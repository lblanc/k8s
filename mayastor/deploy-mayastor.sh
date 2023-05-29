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
tar -xvz  -f <(wget -q -O - https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz) linux-amd64/helm
sudo mv linux-amd64/helm /usr/local/bin/helm
sudo rm -fR linux-amd64


# Add the OpenEBS Mayastor Helm repository.
echo
echo "${YELLOW}Add the OpenEBS Mayastor Helm repository....${NC}"
helm repo add mayastor https://openebs.github.io/mayastor-extensions/ 



# install Mayastor _version 2.2.
echo
echo "${YELLOW}Install Mayastor _version 2.2....${NC}"
helm install mayastor mayastor/mayastor -n mayastor --create-namespace --version 2.2.0



# End
echo
echo "${RED}Check mayastor daemonset running before continue....${NC}"
echo "kubectl -n mayastor get daemonset mayastor"
echo 
echo "kubectl -n mayastor get nodes"
echo 
echo "Use this link to configure Mayastor"
echo "   https://mayastor.gitbook.io/introduction/quickstart/configure-mayastor"
