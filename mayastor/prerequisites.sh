#!/bin/bash
# Run on master node, rsa key must be exchange with worker nodes

# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Mastes + Workers nodes list
nodes="node1 node2 node3 node4"
masternode="node1"
workernodes="node2 node3 node4"

# Linux user
user="user"


#Enable Huge Page Support
for node in ${nodes}; do
  echo "${YELLOW}Enable Huge Page Support on node: ${node}${NC}"
  ssh ${user}@${node} "echo 1024 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages"
  ssh ${user}@${node} "echo vm.nr_hugepages = 1024 | sudo tee -a /etc/sysctl.conf"  
  ssh ${user}@${node} "echo nvme-tcp | sudo tee -a /etc/modules"
  ssh ${user}@${node} "echo ext4 | sudo tee -a /etc/modules"
  ssh ${user}@${node} "echo xfs | sudo tee -a /etc/modules"
done

for node in ${workernodes}; do
  ssh ${user}@${node} "sudo reboot"   
done

for node in ${masternode}; do
  ssh ${user}@${node} "sudo reboot"   
done