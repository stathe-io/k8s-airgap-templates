# RKE2 inside the enclave

Templates for an RKE2 node with no route out, in the order to use them.
Taken from the RKE2 [air-gap](https://docs.rke2.io/install/airgap) and
[hardening](https://docs.rke2.io/security/hardening_guide) documentation.

| File | Goes to | Tested |
|---|---|---|
| `config.yaml` | `/etc/rancher/rke2/config.yaml` | No. Checked against the documentation |
| `registries.yaml` | `/etc/rancher/rke2/registries.yaml` | The mirror pattern runs in the lab on k3s |
| `blackhole-route.service` | `/etc/systemd/system/` | The route commands, in a Linux container without a network |

## On the connected side

Fetch the artifacts for one RKE2 version and architecture, check them against
the published checksums and seal them into the bundle (see
[docs/transfer.md](../../docs/transfer.md)):

- `rke2-images.linux-amd64.tar.zst`
- `rke2.linux-amd64.tar.gz`
- `sha256sum-amd64.txt`
- `install.sh`, from `https://get.rke2.io`

## On each node, before the first start

1. Open the bundle at the gate and copy the four files to `/root/rke2-artifacts`.
2. Give the node a default route if it has none. Install and enable
   `blackhole-route.service`, then check with `ip route show default`.
3. On SELinux hosts, install `rke2-selinux` and its dependencies from local
   packages.
4. Prepare the host for the CIS profile. RKE2 refuses to start without it:

   ```sh
   sudo useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U
   sudo mkdir -p /etc/rancher/rke2
   ```

5. Place `config.yaml` and `registries.yaml` in `/etc/rancher/rke2/`. Put the
   enclave CA where `registries.yaml` expects it.
6. Install from the local artifacts:

   ```sh
   sudo INSTALL_RKE2_ARTIFACT_PATH=/root/rke2-artifacts sh /root/rke2-artifacts/install.sh
   ```

7. Apply the CIS kernel settings, on a fresh install only:

   ```sh
   sudo cp -f /usr/local/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
   sudo systemctl restart systemd-sysctl
   ```

   On an RPM install the file is in `/usr/share/rke2/` instead.

8. Start the server: `sudo systemctl enable --now rke2-server.service`.

## After the first start

- The audit policy the CIS profile installs at
  `/etc/rancher/rke2/audit-policy.yaml` logs nothing (`level: None`). Set the
  level to `Metadata` at least and restart `rke2-server`. An enclave without an
  audit trail cannot show who did what.
- For every namespace you create, set `automountServiceAccountToken: false` on
  its `default` service account. The CIS profile does that only for the
  system namespaces.
- With `system-default-registry` set, RKE2 pulls its own system images from the
  enclave registry. Load them there from `rke2-images.linux-amd64.tar.zst`
  through the gate, like any other image.
