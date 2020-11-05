#!/bin/bash
# William Lam
# www.virtuallyghetto

PhotonOVA="/Volumes/Storage/Software/photon-hw13_uefi-3.0-a383732.ova"
PhotonRouterVMName="router.tanzu.local"
ESXiHostname="esxi-01.tanzu.local"
ESXiUsername="root"
ESXiPassword='VMware1!'

PhotonRouterNetwork="VM Network"
PhotonRouterDatastore="local-vmfs"

### DO NOT EDIT BEYOND HERE ###

ovftool \
--name=${PhotonRouterVMName} \
--X:waitForIpv4 \
--powerOn \
--acceptAllEulas \
--noSSLVerify \
--datastore=${PhotonRouterDatastore} \
--net:"None=${PhotonRouterNetwork}" \
${PhotonOVA} \
"vi://${ESXiUsername}:${ESXiPassword}@${ESXiHostname}"