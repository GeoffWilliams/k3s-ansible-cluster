#!/bin/bash

export VIP=10.50.0.5
ROUTER=$(echo "$VIP" | awk -F. '{print $1 "." $2 "." $3 ".1"}')

INTERFACE=$(ip route get $ROUTER | awk '/dev/ { print $3 }')

# latest version of script
KVVERSION_CURRENT=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")
KVVERSION_INSTALL=v0.7.1
OUTPUT_MANIFEST=/var/lib/rancher/k3s/server/manifests/kube-vip-daemonset.yaml

echo "Network interface: ${INTERFACE}"

if [ "$KVVERSION_CURRENT" != "$KVVERSION_INSTALL" ] ; then
    echo "Newer version of kube-vip available: ${KVVERSION_CURRENT} but installing ${KVVERSION_INSTALL} as you requested..."
fi


KUBE_VIP_ARGS="manifest daemonset \
    --interface $INTERFACE \
    --address $VIP \
    --inCluster \
    --taint \
    --controlplane \
    --arp \
    --leaderElection
"

# this will output a manifest???
ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION_INSTALL
ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION_INSTALL vip /kube-vip $KUBE_VIP_ARGS > $OUTPUT_MANIFEST
