#!/bin/bash
set -euo pipefail

#==============================
# Configuration
#==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

nodes=("node1" "node2" "node3" "node4")
masternode="node1"
workernodes=("node2" "node3" "node4")
user="root"

#==============================
# SSH Key distribution
#==============================
echo -e "${YELLOW}🔑 Génération et distribution de la clé SSH...${NC}"
[[ ! -f ~/.ssh/id_rsa ]] && ssh-keygen -q -f ~/.ssh/id_rsa -N ""

for node in "${nodes[@]}"; do
  echo -e "${BLUE}→ Copie de la clé SSH vers ${node}${NC}"
  ssh-copy-id -o StrictHostKeyChecking=no "${user}@${node}" >/dev/null 2>&1 || {
    echo -e "${RED}Erreur : impossible de copier la clé vers ${node}${NC}"
    exit 1
  }
done

#==============================
# Script distant commun
#==============================
remote_setup=$(cat <<'EOF'
set -euo pipefail

echo "[INFO] ⏰ Synchronisation de l’horloge"
sudo hwclock --hctosys

echo "[INFO] 🧹 Désactivation du swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "[INFO] 🧩 Chargement des modules noyau"
cat <<EOT | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
nvme_tcp
ext4
xfs
EOT
sudo modprobe overlay br_netfilter

echo "[INFO] ⚙️  Configuration sysctl"
cat <<EOT | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOT
sudo sysctl --system >/dev/null

echo "[INFO] 📦 Mise à jour du système"
sudo apt update -y && sudo apt upgrade -y

echo "[INFO] 🐳 Installation de containerd"
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update -y
sudo apt install -y containerd.io

echo "[INFO] 🧾 Configuration de containerd"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i '/disabled_plugins/s/^/#/' /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl enable --now containerd
sudo systemctl restart containerd

echo "[INFO] 🔑 Installation de Kubernetes (kubeadm, kubelet, kubectl)"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt update -y && sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
EOF
)

#==============================
# Configuration parallèle
#==============================
echo -e "${YELLOW}⚙️  Configuration des nœuds en parallèle...${NC}"

for node in "${nodes[@]}"; do
  echo -e "${BLUE}→ Démarrage configuration de ${node}${NC}"
  (
    ssh -o StrictHostKeyChecking=no "${user}@${node}" "bash -s" <<<"$remote_setup"
    echo -e "${GREEN}✔️  Configuration terminée pour ${node}${NC}"
  ) &
done

wait
echo -e "${GREEN}✅ Tous les nœuds sont configurés !${NC}"

#==============================
# Initialisation du master
#==============================
echo -e "${YELLOW}🚀 Initialisation du cluster Kubernetes sur ${masternode}${NC}"
ssh -o StrictHostKeyChecking=no "${user}@${masternode}" "bash -s" <<EOF
set -e
if [ -f /etc/kubernetes/admin.conf ]; then
  echo '[INFO] ✅ Cluster déjà initialisé, on saute kubeadm init.'
else
  echo '[INFO] 🚀 Initialisation du cluster Kubernetes...'
  sudo kubeadm reset -f || true
  sudo systemctl restart containerd
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=${masternode} --upload-certs
  mkdir -p /root/.kube
  sudo cp /etc/kubernetes/admin.conf /root/.kube/config
  sudo chown root:root /root/.kube/config
  echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc
  wget -q -O - https://github.com/derailed/k9s/releases/download/v0.50.16/k9s_Linux_amd64.tar.gz | sudo tar -xz -C /usr/local/bin k9s
fi
exit 0
EOF

#==============================
# Ajout des workers
#==============================
echo -e "${YELLOW}🔗 Ajout des nœuds workers au cluster${NC}"
join_cmd=$(ssh "${user}@${masternode}" "kubeadm token create --print-join-command")

for node in "${workernodes[@]}"; do
  echo -e "${BLUE}→ Worker ${node}${NC}"
  (
    ssh "${user}@${node}" "sudo ${join_cmd}"
    ssh "${user}@${node}" "mkdir -p /root/.kube"
    scp "${user}@${masternode}:/root/.kube/config" "${user}@${node}:/root/.kube/config" >/dev/null
    ssh "${user}@${node}" "sudo chown root:root /root/.kube/config"
    echo -e "${GREEN}✔️  Worker ${node} ajouté au cluster${NC}"
  ) &
done

wait
echo -e "${GREEN}✅ Tous les workers ont rejoint le cluster !${NC}"

#==============================
# Installation du réseau Flannel
#==============================
echo -e "${YELLOW}🌐 Installation du réseau Flannel${NC}"
ssh "${user}@${masternode}" "
  if ! kubectl get pods -n kube-flannel >/dev/null 2>&1; then
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  else
    echo '[INFO] Flannel déjà installé, on saute cette étape.'
  fi
"

echo -e "${GREEN}✅ Cluster Kubernetes prêt !${NC}"
echo -e "👉 Commandes utiles :
  kubectl get nodes -o wide
  kubectl get pods -A
  k9s${NC}"
