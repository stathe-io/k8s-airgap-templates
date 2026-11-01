# Harbor

The enclave registry. Harbor v2.14.6, amd64 only.

On the connected side, fetch `harbor-offline-installer-v2.14.6.tgz` and its
`.asc`. Verify it before sealing it into the bundle (release key
`644FF454C0B4115C`).

In the enclave:

1. Copy `harbor.yml.tmpl` from the installer to `harbor.yml` and set the keys
   in [harbor.yml](harbor.yml).
2. `./install.sh --with-trivy`
3. Per project the cluster pulls from: an immutability rule on all tags, and
   no proxy cache or replication to an upstream.
4. Robot accounts: one for the import gate (push), one per pipeline, one for
   the nodes (pull only).
