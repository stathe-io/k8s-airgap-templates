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

# The tools come out of the bundle, not from a registry.
docker load -q -i "$bundle/tools.tar" >/dev/null

docker inspect registry >/dev/null 2>&1 ||
  docker run -d --name registry --network "$NETWORK" --restart unless-stopped \
    "$REGISTRY_IMAGE" >/dev/null

until docker run --rm --network "$NETWORK" "$CRANE_IMAGE" catalog --insecure "$REGISTRY" >/dev/null 2>&1; do
  sleep 1
done

keys="$here/../keys"

# The import gate. Each image is loaded under its own repository path and
# signed by digest with the gate's key. The signature says the image came in
# through the gate. There is no transparency log to record it in. The
# signature uses cosign's classic format because Kyverno does not find the
# newer bundle format in a registry without the OCI 1.1 referrers API.
for dir in "$bundle"/images/*/; do
  ref=$(cat "$dir/ref")
  repo=$(echo "$ref" | sed -E 's#^[^/]+/##; s#@.*##')
  digest=${ref##*@}
  docker run --rm --network "$NETWORK" -v "$dir:/img:ro" "$CRANE_IMAGE" \
    push --index --insecure /img "$REGISTRY/$repo" >/dev/null
  docker run --rm --network "$NETWORK" -e COSIGN_PASSWORD= -v "$keys:/k:ro" "$COSIGN_IMAGE" \
    sign --key /k/cosign.key --new-bundle-format=false --use-signing-config=false \
    --tlog-upload=false --allow-http-registry --yes "$REGISTRY/${repo%%:*}@$digest" >/dev/null 2>&1
  echo "loaded and signed $ref"
done

# The fixture: one image in the registry that the gate did not sign.
first=$(grep -v '^#' "$here/../images.txt" | head -1 | sed -E 's#^[^/]+/##; s#:.*##')
first_digest=$(grep -v '^#' "$here/../images.txt" | head -1 | sed 's/.*@//')
docker run --rm --network "$NETWORK" "$CRANE_IMAGE" \
  copy --insecure "$REGISTRY/$first@$first_digest" "$REGISTRY/$UNSIGNED_FIXTURE:1" >/dev/null 2>&1
echo "loaded $UNSIGNED_FIXTURE, unsigned on purpose"

# No load balancer and no published API port: an internal network cannot
# publish one. The operator works from inside the enclave anyway.
k3d cluster create "$CLUSTER" \
  --image "$K3S_IMAGE" \
  --network "$NETWORK" \
  --no-lb \
  -v "$bundle/$K3S_AIRGAP:/var/lib/rancher/k3s/agent/images/$K3S_AIRGAP@server:0" \
  -v "$here/k3d-entrypoint-route.sh:/bin/k3d-entrypoint-route.sh@server:0" \
  -v "$here/registries.yaml:/etc/rancher/k3s/registries.yaml@server:0" \
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

k() { docker exec -i "$node" kubectl "$@"; }

# Pods resolve names through CoreDNS, which knows nothing about Docker's
# network. Admission has to reach the registry to fetch signatures, so the
# registry gets a name in the cluster.
registry_ip=$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NETWORK\").IPAddress}}" registry)
k -n kube-system create configmap coredns-custom --dry-run=client -o yaml \
  --from-literal=registry.server="registry:53 {
  hosts {
    $registry_ip registry
  }
}" | k apply -f - >/dev/null
k -n kube-system rollout restart deployment coredns >/dev/null

# Kyverno from the bundle, with its images pointed at the enclave registry.
manifest=$(cat "$bundle/kyverno-install.yaml")
for ref in $(grep '^reg.kyverno.io/' "$here/../images.txt"); do
  tagged=${ref%@*}
  manifest=$(printf '%s' "$manifest" | sed "s#$tagged#$REGISTRY/${ref#*/}#g")
done
printf '%s\n' "$manifest" | k apply --server-side -f - >/dev/null
k -n kyverno rollout status deployment kyverno-admission-controller --timeout=300s >/dev/null

# The public key goes in at the placeholder, indented to sit inside the block
# scalar. sed reads it from a file, which works the same on GNU and BSD.
indented=$(mktemp)
sed 's/^/            /' "$keys/cosign.pub" > "$indented"
sed -e "/^__PUBLIC_KEY__\$/r $indented" -e '/^__PUBLIC_KEY__$/d' "$here/policy.yaml" |
  k apply -f - >/dev/null
rm -f "$indented"
k wait imagevalidatingpolicy/require-gate-signature \
  --for=jsonpath='{.status.conditionStatus.ready}'=true --timeout=120s >/dev/null
echo "ready"
