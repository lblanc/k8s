#!/bin/bash

# Nodes list
nodes="node2 node3 node4"


# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33]'
NC='\033[0m' # No Color

#echo -e "${ORANGE}Run this script on master node with rsa key exchange with worker nodes${NC}"
echo
read -p "Are you sure? " -n 1 -r
echo  
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 
fi

export KUBECONFIG=/etc/kubernetes/admin.conf

command=$(kubeadm token create --print-join-command)


for node in ${nodes}; do
 
  ssh root@${node} ${command}        
 
done



