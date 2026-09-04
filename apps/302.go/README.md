# 302.go

Kustomize manifests for [302.go](https://github.com/KoukeNeko/302.go) behind Traefik with a
cert-manager certificate. State lives on one RWO volume; the deployment uses `Recreate` because
SQLite allows a single writer.

## First deploy

1. Replace `s.example.com` in `ingress.yaml` and `kustomization.yaml` with the real hostname, and
   adjust the `cert-manager.io/cluster-issuer` name if yours differs.
2. Seal the credentials (writes `sealed-secret.yaml`, prints the API token once):

   ```bash
   ./seal.sh
   ```

3. Commit and push. Argo CD picks the change up from `argocd/302go.yaml`.

## Releases

Tagging `vX.Y.Z` in the 302.go repo builds the image and opens a commit here that bumps
`images[].newTag` in `kustomization.yaml`. Argo CD then rolls the new version out.
