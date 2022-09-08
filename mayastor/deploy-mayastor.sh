#!/bin/bash

# Worker nodes list who will host mayastor
nodesmayastor="node2 node3 node4"

for node in ${nodesmayastor}; do
 
    kubectl label node ${node} openebs.io/engine=mayastor
 
done 

# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33]'
NC='\033[0m' # No Color


# Create namespace
echo
echo -e "${ORANGE}Create namespace....${NC}"
kubectl create namespace mayastor


# RBAC Resources
echo
echo -e "${ORANGE}RBAC Resources....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/operator-rbac.yaml

# Custom Resource Definitions
echo
echo -e "${ORANGE}Custom Resource Definitions....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/mayastorpoolcrd.yaml


# Deploy Mayastor Dependencies
echo
echo -e "${ORANGE}Deploy Mayastor Dependencies....${NC}"
# NATS
echo
echo -e "${ORANGE}NATS....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/nats-deployment.yaml
echo -e "${RED}Check if NATS running before continue....${NC}"
echo "kubectl -n mayastor get pods --selector=app=nats"
read -p "Press [Enter] key to resume..."


# etcd
echo
echo -e "${ORANGE}etcd....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/storage/localpv.yaml
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/statefulset.yaml 
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/svc.yaml
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/svc-headless.yaml
echo -e "${RED}Check if etcd running before continue....${NC}"
echo "kubectl -n mayastor get pods --selector=app.kubernetes.io/name=etcd"
read -p "Press [Enter] key to resume..."

# Deploy Mayastor Components
echo
echo -e "${ORANGE}Deploy Mayastor Components....${NC}"
echo
echo -e "${ORANGE}CSI Node Plugin....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/csi-daemonset.yaml
echo -e "${RED}Check if CSI Node Plugin running before continue....${NC}"
echo "kubectl -n mayastor get daemonset mayastor-csi"
read -p "Press [Enter] key to resume..."

# Control Plane
echo
echo -e "${ORANGE}Control Plane....${NC}"
# Core Agents
echo
echo -e "${ORANGE}Core Agents....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/core-agents-deployment.yaml
echo -e "${RED}Check if Core Agents running before continue....${NC}"
echo "kubectl get pods -n mayastor --selector=app=core-agents"
read -p "Press [Enter] key to resume..."
# REST
echo
echo -e "${ORANGE}REST....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/rest-deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/rest-service.yaml
echo -e "${RED}Check if REST running before continue....${NC}"
echo "kubectl get pods -n mayastor --selector=app=rest"
read -p "Press [Enter] key to resume..."
# CSI Controller
echo
echo -e "${ORANGE}CSI Controller....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/csi-deployment.yaml
echo -e "${RED}Check if CSI Controller running before continue....${NC}"
echo "kubectl get pods -n mayastor --selector=app=csi-controller"
read -p "Press [Enter] key to resume..."
# MSP Operator
echo
echo -e "${ORANGE}MSP Operator....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/msp-deployment.yaml
echo -e "${RED}Check if MSP Operator running before continue....${NC}"
echo "kubectl get pods -n mayastor --selector=app=msp-operator"
read -p "Press [Enter] key to resume..."
# Data Plane
echo
echo -e  "${ORANGE}Data Plane....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/mayastor-daemonset.yaml
echo -e "${RED}Check mayastor daemonset running before continue....${NC}"
echo "kubectl -n mayastor get daemonset mayastor"
echo 
echo "kubectl mayastor get nodes"