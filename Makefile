.PHONY: keys bundle up verify down

# The import gate's signing key. It stays on this host and out of git; only
# the public half goes into the cluster.
keys:
	sh enclave/keys.sh

bundle:
	sh connected/fetch.sh

up: keys
	sh enclave/up.sh

verify:
	sh verify/verify.sh

down:
	. ./versions.env; k3d cluster delete $$CLUSTER; docker rm -f registry >/dev/null 2>&1; docker network rm $$NETWORK || true
