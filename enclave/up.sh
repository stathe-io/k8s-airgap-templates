#!/bin/sh
# The enclave. A Docker network with no route out and a k3s node on it that
# starts from the bundle alone.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../versions.env"
bundle="$here/../bundle"

[ -f "$bundle/$K3S_AIRGAP" ] || { echo "no bundle; run connected/fetch.sh first" >&2; exit 2; }

docker network inspect "$NETWORK" >/dev/null 2>&1 ||
  docker network create --internal "$NETWORK" >/dev/null

# No load balancer and no published API port: an internal network cannot
# publish one. The operator works from inside the enclave anyway.
k3d cluster create "$CLUSTER" \
  --image "$K3S_IMAGE" \
  --network "$NETWORK" \
  --no-lb \
  -v "$bundle/$K3S_AIRGAP:/var/lib/rancher/k3s/agent/images/$K3S_AIRGAP@server:0" \
  -v "$here/k3d-entrypoint-route.sh:/bin/k3d-entrypoint-route.sh@server:0" \
  --k3s-arg "--disable=traefik,metrics-server@server:0" \
  --wait=false

node="k3d-${CLUSTER}-server-0"
echo "waiting for $node"
until docker exec "$node" kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready "; do
  if docker logs "$node" 2>&1 | grep -q 'level=fatal'; then
    docker logs "$node" 2>&1 | grep 'level=fatal' >&2
    exit 1
  fi
  sleep 3
done
echo "ready"
