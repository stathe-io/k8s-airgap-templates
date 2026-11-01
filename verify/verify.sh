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

k() { docker exec "$NODE" kubectl "$@"; }

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
  k delete pod run-probe --ignore-not-found --wait=true
  k run run-probe --restart=Never --image="$BUSYBOX" --command -- true
  k wait pod/run-probe --for=jsonpath='{.status.phase}'=Succeeded --timeout=60s
  status=$?
  k delete pod run-probe --ignore-not-found --wait=false
  return $status
}

pod_cannot_reach_internet() {
  k delete pod egress-probe --ignore-not-found --wait=true
  k run egress-probe --restart=Never --image="$BUSYBOX" \
    --command -- wget -q -T 5 -O /dev/null "$EGRESS_PROBE"
  k wait pod/egress-probe --for=jsonpath='{.status.phase}'=Failed --timeout=60s
  status=$?
  k delete pod egress-probe --ignore-not-found --wait=false
  return $status
}

# An image that is not in the bundle cannot arrive any other way.
unknown_image_is_not_pulled() {
  k delete pod pull-probe --ignore-not-found --wait=true
  k run pull-probe --restart=Never --image="$UNBUNDLED_IMAGE"
  k wait pod/pull-probe \
    --for=jsonpath='{.status.containerStatuses[0].state.waiting.reason}'=ErrImagePull \
    --timeout=60s ||
  k wait pod/pull-probe \
    --for=jsonpath='{.status.containerStatuses[0].state.waiting.reason}'=ImagePullBackOff \
    --timeout=30s
  status=$?
  k delete pod pull-probe --ignore-not-found --wait=false
  return $status
}

check "the cluster node is Ready" node_ready
check "the network has no route out" network_is_internal
check "the node cannot reach the internet" node_cannot_reach_internet
check "a pod from the bundle runs" pod_from_bundle_runs
check "a pod cannot reach the internet" pod_cannot_reach_internet
check "an image outside the bundle is not pulled" unknown_image_is_not_pulled

exit $failed
