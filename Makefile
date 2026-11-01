include versions.env

.PHONY: bundle up verify down

bundle:
	sh connected/fetch.sh

up:
	sh enclave/up.sh

verify:
	sh verify/verify.sh

down:
	-k3d cluster delete $(CLUSTER)
	-docker network rm $(NETWORK)
