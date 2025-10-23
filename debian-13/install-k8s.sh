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

# ssh no StrictHostKeyChecking
alias ssh="ssh  -o 'StrictHostKeyChecking no'"

# Exchange rsa key with nodes
echo "${YELLOW}Exchange rsa key with nodes${NC}"
ssh-keygen -q  -f ~/.ssh/id_rsa  -N ""

for node in ${nodes}; do
ssh ${user}@${node} "sudo hwclock --hctosys"
ssh-copy-id ${user}@${node}
done


for node in ${nodes}; do


# Disable swap
echo "${YELLOW}Disable swap on node: $node${NC}"
ssh ${user}@${node} "sudo swapoff -a"
ssh ${user}@${node} "sudo sed -i '/ swap / s/^/#/' /etc/fstab"

# Kernel modules
echo "${YELLOW}Load Kernel modules on node: $node${NC}"
ssh ${user}@${node} "cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF"
ssh ${user}@${node} "sudo modprobe overlay"
ssh ${user}@${node} "sudo modprobe br_netfilter"

# Enable Forwarding
echo "${YELLOW}Enable Forwarding on node: $node${NC}"
ssh ${user}@${node} "sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF"
ssh ${user}@${node} "sudo sysctl --system"

# Update
echo "${YELLOW}System update on node: $node${NC}"
ssh ${user}@${node} "sudo apt update -y"
ssh ${user}@${node} "sudo apt upgrade -y"




# Install containerd runtime
echo "${YELLOW}Install containerd runtime on node: $node${NC}"
ssh ${user}@${node} "sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release"

ssh ${user}@${node} "sudo mkdir -p /etc/apt/keyrings"
ssh ${user}@${node} "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"

ssh ${user}@${node} "echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"

ssh ${user}@${node} "sudo apt update"
ssh ${user}@${node} "sudo apt install -y containerd.io"

ssh ${user}@${node} "sudo mkdir -p /etc/containerd"
ssh ${user}@${node} "containerd config default | sudo tee /etc/containerd/config.toml > /dev/null"
ssh ${user}@${node} "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml"
ssh ${user}@${node} "sudo systemctl restart containerd"
ssh ${user}@${node} "sudo systemctl enable containerd"



# Add apt repository for Kubernetes
echo "${YELLOW}Add apt repository for Kubernetes on node: $node${NC}"
ssh ${user}@${node} "sudo apt update"
ssh ${user}@${node} "sudo apt install -y apt-transport-https ca-certificates curl gpg"

ssh ${user}@${node} "sudo mkdir -p /etc/apt/keyrings"
ssh ${user}@${node} "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"

ssh ${user}@${node} "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"


# Install Kubernetes components Kubectl, kubeadm & kubelet
echo "${YELLOW}Install Kubernetes components Kubectl, kubeadm & kubelet on node: $node${NC}"

ssh ${user}@${node} "sudo apt update"
ssh ${user}@${node} "sudo apt install -y kubelet kubeadm kubectl"
ssh ${user}@${node} "sudo apt-mark hold kubelet kubeadm kubectl"


done


# Initialize Kubernetes cluster with Kubeadm
echo "${YELLOW}Initialize Kubernetes cluster with Kubeadm on master node: $masternode${NC}"
ssh ${user}@${masternode} "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=${masternode}"
ssh ${user}@${masternode} "mkdir -p $HOME/.kube"
ssh ${user}@${masternode} "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config"
ssh ${user}@${masternode} "sudo chown $(id -u):$(id -g) $HOME/.kube/config"
ssh ${user}@${node} "tar -xvz  -f <(wget -q -O - https://github.com/derailed/k9s/releases/download/v0.50.16/k9s_Linux_amd64.tar.gz ) k9s"

sleep 30



# Join worker nodes
echo "${YELLOW}Create kube join command${NC}"
command=$(ssh ${user}@${masternode} "kubeadm token create --print-join-command")

for node in ${workernodes}; do
echo "${YELLOW}Join worker node: $node${NC}"
ssh ${user}@${node} "sudo ${command}"       
ssh ${user}@${node} "mkdir -p $HOME/.kube"
scp ${user}@${masternode}:$HOME/.kube/config ${user}@${node}:$HOME/.kube/config
ssh ${user}@${node} "sudo chown $(id -u):$(id -g) $HOME/.kube/config" 
done

sleep 10

# Install Flannel Pod Network Add-on
echo "${YELLOW}Install Flannel Pod Network Add-on ${NC}"
ssh ${user}@${masternode} "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

./k9s
