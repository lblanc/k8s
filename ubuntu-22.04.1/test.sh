#!/bin/bash


#
# Run this script on master, with good hosts file and ssh key exchange with workers nodes "ssh-copy-id"
#

# Define some colours for later
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
ORANGE='\033[1;33]'
NC='\033[0m' # No Color

# Mastes + Workers nodes list
nodes="node1 node2 node3 node4"

# K8s version & version
k8sversion=1.24.4
clustername="Lab-Cluster"

# Linux user
user="user"


# Functions
onnodes () {
for node in ${nodes}; do
  ssh ${user}@{node} $1       
done
  
}


# Disable swap
onnodes ("sudo swapoff -a")
onnodes ("sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab")

onnodes ("sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF")