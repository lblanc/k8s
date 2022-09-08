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
sleep 60


# etcd
echo
echo -e "${ORANGE}etcd....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/storage/localpv.yaml
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/statefulset.yaml 
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/svc.yaml
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/svc-headless.yaml
sleep 20

# Deploy Mayastor Components
echo
echo -e "${ORANGE}Deploy Mayastor Components....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/csi-daemonset.yaml
sleep 20

# Control Plane
echo
echo -e "${ORANGE}Control Plane....${NC}"
# Core Agents
echo
echo -e "${ORANGE}Core Agents....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/core-agents-deployment.yaml
sleep 20
# REST
echo
echo -e "${ORANGE}REST....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/rest-deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/rest-service.yaml
sleep 20
# CSI Controller
echo
echo -e "${ORANGE}CSI Controller....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/csi-deployment.yaml
sleep 20
# MSP Operator
echo
echo -e "${ORANGE}MSP Operator....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/msp-deployment.yaml
sleep 20
# Data Plane
echo
echo -e  "${ORANGE}Data Plane....${NC}"
kubectl apply -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/mayastor-daemonset.yaml