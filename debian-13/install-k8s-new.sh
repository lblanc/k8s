#!/bin/bash
set -euo pipefail

# ===========================
# Colors
# ===========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ===========================
# Configuration
# ===========================
nodes=("node1" "node2" "node3" "node4")
masternode="node1"
workernodes=("node2" "node3" "node4")
user="root"

# Disable SSH host key checking for automation
alias ssh="ssh -o StrictHostKeyChecking=no"

# ===========================
# SSH Key Setup
# ===========================
echo -e "${YELLOW}Generating SSH key and distributing to nodes...${NC}"
[[ ! -f ~/.ssh/id_rsa ]] && ssh-keygen -q -f ~/.ssh/id_rsa -N ""

for node in "${nodes[@]}"; do
  echo -e "${BLUE}→ Copying SSH key to $node${NC}"
  ssh-copy-id -o StrictHostKeyChecking=no "${user}@${node}" >/dev/null 2>&1
  ssh "${user}@${node}" "sudo hwclock --hctosys" || true
done

# ===========================
# Function to configure node
# ===========================
configure_node() {
  node="$1"
  echo -e "${YELLOW}Configuring node: ${node}${NC}"

  ssh "${user}@${node}" bash -s <<'EOF'
set -euo pipefail

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
sudo tee /etc/modules-load.d/k8s.conf >/dev/null <<MODULES
overlay
br_netfilter
nvme_tcp
ext4
xfs
MODULES
sudo modprobe overlay br_netfilter

# Enable IP forwarding
sudo tee /etc/sysctl.d/k8s.conf >/dev/null <<SYSCTL
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
SYSCTL
sudo sysctl --system >/dev/null

# System update
sudo apt-get update -y && sudo apt-get upgrade -y

# Install containerd
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update -y && sudo apt-get install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl enable --now containerd

# Install Kubernetes components
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
EOF
}

# ===========================
# Configure all nodes in parallel
# ===========================
echo -e "${YELLOW}Applying configuration to all nodes...${NC}"
for node in "${nodes[@]}"; do
  configure_node "${node}" &
done
wait

# ===========================
# Initialize Master
# ===========================
echo -e "${YELLOW}Initializing Kubernetes master on ${masternode}${NC}"
ssh "${user}@${masternode}" bash -s <<EOF
set -euo pipefail
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=${masternode}
mkdir -p \$HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
wget -q -O - https://github.com/derailed/k9s/releases/download/v0.50.16/k9s_Linux_amd64.tar.gz | tar xz k9s
EOF

sleep 20

# ===========================
# Join worker nodes
# ===========================
echo -e "${YELLOW}Generating join command...${NC}"
join_cmd=$(ssh "${user}@${masternode}" "kubeadm token create --print-join-command")

for node in "${workernodes[@]}"; do
  echo -e "${BLUE}→ Joining ${node} to cluster${NC}"
  ssh "${user}@${node}" "sudo ${join_cmd}"
  ssh "${user}@${node}" "mkdir -p \$HOME/.kube"
  scp "${user}@${masternode}:\$HOME/.kube/config" "${user}@${node}:\$HOME/.kube/config"
  ssh "${user}@${node}" "sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
done

# ===========================
# Deploy Flannel CNI
# ===========================
echo -e "${YELLOW}Deploying Flannel CNI...${NC}"
ssh "${user}@${masternode}" "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

# ===========================
# Start K9s
# ===========================
ssh "${user}@${masternode}" "./k9s"
echo -e "${GREEN}Cluster setup complete!${NC}"
