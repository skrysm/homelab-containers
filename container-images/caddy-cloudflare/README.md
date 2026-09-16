# Caddy with Cloudflare DNS support

This image extends the official Alpine-based Caddy image with the
[`dns.providers.cloudflare`](https://github.com/caddy-dns/cloudflare) module.
It can use Cloudflare's DNS API to complete ACME DNS-01 challenges, including
for wildcard certificates.

Create a scoped Cloudflare API token with `Zone.Zone:Read` and `Zone.DNS:Edit`
permissions for the zones Caddy manages. Pass it to the container as the
`CF_API_TOKEN` environment variable rather than writing it into the Caddyfile:

```caddyfile
*.example.com {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
    }

    respond "Caddy is running"
}
```

Persist `/data` so Caddy retains certificates and ACME state. Persisting
`/config` is also recommended. The image otherwise retains the default command,
ports, paths, and behavior of the official Caddy image.
