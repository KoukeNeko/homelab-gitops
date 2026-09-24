#!/usr/bin/env bash
# Produce sealed-secret.yaml for ShareCodex.
#
#   ./seal.sh                                   # prompts for the admin password
#   ./seal.sh --controller-namespace kube-system   # extra kubeseal flags pass through
#
# Needs: kubectl (pointed at the cluster) and kubeseal. When the secret already
# exists in the cluster its Postgres password is reused, so running this again
# only changes the admin password; on a first deploy a new one is generated.
# Nothing plaintext is written to disk.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE=sharecodex
SECRET_NAME=sharecodex-secrets

read -r -s -p "Admin password (12+ characters): " admin_password; echo
[[ ${#admin_password} -ge 12 ]] || { echo "the admin password must be at least 12 characters" >&2; exit 1; }

# The database was initialised with this password; a new one would lock the
# server out of it. Only a secret the cluster says does not exist counts as a
# first deploy; any other lookup failure stops here.
if existing="$(kubectl get secret "$SECRET_NAME" --namespace "$NAMESPACE" \
    -o jsonpath='{.data.POSTGRES_PASSWORD}' 2>"${TMPDIR:-/tmp}/sharecodex-seal.err")"; then
  postgres_password="$(printf '%s' "$existing" | base64 --decode)"
  [[ -n "$postgres_password" ]] || { echo "$SECRET_NAME has no POSTGRES_PASSWORD" >&2; exit 1; }
  echo "Keeping the existing Postgres password."
elif grep -q NotFound "${TMPDIR:-/tmp}/sharecodex-seal.err"; then
  postgres_password="$(openssl rand -hex 24)"
  echo "Generated a Postgres password for the first deploy."
else
  echo "Could not read $SECRET_NAME from the cluster; is kubectl pointed at it?" >&2
  cat "${TMPDIR:-/tmp}/sharecodex-seal.err" >&2
  rm -f "${TMPDIR:-/tmp}/sharecodex-seal.err"
  exit 1
fi
rm -f "${TMPDIR:-/tmp}/sharecodex-seal.err"

kubectl create secret generic "$SECRET_NAME" --namespace "$NAMESPACE" --dry-run=client -o yaml \
  --from-literal=ADMIN_PASSWORD="$admin_password" \
  --from-literal=POSTGRES_PASSWORD="$postgres_password" \
  --from-literal=DATABASE_URL="postgres://sharecodex:${postgres_password}@postgres:5432/sharecodex?sslmode=disable" \
  | kubeseal --format yaml "$@" > sealed-secret.yaml

echo "sealed-secret.yaml written. Commit and push it, then restart the server so it reads the new password:"
echo "  kubectl -n $NAMESPACE rollout restart deployment/sharecodex"
