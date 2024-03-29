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

# K8s version & version
k8sversion=1.23.17

# Linux user
user="user"
alias ssh="ssh  -o 'StrictHostKeyChecking no'"

# Exchange rsa key with nodes
echo "${YELLOW}Exchange rsa key with nodes${NC}"
ssh-keygen -q  -f ~/.ssh/id_rsa  -N ""

for node in ${nodes}; do
ssh ${user}@${node} "sudo hwclock --hctosys"
ssh-copy-id ${user}@${node}
done


for node in ${nodes}; do

# Enable ufw and rules
echo "${YELLOW}Enable ufw and rules on node: $node${NC}"
ssh ${user}@${node} "sudo ufw allow ssh"
ssh ${user}@${node} "sudo ufw --force enable"
ssh ${user}@${node} "sudo ufw allow from 192.168.1.0/24"
ssh ${user}@${node} "sudo ufw allow from 10.244.0.0/16"


# Disable swap
echo "${YELLOW}Disable swap on node: $node${NC}"
ssh ${user}@${node} "sudo swapoff -a"
ssh ${user}@${node} "sudo sed -i '/swap.img/d' /etc/fstab"

# Kernel modules
echo "${YELLOW}Load Kernel modules on node: $node${NC}"
ssh ${user}@${node} "sudo tee /etc/modules-load.d/modules.conf <<EOF
overlay
br_netfilter
EOF"
ssh ${user}@${node} "sudo modprobe overlay"
ssh ${user}@${node} "sudo modprobe br_netfilter"

# Update
echo "${YELLOW}System update on node: $node${NC}"
ssh ${user}@${node} "sudo apt update -y"
ssh ${user}@${node} "sudo apt upgrade -y"

# Enable Forwarding
echo "${YELLOW}Enable Forwarding on node: $node${NC}"
ssh ${user}@${node} "sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF"
ssh ${user}@${node} "sudo sysctl --system"


# Install containerd runtime
echo "${YELLOW}Install containerd runtime on node: $node${NC}"
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
echo "${YELLOW}Add apt repository for Kubernetes on node: $node${NC}"
ssh ${user}@${node} "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -"
ssh ${user}@${node} "sudo apt-add-repository 'deb http://apt.kubernetes.io/ kubernetes-xenial main'"

# Install Kubernetes components Kubectl, kubeadm & kubelet
echo "${YELLOW}Install Kubernetes components Kubectl, kubeadm & kubelet on node: $node${NC}"
ssh ${user}@${node} "sudo apt install -y bash-completion wget tar kubelet=${k8sversion}-00 kubeadm=${k8sversion}-00 kubectl=${k8sversion}-00"
ssh ${user}@${node} "sudo apt-mark hold kubelet=${k8sversion}-00 kubeadm=${k8sversion}-00 kubectl=${k8sversion}-00"
ssh ${user}@${node} "tar -xvz  -f <(wget -q -O - https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz ) k9s"
ssh ${user}@${node} "kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"

done


# Initialize Kubernetes cluster with Kubeadm
echo "${YELLOW}Initialize Kubernetes cluster with Kubeadm on master node: $masternode${NC}"
ssh ${user}@${masternode} "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=${masternode}"
ssh ${user}@${masternode} "mkdir -p $HOME/.kube"
ssh ${user}@${masternode} "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config"
ssh ${user}@${masternode} "sudo chown $(id -u):$(id -g) $HOME/.kube/config"
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
