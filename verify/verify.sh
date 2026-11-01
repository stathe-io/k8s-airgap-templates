#!/bin/sh
# Proves what the lab claims, one check per claim. Each prints PASS or FAIL and
# the script exits non-zero if any failed, so a claim that stops being true
# fails loudly instead of quietly.
#
# Run from the host. Commands go into the cluster through the server node,
# the way an operator inside the enclave would reach it.
set -u
. "$(dirname "$0")/../versions.env"

NODE="k3d-${CLUSTER}-server-0"
failed=0

check() {
  name=$1; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $name"
  else
    echo "FAIL  $name"
    failed=1
  fi
}

k() { docker exec -i "$NODE" kubectl "$@"; }

# The probes below use busybox from the k3s bundle, which is not signed. They
# run in their own namespace, which the admission policy exempts, so a probe
# fails because of the network and never because admission refused it.
PROBES=lab-probes
p() { k -n "$PROBES" "$@"; }

node_ready() {
  k get nodes --no-headers | grep -q " Ready "
}

# The network itself is the control: Docker gives an --internal network no
# route out, whatever the node or a pod tries.
network_is_internal() {
  [ "$(docker network inspect "$NETWORK" --format '{{.Internal}}')" = true ]
}

# The node has to be running first: without that, docker exec fails on the
# missing container and the negation turns the failure into a pass.
node_cannot_reach_internet() {
  [ "$(docker inspect -f '{{.State.Running}}' "$NODE" 2>/dev/null)" = true ] &&
    ! docker exec "$NODE" wget -q -T 5 -O /dev/null "$EGRESS_PROBE"
}

# The control for the next check: the same image, scheduled the same way,
# succeeds. Without it a pod that failed for any reason would count as proof.
pod_from_bundle_runs() {
  p delete pod run-probe --ignore-not-found --wait=true
  p run run-probe --restart=Never --image="$BUSYBOX" --command -- true
  p wait pod/run-probe --for=jsonpath='{.status.phase}'=Succeeded --timeout=60s
  status=$?
  p delete pod run-probe --ignore-not-found --wait=false
  return $status
}

pod_cannot_reach_internet() {
  p delete pod egress-probe --ignore-not-found --wait=true
  p run egress-probe --restart=Never --image="$BUSYBOX" \
    --command -- wget -q -T 5 -O /dev/null "$EGRESS_PROBE"
  p wait pod/egress-probe --for=jsonpath='{.status.phase}'=Failed --timeout=60s
  status=$?
  p delete pod egress-probe --ignore-not-found --wait=false
  return $status
}

# An image that is not in the bundle cannot arrive any other way.
unknown_image_is_not_pulled() {
  p delete pod pull-probe --ignore-not-found --wait=true
  p run pull-probe --restart=Never --image="$UNBUNDLED_IMAGE"
  p wait pod/pull-probe \
    --for=jsonpath='{.status.containerStatuses[0].state.waiting.reason}'=ErrImagePull \
    --timeout=60s ||
  p wait pod/pull-probe \
    --for=jsonpath='{.status.containerStatuses[0].state.waiting.reason}'=ImagePullBackOff \
    --timeout=30s
  status=$?
  p delete pod pull-probe --ignore-not-found --wait=false
  return $status
}

# The images the bundle lists, as repository paths without the registry host.
bundled_repos() {
  grep -v '^#' "$(dirname "$0")/../images.txt" | sed -E 's#^[^/]+/##; s#[:@].*##' | sort -u
}

# Runs crane on the enclave network, the only place the registry answers.
in_enclave() {
  docker run --rm --network "$NETWORK" "$CRANE_IMAGE" "$@"
}

# Besides the bundle, the registry holds one deliberate fixture: an image that
# crossed without passing the gate, so the refusal below has something to refuse.
registry_holds_exactly_the_bundle() {
  have=$(in_enclave catalog --insecure "$REGISTRY" | sort -u)
  want=$( (bundled_repos; echo "$UNSIGNED_FIXTURE") | sort -u)
  [ -n "$have" ] && [ "$have" = "$want" ]
}

unsigned_image_is_refused() {
  k delete pod unsigned-probe --ignore-not-found --wait=true
  out=$(k run unsigned-probe --restart=Never --image="$REGISTRY/$UNSIGNED_FIXTURE:1" 2>&1)
  k delete pod unsigned-probe --ignore-not-found --wait=false
  echo "$out" | grep -q "admission webhook" &&
    echo "$out" | grep -q "not signed by the import gate"
}

# The same refusal for an init container, next to a signed main container.
unsigned_init_container_is_refused() {
  signed="$REGISTRY/$(grep -v '^#' "$(dirname "$0")/../images.txt" | head -1 | sed -E 's#^[^/]+/##')"
  out=$(printf '%s\n' \
    "apiVersion: v1" \
    "kind: Pod" \
    "metadata: {name: init-probe, namespace: default}" \
    "spec:" \
    "  restartPolicy: Never" \
    "  initContainers: [{name: init, image: \"$REGISTRY/$UNSIGNED_FIXTURE:1\"}]" \
    "  containers: [{name: app, image: \"$signed\"}]" |
    k apply --dry-run=server -f - 2>&1)
  echo "$out" | grep -q "not signed by the import gate"
}

# Workloads name the enclave registry, not the original one: admission fetches
# the signature from the registry a pod names. Only this one answers.
bundled_image_runs() {
  image="$REGISTRY/$(grep -v '^#' "$(dirname "$0")/../images.txt" | head -1 | sed -E 's#^[^/]+/##')"
  k delete pod bundle-probe --ignore-not-found --wait=true
  k run bundle-probe --restart=Never --image="$image"
  k wait pod/bundle-probe --for=condition=Ready --timeout=90s
  status=$?
  k delete pod bundle-probe --ignore-not-found --wait=false
  return $status
}

k create namespace "$PROBES" --dry-run=client -o yaml | k apply -f - >/dev/null 2>&1

check "the cluster node is Ready" node_ready
check "the network has no route out" network_is_internal
check "the node cannot reach the internet" node_cannot_reach_internet
check "a pod from the bundle runs" pod_from_bundle_runs
check "a pod cannot reach the internet" pod_cannot_reach_internet
check "an image outside the bundle is not pulled" unknown_image_is_not_pulled
check "the enclave registry holds exactly the bundle" registry_holds_exactly_the_bundle
check "a bundled image runs, pulled through the enclave registry" bundled_image_runs
check "an unsigned image is refused at admission" unsigned_image_is_refused
check "an unsigned init container is refused at admission" unsigned_init_container_is_refused

exit $failed
