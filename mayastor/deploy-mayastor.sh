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


# Create namespace
echo
echo "${YELLOW}Create namespace....${NC}"
kubectl create namespace mayastor


# RBAC Resources
echo
echo "${YELLOW}RBAC Resources....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/operator-rbac.yaml

# Custom Resource Definitions
echo
echo "${YELLOW}Custom Resource Definitions....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/mayastorpoolcrd.yaml


# Deploy Mayastor Dependencies
echo
echo "${YELLOW}Deploy Mayastor Dependencies....${NC}"
# NATS
echo
echo "${YELLOW}NATS....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/nats-deployment.yaml



# etcd
echo
echo "${YELLOW}etcd....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/storage/localpv.yaml
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/statefulset.yaml 
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/svc.yaml
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/svc-headless.yaml


# Deploy Mayastor Components
echo
echo "${YELLOW}Deploy Mayastor Components....${NC}"
echo
echo "${YELLOW}CSI Node Plugin....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/csi-daemonset.yaml


# Control Plane
echo
echo "${YELLOW}Control Plane....${NC}"
# Core Agents
echo
echo "${YELLOW}Core Agents....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/core-agents-deployment.yaml

# REST
echo
echo "${YELLOW}REST....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/rest-deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/rest-service.yaml

# CSI Controller
echo
echo "${YELLOW}CSI Controller....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/csi-deployment.yaml

# MSP Operator
echo
echo "${YELLOW}MSP Operator....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/msp-deployment.yaml

# Data Plane
echo
echo "${YELLOW}Data Plane....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/mayastor-daemonset.yaml
echo
echo "${RED}Check mayastor daemonset running before continue....${NC}"
echo "kubectl -n mayastor get daemonset mayastor"
echo 
echo "kubectl -n mayastor get nodes"