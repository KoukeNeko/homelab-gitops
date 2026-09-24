# ShareCodex

Kustomize manifests for the [ShareCodex](https://github.com/KoukeNeko/ShareCodex) server and its
Postgres database. Members' desktop apps sync to `https://sharecodex.doeshing.uk`; the admin console
is at `/admin/`.

## First deploy

1. Seal the credentials (prompts for the admin password; the Postgres password is generated):

   ```bash
   ./seal.sh
   ```

2. Cloudflare Tunnel: add the public hostname `sharecodex.doeshing.uk` → `http://<node-ip>:80`.
3. Commit and push, then `kubectl apply -f argocd/sharecodex.yaml` once.

## Releases

Set `images[].newTag` in `kustomization.yaml` to the new ShareCodex version and push. Argo CD rolls
it out; the server runs its own database migrations on start.
