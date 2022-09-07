#!/bin/bash

# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33]'
NC='\033[0m' # No Color

echo -e "${ORANGE}Set some prerequisites....${NC}"

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


# selinux permissive
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config


# Configure Firewall
sudo systemctl enable --now firewalld.service
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --reload
sudo modprobe br_netfilter
sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables"
sudo sh -c "echo '1' > /proc/sys/net/ipv4/ip_forward"


# Update
echo -e "${ORANGE}System update....${NC}"
sudo dnf update -y


# Install Docker
echo -e "${ORANGE}Install Docker....${NC}"
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install docker-ce -y
sudo systemctl start docker
sudo systemctl enable docker


# Install kubelet, Kubeadm and kubectl
echo -e "${ORANGE}Install kubelet, Kubeadm and kubectl....${NC}"
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
sudo dnf install -y kubelet-1.23.10-0 kubeadm-1.23.10-0 kubectl-1.23.10-0 --disableexcludes=kubernetes
sudo systemctl enable --now kubelet


# Install Kubernetes Cluster with Kubeadm
echo -e "${ORANGE}Install Kubernetes Cluster with Kubeadm....${NC}"
cat <<EOF | sudo tee kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: "v1.23.10"
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
echo -e "${ORANGE}Installing calico as network ad-on....${NC}"
kubectl apply -f https://docs.projectcalico.org/v3.24/manifests/calico.yaml