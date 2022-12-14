#!/bin/bash


# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33]'
NC='\033[0m' # No Color

# Worker nodes list who will host mayastor
nodesmayastor="node2 node3 node4"
    

for node in ${nodes}; do
 
    kubectl label node ${nodesmayastor} openebs.io/engine-
 
done

# Delete namespace
echo
echo -e "${ORANGE}Delete namespace....${NC}"
kubectl delete namespace mayastor


# RBAC Resources
echo
echo -e "${ORANGE}RBAC Resources....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/operator-rbac.yaml

# Custom Resource Definitions
echo
echo -e "${ORANGE}Custom Resource Definitions....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/mayastorpoolcrd.yaml


# Deploy Mayastor Dependencies
echo
echo -e "${ORANGE}Deploy Mayastor Dependencies....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/nats-deployment.yaml


# etcd
echo
echo -e "${ORANGE}etcd....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/storage/localpv.yaml
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/statefulset.yaml 
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/svc.yaml
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/etcd/svc-headless.yaml


# Deploy Mayastor Components
echo
echo -e "${ORANGE}Deploy Mayastor Components....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/csi-daemonset.yaml

# Control Plane
echo
echo -e "${ORANGE}Control Plane....${NC}"
# Core Agents
echo
echo -e "${ORANGE}Core Agents....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/core-agents-deployment.yaml

# REST
echo
echo -e "${ORANGE}REST....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/rest-deployment.yaml
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/rest-service.yaml

# CSI Controller
echo
echo -e "${ORANGE}CSI Controller....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/csi-deployment.yaml

# MSP Operator
echo
echo -e "${ORANGE}MSP Operator....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor-control-plane/master/deploy/msp-deployment.yaml

# Data Plane
echo
echo -e  "${ORANGE}Data Plane....${NC}"
kubectl delete -f https://raw.githubusercontent.com/openebs/mayastor/master/deploy/mayastor-daemonset.yaml





