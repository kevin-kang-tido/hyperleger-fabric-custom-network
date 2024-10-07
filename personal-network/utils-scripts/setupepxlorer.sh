#!/bin/bash

exit # to prevent the execution of the script

echo "Setup the explorer...." 
echo "This is the current directory : $(pwd) " 

function setupExplorer(){
    # Clone the repository of explorer 
    git clone https://github.com/hyperledger/blockchain-explorer.git
    cd blockchain-explorer

    # we will have to update the connection profile of the explorer 

    mkdir -p hyperledger-explorer/config 
    mkdir -p hyperledger-explorer/connection-profile

}