#!/usr/bin/env bash
# Produce sealed-secret.yaml for ShareCodex.
#
#   ./seal.sh                                   # prompts for the admin password
#   ./seal.sh --controller-namespace kube-system   # extra kubeseal flags pass through
#
# Needs: kubectl (pointed at the cluster) and kubeseal. A new Postgres password
# is generated each run, so re-sealing after the database exists requires
# changing the password in Postgres too. Nothing plaintext is written to disk.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE=sharecodex
SECRET_NAME=sharecodex-secrets

read -r -s -p "Admin password (12+ characters): " admin_password; echo
[[ ${#admin_password} -ge 12 ]] || { echo "the admin password must be at least 12 characters" >&2; exit 1; }
postgres_password="$(openssl rand -hex 24)"

kubectl create secret generic "$SECRET_NAME" --namespace "$NAMESPACE" --dry-run=client -o yaml \
  --from-literal=ADMIN_PASSWORD="$admin_password" \
  --from-literal=POSTGRES_PASSWORD="$postgres_password" \
  --from-literal=DATABASE_URL="postgres://sharecodex:${postgres_password}@postgres:5432/sharecodex?sslmode=disable" \
  | kubeseal --format yaml "$@" > sealed-secret.yaml

echo "sealed-secret.yaml written."
