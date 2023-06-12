#!/bin/bash


# Define some colours for later
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33]'
NC='\033[0m' # No Color

    

for node in ${nodes}; do
 
    kubectl label node ${nodesmayastor} openebs.io/engine-
 
done

# Delete namespace
echo
echo -e "${ORANGE}Delete namespace....${NC}"
kubectl delete namespace mayastor


