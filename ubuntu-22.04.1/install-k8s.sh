#!/bin/bash


#
# Run this script on master, with good hosts file and ssh key exchange with workers nodes "ssh-copy-id"
#

# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Mastes + Workers nodes list
nodes="node1 node2 node3 node4"

# K8s version & version
k8sversion=1.24.4
clustername="Lab-Cluster"

# Linux user
user="user"


for node in ${nodes}; do

# Disable swap
echo -e "${YELLOW}Disable swap on node: $node${NC}"
ssh ${user}@${node} "sudo swapoff -a"
ssh ${user}@${node} "sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"

# Kernel modules
echo -e "${YELLOW}Load Kernel modules on node: $node${NC}"
ssh ${user}@${node} "sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF"
ssh ${user}@${node} "sudo modprobe overlay"
ssh ${user}@${node} "sudo modprobe br_netfilter"

# Update
echo -e "${YELLOW}System update on node: $node${NC}"
ssh ${user}@${node} "sudo apt update -y"
ssh ${user}@${node} "sudo apt upgrade -y"

# Enable Forwarding
echo -e "${YELLOW}Enable Forwarding on node: $node${NC}"
ssh ${user}@${node} "sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF"
ssh ${user}@${node} "sudo sysctl --system"


# Install containerd runtime
echo -e "${YELLOW}Install containerd runtime on node: $node${NC}"
ssh ${user}@${node} "sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates"
ssh ${user}@${node} "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg"
ssh ${user}@${node} 'sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"'
ssh ${user}@${node} "sudo apt update"
ssh ${user}@${node} "sudo apt install -y containerd.io"
ssh ${user}@${node} "containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1"
ssh ${user}@${node} "sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml"
ssh ${user}@${node} "sudo systemctl restart containerd"
ssh ${user}@${node} "sudo systemctl enable containerd"

# Add apt repository for Kubernetes
echo -e "${YELLOW}Add apt repository for Kubernetes on node: $node${NC}"
ssh ${user}@${node} "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -"
ssh ${user}@${node} "sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main""



done