#!/bin/bash
# Run on master node, rsa key must be exchange with worker nodes

# Worker nodes list
nodes="node2 node3 node4"

# Worker nodes list who will host mayastor
nodesmayastor="node2 node3 node4"

# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33]'
NC='\033[0m' # No Color


#Enable Huge Page Support
echo -e "${ORANGE}Enable Huge Page Support....${NC}"
echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
echo vm.nr_hugepages = 1024 | sudo tee -a /etc/sysctl.conf
for node in ${nodes}; do
 
  ssh root@${node} echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
  ssh root@${node} echo vm.nr_hugepages = 1024 | sudo tee -a /etc/sysctl.conf      
 
done

for node in ${nodes}; do
 
    kubectl label node ${node} openebs.io/engine=mayastor
 
done

