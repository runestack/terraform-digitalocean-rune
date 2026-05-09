# Edge node with ACME-managed TLS

Single edge droplet that terminates :80/:443 and issues
Let's Encrypt certs for any service deployed with
`expose.tls.mode = auto`.

## Apply

```bash
export TF_VAR_do_token="dop_v1_..."
export TF_VAR_ssh_key_name="my-laptop"
export TF_VAR_acme_email="ops@example.com"

terraform init
terraform apply
```

## DNS

Point your domain's A record at the output `ipv4_address` **before**
casting any service with `tls.mode = auto` — the HTTP-01 challenge
needs DNS to resolve back to this droplet.

## Cast a service

```yaml
service:
  name: landing
  image: nginx:alpine
  ports: [{ name: http, port: 80 }]
  expose:
    host: example.com
    port: http
    tls:
      mode: auto
```

The first request to `https://example.com` will trigger issuance
(~5–15s). Subsequent renewals happen automatically 30 days before
expiry.
