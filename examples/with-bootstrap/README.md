# Edge node with automated bootstrap

```bash
export TF_VAR_do_token="dop_v1_..."
export TF_VAR_ssh_key_name="my-laptop"
export TF_VAR_acme_email="ops@example.com"
export TF_VAR_ssh_private_key="$(cat ~/.ssh/id_ed25519)"

# Optional: also store GHCR credentials as an encrypted Rune Secret.
export TF_VAR_ghcr_username="my-github-user"
export TF_VAR_ghcr_pat="$(gh auth token)"

terraform init
terraform apply
```

`ssh_private_key` is the PEM contents themselves — passed in
directly so the example stays evaluable by `tflint` and other
static checkers (which can't read files outside the config).

When apply finishes:

```bash
$(terraform output -raw rune_login_command)
rune whoami
```

The admin token sits at the path printed by
`terraform output -raw bootstrap_token_path` (mode 0600). Treat it
like a root password.

## Registry credentials as Rune Secrets

When `ghcr_username` + `ghcr_pat` are set, the rendered runefile
carries only a `fromSecret = "ghcr-credentials"` reference. On
first start, runed reads `GHCR_USERNAME` and `GHCR_PAT` from
`/etc/rune/runed.env` (written by cloud-init from
`var.runed_environment`), creates the `ghcr-credentials` Secret
in the `system` namespace, encrypts it under the per-secret DEK,
and uses it for image pulls. No PAT is ever written to the
runefile itself.

`runed` infers the auth type from the secret's data keys (see
`resolveRegistrySecret`): `username + password` → basic,
`token` → bearer, `.dockerconfigjson` → docker config JSON,
`awsAccessKeyId + …` → ECR. So once the secret exists, the
`auth.data` block in the runefile is irrelevant — the secret
contents are the source of truth.

To verify after login:

```bash
rune get secret ghcr-credentials -n system
```

To rotate the PAT, the cleanest path is to manage the secret
out-of-band and drop the `bootstrap`/`data` from the TF config
once it exists:

```bash
rune cast secret ghcr-credentials -n system \
  --from-literal username=$GHCR_USERNAME \
  --from-literal password=$(gh auth token)
```

Or, to keep TF as the source of truth, leave `bootstrap = true`
+ `manage = "update"` and re-apply with the new `TF_VAR_ghcr_pat`:

```bash
TF_VAR_ghcr_pat="$(gh auth token)" terraform apply
ssh root@$(terraform output -raw ipv4_address) systemctl restart runed
```

## Re-bootstrap

If you need to rotate the admin token, taint and re-apply:

```bash
terraform apply -replace=module.rune.null_resource.bootstrap[0]
```

This re-runs the SSH bootstrap and overwrites the local token file.
