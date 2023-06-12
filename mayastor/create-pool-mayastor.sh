#!/bin/bash

# Worker nodes list who will host mayastor
nodesmayastor="node2 node3 node4"

#rawdisk="/dev/vdb"
rawdisk="malloc:///malloc0?size_mb=2048"


for node in ${nodesmayastor}; do
 
 
cat <<EOF | kubectl create -f -
apiVersion: "openebs.io/v1alpha1"
kind: DiskPool
metadata:
  name: pool-on-$node
  namespace: mayastor
spec:
  node: $node
  disks: ["$rawdisk"]
EOF
 
done 

echo
echo "${RED}Verify Pool Creation and Status before continue....${NC}"
echo "kubectl get dsp -n mayastor"
echo 
kubectl get dsp -n mayastor
