# Minimal example

Provisions a single worker droplet with default ports open to the
public internet.

```bash
export TF_VAR_do_token="dop_v1_..."
export TF_VAR_ssh_key_name="my-laptop"

terraform init
terraform apply
```

After apply, bootstrap manually:

```bash
ssh root@$(terraform output -raw ipv4_address) 'rune admin bootstrap --out-file /tmp/rune-admin.token'
scp root@$(terraform output -raw ipv4_address):/tmp/rune-admin.token ./rune-admin.token
rune login dev --server $(terraform output -raw grpc_endpoint) --token-file ./rune-admin.token
```

For a fully automated bootstrap, see `../with-bootstrap/`.
