#!/bin/bash
exit 0 
# this should be inside the personal-network directory 
export WORKSHOP_PATH=$(pwd)
echo "The path of the binaries is ${WORKSHOP_PATH}"
export PATH=$PATH:$(pwd)/bin


# this typically contains three different files such as core.yaml, orderer.yaml, configtx.yaml 
export FABRIC_CFG_PATH=${WORKSHOP_PATH}/config 