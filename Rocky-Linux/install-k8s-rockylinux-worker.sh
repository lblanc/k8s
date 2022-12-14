#!/bin/bash

# Define some colours for later
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
ORANGE='\033[1;33]'
NC='\033[0m' # No Color


# K8s version
k8sversion=1.24.4

echo -e "${BLUE}Set some prerequisites....${NC}"


# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


# selinux permissive
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config


# Configure Firewall
sudo systemctl disable --now firewalld.service
#sudo firewall-cmd --permanent --add-port=10250/tcp
#sudo firewall-cmd --permanent --add-port=30000-32767/tcp                                                  
#sudo firewall-cmd --reload
sudo modprobe br_netfilter
sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-ip6tables"
sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables"
sudo sh -c "echo '1' > /proc/sys/net/ipv4/ip_forward"


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

reboot