# homelab-gitops

Declarative configuration for a single-node [K3s](https://k3s.io/) homelab.
[Argo CD](https://argo-cd.readthedocs.io/) watches this repository and keeps the
cluster matching what is committed here — change Git, and the cluster follows.

## Architecture

```
user ──https──▶ Cloudflare edge ── TLS terminates here
                     │  encrypted tunnel (cloudflared, no inbound ports)
                     ▼
              cloudflared (runs on the K3s host)
                     │  http → node :80
                     ▼
                 Traefik ── routes by Host ──▶ Service ──▶ Pod
```

| Piece | Role |
|-------|------|
| **K3s** | Single-node Kubernetes. |
| **Argo CD** | Reconciles this repo into the cluster (auto-sync, self-heal, prune). |
| **Traefik** | K3s' built-in ingress router. Matches requests to Services by `Host`. |
| **Cloudflare Tunnel** | Public entry point. `cloudflared` runs on the host and dials out to Cloudflare — no router ports are opened. TLS is served at Cloudflare's edge. |
| **Sealed Secrets** | Secrets are encrypted with `kubeseal`, so the ciphertext is safe to commit. |

## Layout

```
apps/          One folder per app, built with Kustomize.
argocd/        One Argo CD Application per app, pointing back at apps/<name>.
```

## How an app gets exposed

1. The app has an `Ingress` whose `host` is a **first-level** subdomain
   (e.g. `app.koukeneko.cafe`). The ingress targets Traefik's `web`
   entrypoint (port 80) — TLS is Cloudflare's job, not the cluster's.
2. In the Cloudflare Tunnel, a public hostname routes that name to
   `http://<node-ip>:80` (Traefik). Adding the hostname creates its DNS record.
3. Traefik matches the `Host` header to the app's Service.

> [!IMPORTANT]
> Use a **first-level** subdomain. Cloudflare's free Universal SSL covers
> `koukeneko.cafe` and `*.koukeneko.cafe` only. A two-level name like
> `app.lab.koukeneko.cafe` has no edge certificate and fails the TLS handshake
> unless you buy Advanced Certificate Manager.

## Secrets

Plaintext secrets never land in this repo. Each app that needs one ships a
`seal.sh` that:

1. hashes/generates the credentials,
2. runs `kubeseal` against the cluster's controller,
3. writes an encrypted `sealed-secret.yaml`.

Commit the sealed file. Only the in-cluster controller holds the private key, so
nobody can decrypt it from Git — and the ciphertext is bound to its target
namespace and name. `.gitignore` also blocks `**/secret.yaml` and
`**/*.plain.yaml` as a backstop.

## Add a new app

1. `apps/<name>/` — Kustomize manifests (Deployment, Service, Ingress, …).
2. Ingress `host`: a first-level subdomain; entrypoint `web`.
3. Secrets, if any: write a `seal.sh`, run it, commit `sealed-secret.yaml`.
4. Cloudflare Tunnel: add the hostname → `http://<node-ip>:80`.
5. `argocd/<name>.yaml` — an Argo CD `Application` pointing at `apps/<name>`.
6. `kubectl apply -f argocd/<name>.yaml`, then push. Argo takes it from there.

## Platform bootstrap (one-time)

Installed on the cluster outside this repo:

- **Argo CD** — `kubectl apply -n argocd -f <argo stable install.yaml>`.
- **Sealed Secrets controller** — the official release manifest, into
  `kube-system` as `sealed-secrets-controller` (so `kubeseal` finds it by
  default).
- **cloudflared** — a systemd service on the host, run with the tunnel token.

## Apps

| App | URL | Image |
|-----|-----|-------|
| [302.go](apps/302.go/) | https://302.koukeneko.cafe | `ghcr.io/koukeneko/302.go` |
