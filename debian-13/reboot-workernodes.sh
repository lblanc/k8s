#!/bin/bash


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
user="root"


# Reboot WorkerNodes
echo "${YELLOW}Reboot WorkerNodes${NC}"

for node in ${workernodes}; do
ssh ${user}@${node} "sudo reboot"
done
