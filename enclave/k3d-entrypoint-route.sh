#!/bin/sh
# An --internal Docker network has no default route. k3s refuses to start
# without one. Route via the network's gateway address: Docker drops the
# traffic there, so the node still has no way out.
gw=$(ip -4 addr show eth0 | awk '/inet /{split($2,a,"/"); split(a[1],o,"."); print o[1]"."o[2]"."o[3]".1"}')
ip route add default via "$gw" dev eth0 2>/dev/null || true
