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

$ sudo modprobe overlay
$ sudo modprobe br_netfilter







# Update
echo -e "${BLUE}System update....${NC}"
sudo dnf update -y


# Install Docker
echo -e "${BLUE}Install Docker....${NC}"
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install docker-ce -y
sudo systemctl start docker
sudo systemctl enable docker


# Install kubelet, Kubeadm and kubectl
echo -e "${BLUE}Install kubelet, Kubeadm and kubectl....${NC}"
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
#exclude=kubelet kubeadm kubectl
EOF
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