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
ssh ${user}@${node} "modprobe overlay"
ssh ${user}@${node} "modprobe br_netfilter"

# Update
echo -e "${YELLOW}System update on node: $node${NC}"
sudo apt update -y
sudo apt upgrade -y

# Enable Forwarding
echo -e "${YELLOW}Enable Forwarding on node: $node${NC}"
ssh ${user}@${node} "sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF "
ssh ${user}@${node} "sudo sysctl --system"









done




sudo dnf install -y wget tar kubelet-${k8sversion}-0 kubeadm-${k8sversion}-0 kubectl-${k8sversion}-0 --disableexcludes=kubernetes
sudo systemctl enable --now kubelet


# Install Kubernetes Cluster with Kubeadm
echo -e "${BLUE}Install Kubernetes Cluster with Kubeadm....${NC}"
cat <<EOF | sudo tee kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: "${k8sversion}"
#clusterName: "${clustername}"
networking:
  podSubnet: "10.244.0.0/16" # --pod-network-cidr
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: cgroupfs
EOF

sudo kubeadm init --config kubeadm-config.yaml

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes


# Installing calico as network ad-on
echo -e "${BLUE}Installing calico as network ad-on....${NC}"
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/canal.yaml

tar -xvz  -f <(wget -q -O - https://github.com/derailed/k9s/releases/download/v0.26.3/k9s_Linux_x86_64.tar.gz ) k9s

reboot