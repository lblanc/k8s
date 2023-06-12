#!/bin/bash

# Linux user
user="user"
alias ssh="ssh  -o 'StrictHostKeyChecking no'"

# Worker nodes list who will host mayastor
nodesmayastor="node2 node3 node4"

#rawdisk="/dev/vdb"
rawdisk="/media/ramdisk"


for node in ${nodesmayastor}; do


ssh ${user}@${nodesmayastor} "sudo mkdir /media/ramdisk"
ssh ${user}@${nodesmayastor} "sudo mount -t tmpfs -o size=2G tmpfs /media/ramdisk"
 
cat <<EOF | kubectl create -f -
apiVersion: "openebs.io/v1alpha1"
kind: DiskPool
metadata:
  name: pool-$node
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
