#!/bin/bash
# Run on master node, rsa key must be exchange with worker nodes

# Worker nodes list
nodes="node2 node3 node4"


export KUBECONFIG=/etc/kubernetes/admin.conf

command=$(kubeadm token create --print-join-command)


for node in ${nodes}; do
 
  echo -e "${ORANGE}Join node: ${node} ${NC}"
  ssh root@${node} ${command}        
 
done



