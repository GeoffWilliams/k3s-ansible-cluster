#!/bin/bash

export VIP=172.20.0.5

# fucking crazy
# https://serverfault.com/questions/1019363/using-ip-address-show-type-to-display-physical-network-interface
export INTERFACE=$(
    ip -details -json address show | jq --join-output '
    .[] |
      if .linkinfo.info_kind // .link_type == "loopback" // .operstate == "DOWN"  then
          empty
      else
          .ifname ,
          ( ."addr_info"[] |
		  if .family == "inet" or .family == "inet6"  then
                  ""
              else
                  empty
              end
          ),
          "\n"
      end
    '

)

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
    --services \
    --arp \
    --leaderElection
"

# this will output a manifest???
ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION_INSTALL
ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION_INSTALL vip /kube-vip $KUBE_VIP_ARGS > $OUTPUT_MANIFEST
