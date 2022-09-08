#!/bin/bash

# Nodes list
nodes="node2 node3 node4"


# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33]'
NC='\033[0m' # No Color

export KUBECONFIG=/etc/kubernetes/admin.conf

command=$(kubeadm token create --print-join-command)


for node in ${nodes}; do
 
  echo -e "${ORANGE}Join node: ${node}${NC}"
  ssh root@${node} ${command}        
 
done



