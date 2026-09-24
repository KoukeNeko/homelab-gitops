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

Tagging `vX.Y.Z` in the ShareCodex repo builds the image and commits a bump of `images[].newTag` in
`kustomization.yaml` here. Argo CD rolls it out; the server
runs its own database migrations on start. To roll out by hand, set `newTag` and push.

## Changing the admin password

```bash
./seal.sh
```

It reuses the database password already in the cluster, so only the admin password changes. Commit
and push `sealed-secret.yaml`, then restart the server so it picks up the new password:

```bash
kubectl -n sharecodex rollout restart deployment/sharecodex
```
