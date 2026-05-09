# Edge node with automated bootstrap

```bash
export TF_VAR_do_token="dop_v1_..."
export TF_VAR_ssh_key_name="my-laptop"
export TF_VAR_acme_email="ops@example.com"
# (optional) export TF_VAR_ssh_private_key_path="$HOME/.ssh/id_ed25519"

terraform init
terraform apply
```

When apply finishes:

```bash
$(terraform output -raw rune_login_command)
rune whoami
```

The admin token sits at the path printed by
`terraform output -raw bootstrap_token_path` (mode 0600). Treat it
like a root password.

## Re-bootstrap

If you need to rotate, taint and re-apply:

```bash
terraform apply -replace=module.rune.null_resource.bootstrap[0]
```

This re-runs the SSH bootstrap and overwrites the local token file.
