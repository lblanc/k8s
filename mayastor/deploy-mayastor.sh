#!/bin/bash

# Worker nodes list who will host mayastor
nodesmayastor="node2 node3 node4"


for node in ${nodesmayastor}; do
 
    kubectl label node ${node} openebs.io/engine=mayastor
 
done 

# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Install helm
echo
echo "${YELLOW}install helm....${NC}"
wget https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz
tar -xvz  -f helm-v3.12.0-linux-amd64.tar.gz linux-amd64/helm
sudo mv ./linux-amd64/helm /usr/local/bin/helm
sudo rm -fR ./linux-amd64
sudo rm -fR helm-v3.12.0-linux-amd64.tar.gz


# Add the OpenEBS Helm repository.
echo
echo "${YELLOW}Add the mayastor Helm repository....${NC}"
helm repo add mayastor https://openebs.github.io/mayastor-extensions/
helm repo update



# install OpenEBS version 
echo
echo "${YELLOW}Install  mayastor 2.2.0 ....${NC}"
helm install mayastor mayastor/mayastor -n mayastor --create-namespace --version 2.2.0 --set etcd.persistence.storageClass="manual" --set loki-stack.loki.persistence.storageClassName="manual"



# install OpenEBS Plugin
echo
echo "${YELLOW}Install Mayastor Plugin 2.2....${NC}"
wget "https://github.com/openebs/mayastor-control-plane/releases/download/v2.2.0/kubectl-mayastor-x86_64-linux-musl"
sudo mv kubectl-mayastor-x86_64-linux-musl /usr/local/bin/kubectl-mayastor
chmod +x /usr/local/bin/kubectl-mayastor
kubectl mayastor -V



# End
echo
echo "${RED}Check mayastor daemonset running before continue....${NC}"
echo "kubectl -n mayastor get daemonset mayastor"
echo 
echo "kubectl -n mayastor get nodes"
echo 
echo "Use this link to configure Mayastor"
echo "   https://mayastor.gitbook.io/introduction/quickstart/configure-mayastor"
