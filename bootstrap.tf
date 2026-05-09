# ---------------------------------------------------------------
# Optional bootstrap step.
#
# When var.bootstrap = true, this file:
#   1. Waits for the droplet's gRPC port to accept TCP connections
#      (proxy for "cloud-init finished + runed up").
#   2. SSHes in and runs `rune admin bootstrap` to mint a one-time
#      root admin token.
#   3. Pulls the token to the operator's machine via `scp`.
#   4. Emits a `rune login` command as an output for one-paste use.
#
# Implementation notes:
# - We use null_resource + local-exec rather than the `remote-exec`
#   provisioner so the operation is observable in plan/apply logs
#   and re-runnable with -replace=null_resource.bootstrap.
# - The trigger keys on droplet ID + token path so destroying and
#   recreating the droplet re-bootstraps automatically.
# - SSH StrictHostKeyChecking is disabled because the droplet's
#   host key is unknown until first boot. Acceptable trade-off for
#   a one-shot bootstrap; tighten by managing known_hosts yourself.
# ---------------------------------------------------------------

locals {
  bootstrap_context = var.bootstrap_context_name != "" ? var.bootstrap_context_name : "rune-${var.environment}"

  rune_login_command = format(
    "rune login %s --server %s:%d --token-file %s --default-namespace %s",
    local.bootstrap_context,
    digitalocean_droplet.this.ipv4_address,
    var.grpc_port,
    abspath(var.bootstrap_token_path),
    var.bootstrap_namespace,
  )
}

resource "null_resource" "bootstrap" {
  count = var.bootstrap ? 1 : 0

  triggers = {
    droplet_id = digitalocean_droplet.this.id
    token_path = var.bootstrap_token_path
  }

  lifecycle {
    precondition {
      condition     = var.bootstrap_ssh_private_key != ""
      error_message = "bootstrap = true requires bootstrap_ssh_private_key to be set."
    }
  }

  # Wait for SSH + runed gRPC port to be reachable, then bootstrap
  # and pull the token. Embedded in a single shell so a partial
  # failure leaves the resource tainted for re-apply.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-eu", "-o", "pipefail", "-c"]
    environment = {
      DROPLET_IP       = digitalocean_droplet.this.ipv4_address
      SSH_USER         = var.bootstrap_ssh_user
      SSH_KEY_CONTENT  = var.bootstrap_ssh_private_key
      GRPC_PORT        = tostring(var.grpc_port)
      TOKEN_LOCAL_PATH = var.bootstrap_token_path
      WAIT_TIMEOUT     = var.bootstrap_wait_timeout
    }
    command = <<-BOOTSTRAP
      tmpkey=$(mktemp)
      trap 'rm -f "$tmpkey"' EXIT
      printf '%s\n' "$SSH_KEY_CONTENT" > "$tmpkey"
      chmod 600 "$tmpkey"

      ssh_opts=(
        -i "$tmpkey"
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o LogLevel=ERROR
        -o ConnectTimeout=10
      )

      # 1) wait until SSH responds
      deadline=$(( $(date +%s) + $(echo "$WAIT_TIMEOUT" | sed -E 's/m$/*60/;s/s$//' | bc) ))
      while ! ssh "$${ssh_opts[@]}" "$SSH_USER@$DROPLET_IP" 'true' 2>/dev/null; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
          echo "timed out waiting for SSH on $DROPLET_IP" >&2
          exit 1
        fi
        sleep 5
      done

      # 2) wait for runed gRPC port via remote nc (cloud-init may
      #    still be installing when SSH first answers)
      while ! ssh "$${ssh_opts[@]}" "$SSH_USER@$DROPLET_IP" "</dev/tcp/127.0.0.1/$GRPC_PORT" 2>/dev/null; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
          echo "timed out waiting for runed gRPC on :$GRPC_PORT" >&2
          exit 1
        fi
        sleep 5
      done

      # 3) bootstrap (idempotent: fails fast if already bootstrapped,
      #    in which case the operator should run with bootstrap=false)
      ssh "$${ssh_opts[@]}" "$SSH_USER@$DROPLET_IP" \
        'rune admin bootstrap --out-file /tmp/rune-admin.token'

      # 4) copy token down + lock it down
      mkdir -p "$(dirname "$TOKEN_LOCAL_PATH")"
      scp "$${ssh_opts[@]}" "$SSH_USER@$DROPLET_IP:/tmp/rune-admin.token" "$TOKEN_LOCAL_PATH"
      chmod 600 "$TOKEN_LOCAL_PATH"

      # 5) wipe the remote copy
      ssh "$${ssh_opts[@]}" "$SSH_USER@$DROPLET_IP" 'shred -u /tmp/rune-admin.token || rm -f /tmp/rune-admin.token'

      echo "bootstrap complete: $TOKEN_LOCAL_PATH"
    BOOTSTRAP
  }

  depends_on = [digitalocean_droplet.this, digitalocean_firewall.this]
}
