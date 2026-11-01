# Harbor

The registry inside the enclave. Every image the cluster runs is stored here,
after it passed the import gate. Follow the steps in order.

Not yet installed in a test. The settings and paths are checked against the
v2.14.6 release files. Harbor's images are built for amd64 only, so it needs an
amd64 host.

## What you need

- An amd64 Linux host with Docker and Docker Compose, inside the enclave.
- A TLS certificate and key for the registry's name, issued by the enclave CA.
- From the transfer: `harbor-offline-installer-v2.14.6.tgz` plus the Trivy
  database files `trivy.db` and `metadata.json`.

On the connected side, before sealing the bundle, download the installer and
its `.asc` file and verify the signature (the Harbor release key is
`644FF454C0B4115C`).

## Steps

**1. Unpack the installer.**

```sh
tar xzf harbor-offline-installer-v2.14.6.tgz
cd harbor
cp harbor.yml.tmpl harbor.yml
```

**2. Set the enclave settings.** Open `harbor.yml` and change the keys listed
in [harbor.yml](harbor.yml) in this folder.

> Check: `grep -E '^hostname|skip_update|offline_scan' harbor.yml` shows your
> hostname and `true` twice.

**3. Install, with the scanner.**

```sh
sudo ./install.sh --with-trivy
```

> Check: `sudo docker compose ps` lists every Harbor container as running.

**4. Give the scanner its database.**

```sh
sudo mkdir -p /data/trivy-adapter/trivy/db
sudo cp trivy.db metadata.json /data/trivy-adapter/trivy/db/
```

Use the `data_volume` from `harbor.yml` if it is not `/data`. Repeat this
after every transfer.

**5. Lock down each project the cluster pulls from.** In the web UI, per
project:

- Configuration: tick "Prevent vulnerable images from running" if you want
  Harbor to refuse pulls on its own scan result too.
- Policy > Tag Immutability: a rule for all repositories and all tags, so a
  tag can never be pushed again with other content.
- No proxy cache and no replication rule to an outside registry. Inside an
  enclave there is no outside.

**6. Create robot accounts.** Under Robot Accounts:

- one for the import gate, allowed to push,
- one per pipeline that pushes,
- one for the cluster nodes, allowed to pull only.

> Check: `docker login registry.enclave.example` with the nodes' robot account
> works. A `docker push` with it is refused.
