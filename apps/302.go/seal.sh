#!/usr/bin/env bash
# Produce sealed-secret.yaml for 302.go.
#
#   ./seal.sh                       # prompts for the admin password
#   ./seal.sh --controller-namespace kube-system   # extra kubeseal flags pass through
#
# Needs: kubectl (pointed at the cluster), kubeseal, docker (to hash the password
# with the app's own Argon2id parameters). Nothing plaintext is written to disk.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE=302go
SECRET_NAME=302go-secrets
IMAGE="$(sed -n 's/^\s*newName:\s*//p' kustomization.yaml):$(sed -n 's/^\s*newTag:\s*//p' kustomization.yaml)"

read -r -s -p "Admin password: " password; echo
[[ -n "$password" ]] || { echo "password must not be empty" >&2; exit 1; }
password_hash="$(printf '%s\n' "$password" | docker run --rm -i "$IMAGE" hash-password)"
api_token="$(openssl rand -hex 32)"

kubectl create secret generic "$SECRET_NAME" --namespace "$NAMESPACE" --dry-run=client -o yaml \
  --from-literal=ADMIN_PASSWORD_HASH="$password_hash" \
  --from-literal=API_TOKEN="$api_token" \
  | kubeseal --format yaml "$@" > sealed-secret.yaml

echo "sealed-secret.yaml written. API token (store it somewhere safe, it is not recoverable from git):"
echo "$api_token"
