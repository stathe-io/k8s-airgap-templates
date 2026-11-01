.PHONY: bundle up verify down

bundle:
	sh connected/fetch.sh

up:
	sh enclave/up.sh

verify:
	sh verify/verify.sh

down:
	. ./versions.env; k3d cluster delete $$CLUSTER; docker rm -f registry >/dev/null 2>&1; docker network rm $$NETWORK || true
