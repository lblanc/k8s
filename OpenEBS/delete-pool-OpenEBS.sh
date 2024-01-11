#!/bin/bash

# Worker nodes list who will host mayastor
nodesmayastor="node2 node3 node4"

rawdisk="/dev/vdb"

for node in ${nodesmayastor}; do
 
cat <<EOF | kubectl delete -f -
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
