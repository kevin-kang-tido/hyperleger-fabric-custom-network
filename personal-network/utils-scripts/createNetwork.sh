#!/bin/bash

# to make the script exits if there is an error 
set -e
set -o pipefail 
function init(){
    echo "Adding the bin of hyperledger fabric to the PATH..."
    export PATH=$PATH:/home/keo/Documents/blockchain_related/simple-blockchain-demon/personal-network/bin
    # we should use this 
    # export .. $(pwd)/config 
    export FABRIC_CFG_PATH=/home/keo/Documents/blockchain_related/simple-blockchain-demon/personal-network/config
}

function generateCryptoConfig(){

    # crypto-materials 
    echo "I.Generating crypto-config artifacts..."
    cryptogen generate --config=crypto-config.yaml \
        --output=crypto-config

}

function generateChannelArtifacts(){
    echo "II.Generating channel-artifacts..."
    echo "1. Creating the genesis block..."
    mkdir -p channel-artifacts
    configtxgen -profile OrdererGenesis \
        -outputBlock ./channel-artifacts/genesis.block \
        -channelID channelorderergenesis

    echo "2. Generate channel configuration transaction..."
    configtxgen -profile Channel \
        -outputCreateChannelTx ./channel-artifacts/channel.tx \
        -channelID channeldemo
    echo "3. Generate anchor peer transaction(Org1)..."
    configtxgen -profile Channel \
        -outputAnchorPeersUpdate ./channel-artifacts/Org1Anchor.tx \
        -channelID channeldemo -asOrg Org1MSP
    echo "4. Generate anchor peer transaction(Org2)..."
    configtxgen -profile Channel \
        -outputAnchorPeersUpdate ./channel-artifacts/Org2Anchor.tx \
        -channelID channeldemo -asOrg Org2MSP
}


function upNetwork(){
    echo "---> Bring Up the network........."
    echo -e "\t Adding env to the file for the project...."
    echo COMPOSE_PROJECT_NAME=net > .env 
    echo CURRENT_DIR=$PWD >> .env
    docker-compose -f docker-compose-cli.yaml up -d

    # echo "Waiting for the container to be up and running ... " 
    #     containers=("peer0.org1.personal-network.com" "peer0.org2.personal-network.com" "orderer.personal-network.com" "cli")
    
    # for container in "${containers[@]}"; do
    #     echo "Checking $container..."
    #     while true; do
    #         status=$(docker inspect -f '{{.State.Status}}' $container 2>/dev/null)
    #         if [ "$status" = "running" ]; then
    #             echo "$container is up and running"
    #             break
    #         elif [ "$status" = "exited" ] || [ "$status" = "dead" ]; then
    #             echo "Error: $container has stopped or failed to start"
    #             return 1
    #         else
    #             echo "Waiting for $container to be ready..."
    #             sleep 5
    #         fi
    #     done
    # done

    echo "All containers are up and running"
    
    # Check if containers are healthy (if health checks are configured)
    for container in "${containers[@]}"; do
        health=$(docker inspect -f '{{.State.Health.Status}}' $container 2>/dev/null)
        if [ "$health" = "healthy" ]; then
            echo "$container is healthy"
        elif [ "$health" = "unhealthy" ]; then
            echo "Warning: $container is unhealthy"
        fi
    done

    echo "Network is ready for the next steps"
}
function setOrgEnv(){
    local org=$1
    local peer=$2
    local port=$3

    echo "1. Setting the env variables for <<$org>>..."
    export CORE_PEER_LOCALMSPID="${org}MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/peers/${peer}.${org}.personal-network.com/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/users/Admin@${org}.personal-network.com/msp"
    export CORE_PEER_ADDRESS="${peer}.${org}.personal-network.com:${port}"
      
    echo "2. Exporting the orderer CA..."
    export ORDERER_CA="/opt/gopath/fabric-samples/personal-network/crypto-config/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem"


}
function createChannel(){
    upNetwork
    echo "Running stuff on the <<Org1>> via the cli container..."
    docker exec -it cli bash -c '
        setOrgEnv(){
            local org=$1
            local peer=$2
            local port=$3
            # Convert the first letter to uppercase and the rest to lowercase
            local org_uppercase="$(tr '[:lower:]' '[:upper:]' <<< ${org:0:1})${org:1}"

            echo "1. Sourcing Variable for  <<$org_uppercase>>..."
            export CORE_PEER_LOCALMSPID="${org_uppercase}MSP"
            export CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/peers/${peer}.${org}.personal-network.com/tls/ca.crt"
            export CORE_PEER_MSPCONFIGPATH="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/users/Admin@${org}.personal-network.com/msp"
            export CORE_PEER_ADDRESS="${peer}.${org}.personal-network.com:${port}"
            

            export FABRIC_LOGGING_SPEC=INFO # either info or debug
            echo "2. Exporting the orderer CA..."
            export ORDERER_CA="/opt/gopath/fabric-samples/personal-network/crypto-config/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem"
        }
        showExported(){
            echo "orderer ca : $ORDERER_CA" 
            echo "CORE_PEER_LOCALMSPID : $CORE_PEER_LOCALMSPID"
            echo "CORE_PEER_TLS_ROOTCERT_FILE : $CORE_PEER_TLS_ROOTCERT_FILE"
            echo "CORE_PEER_MSPCONFIGPATH : $CORE_PEER_MSPCONFIGPATH"
            echo "CORE_PEER_ADDRESS : $CORE_PEER_ADDRESS"

        }
        setOrgEnv "org1" "peer0" "7051"
        echo "3.Creating the channel ( channeldemo )..."
        peer channel create -o orderer.personal-network.com:7050 -c channeldemo -f /opt/gopath/fabric-samples/personal-network/channel-artifacts/channel.tx --tls --cafile $ORDERER_CA


        echo "4.a Joining the channel (for the Org1)..."
        echo "DEBUG: Showing the values that has been exported...." 
        showExported
        peer channel join -b channeldemo.block \
            --tls --cafile $ORDERER_CA

        echo "Updating the anchor peer on Org1..."
        peer channel update -o orderer.personal-network.com:7050 \
            -c channeldemo -f /opt/gopath/fabric-samples/personal-network/channel-artifacts/Org1Anchor.tx \
            --tls --cafile $ORDERER_CA

        echo "4.b Joining the channel ( for the Org2)..."
        setOrgEnv "org2" "peer0" "7051"
        peer channel join -b channeldemo.block --tls --cafile $ORDERER_CA

        echo "Updating the anchor peer on Org2..."
        peer channel update -o orderer.personal-network.com:7050 \
            -c channeldemo -f /opt/gopath/fabric-samples/personal-network/channel-artifacts/Org2Anchor.tx \
            --tls --cafile $ORDERER_CA



        echo "---> Deploying the chaincode..."

        setOrgEnv "org1" "peer0" "7051"
        echo "3. Deploy the chaincode..."
        echo "3.1. Packaging the chaincode..."
        peer lifecycle chaincode package becc.tar.gz \
            --path /opt/gopath/src/chain/be_chaincode/go/  \
            --lang golang --label becc_1
       

        echo "3.2. Installing the chaincode on <<Org1>>..."
        peer lifecycle chaincode install becc.tar.gz
        echo "3.2. Installing the chaincode on <<Org2>>...."
        setOrgEnv "org2" "peer0" "7051"
        peer lifecycle chaincode install becc.tar.gz
        #    =================================================
        echo "3.3. Querying the installed chaincode..."
        output=$(peer lifecycle chaincode queryinstalled)
        package_id=$(echo "$output" | grep -oP "Package ID: \K[^,]+")
        CC_PACKAGE_ID=$package_id
        # package_id=becc_1:450678564457568689686867
        echo "CC_PACKAGE_ID=$CC_PACKAGE_ID"
        export CC_PACKAGE_ID=$CC_PACKAGE_ID

        echo "3.4. Approving the chaincode <<Org1>>..."
        echo "3.4.1. Increasing the timeout for the chaincode....."
        # export CORE_PEER_CHAINCODE_WAITTIME=300s
        # export CORE_PEER_CHAINCODE_STARTUPTIME=300s
        setOrgEnv "org1" "peer0" "7051"
        peer lifecycle chaincode approveformyorg -o orderer.personal-network.com:7050 --tls --cafile $ORDERER_CA --channelID channeldemo --name becc --version 1 --init-required --package-id $CC_PACKAGE_ID  --sequence 1 --signature-policy "OR('\''Org1MSP.peer'\'', '\''Org2MSP.peer'\'')"

        # --waitForEvent --waitForEventTimeout 300s


        echo "3.5. Checking the commit readiness..."
        peer lifecycle chaincode checkcommitreadiness  --channelID channeldemo  --name becc --version 1 --sequence 1 --output json --init-required --signature-policy "OR('\''Org1MSP.peer'\'', '\''Org2MSP.peer'\'')"

        echo "Exporting ENV for  <<Org2>>..."
        setOrgEnv "org2" "peer0" "7051"
        echo "3.6. Approving the chaincode <<Org2>>..."
        peer lifecycle chaincode approveformyorg \
            -o orderer.personal-network.com:7050 \
            --tls --cafile $ORDERER_CA \
            --channelID channeldemo --name becc --version 1 --init-required --package-id $CC_PACKAGE_ID \
            --sequence 1 --signature-policy "OR('\''Org1MSP.peer'\'', '\''Org2MSP.peer'\'')" 
       
        echo "3.7. Checking the commit readiness..."
        peer lifecycle chaincode checkcommitreadiness \
            --channelID channeldemo \
            --name becc --version 1 \
            --sequence 1  --output json --init-required \
            --signature-policy "OR('\''Org1MSP.peer'\'', '\''Org2MSP.peer'\'')"
        
        echo "3.8. Committing the chaincode... 🚀"
        export PEER_BE1_TLSROOTCERTFILES=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/peers/peer0.org1.personal-network.com/tls/ca.crt
        export PEER_BE2_TLSROOTCERTFILES=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/peers/peer0.org2.personal-network.com/tls/ca.crt

        # We can either run on any peers of the associated org
        peer lifecycle chaincode commit \
            -o orderer.personal-network.com:7050 \
            --tls true \
            --cafile $ORDERER_CA  \
            --channelID channeldemo \
            --name becc \
            --peerAddresses peer0.org1.personal-network.com:7051 \
            --tlsRootCertFiles $PEER_BE1_TLSROOTCERTFILES \
            --peerAddresses peer0.org2.personal-network.com:7051 \
            --tlsRootCertFiles $PEER_BE2_TLSROOTCERTFILES \
            --version 1 \
            --sequence 1 \
            --init-required \
            --signature-policy "OR('\''Org1MSP.peer'\'', '\''Org2MSP.peer'\'')"


        echo "3.9. Checking the query commited chaincode..."
        peer lifecycle chaincode querycommitted \
            --channelID channeldemo \
            --name becc

        # init 
        # queryAllProducts here ! 
    '
    }


function deployChaincode(){
    docker exec -it cli bash -c '
        setOrgEnv(){
            local org=$1
            local peer=$2
            local port=$3
            # Convert the first letter to uppercase and the rest to lowercase
            local org_uppercase="$(tr '[:lower:]' '[:upper:]' <<< ${org:0:1})${org:1}"

            echo "1. Setting the env variables for <<$org_uppercase>>..."
            export CORE_PEER_LOCALMSPID=${org_uppercase}MSP
            export CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/peers/${peer}.${org}.personal-network.com/tls/ca.crt"
            export CORE_PEER_MSPCONFIGPATH="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/users/Admin@${org}.personal-network.com/msp"
            export CORE_PEER_ADDRESS="${peer}.${org}.personal-network.com:${port}"
            
            echo "2. Exporting the orderer CA..."
            export ORDERER_CA="/opt/gopath/fabric-samples/personal-network/crypto-config/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem"


        }
        setOrgEnv "org1" "peer0" "7051"
        echo "3. Deploy the chaincode..."
        echo "3.1. Packaging the chaincode..."
        peer lifecycle chaincode package becc.tar.gz \
        --path /opt/gopath/src/chain/be_chaincode/go/  \
        --lang golang --label becc_1
       
        echo "3.2. Installing the chaincode on <<Org1>>..."
        peer lifecycle chaincode install becc.tar.gz
        
        setOrgEnv "org2" "peer0" "7051"
        echo "3.2. Installing the chaincode on <<Org2>>...."
        peer lifecycle chaincode install becc.tar.gz
        
        echo "3.3. Querying the installed chaincode..."
        output=$(peer lifecycle chaincode queryinstalled)
        package_id=$(echo "$output" | grep -oP "Package ID: \K[^,]+")
        CC_PACKAGE_ID=$package_id
        echo "CC_PACKAGE_ID=$CC_PACKAGE_ID"
        export CC_PACKAGE_ID=$CC_PACKAGE_ID

        setOrgEnv "org1" "peer0" "7051"
        echo "3.4. Approving the chaincode <<Org1>>..."
        peer lifecycle chaincode approveformyorg \
        -o orderer.personal-network.com:7050 \
        --tls --cafile $ORDERER_CA \
        --channelID channeldemo --name becc --version 1 --init-required --package-id $CC_PACKAGE_ID \
        --sequence 1 --signature-policy "OR('Org1MSP.peer', 'Org2MSP.peer')"



        echo "3.5. Checking the commit readiness..."
        peer lifecycle chaincode checkcommitreadiness --channelID channeldemo --name becc --version 1 --sequence 1 --output json --init-required --signature-policy "OR('Org1MSP.peer', 'Org2MSP.peer')"

        echo "3.6. Approving the chaincode <<Org2>>..."
        setOrgEnv "org2" "peer0" "7051"
        peer lifecycle chaincode approveformyorg \
        -o orderer.personal-network.com:7050 \
        --tls --cafile $ORDERER_CA \
        --channelID channeldemo --name becc --version 1 --init-required --package-id $CC_PACKAGE_ID \
        --sequence 1 --signature-policy "OR('Org1MSP.peer', 'Org2MSP.peer')"
       
        echo "3.7. Checking the commit readiness..."
        peer lifecycle chaincode checkcommitreadiness --channelID channeldemo --name becc --version 1 --sequence 1 --output json --init-required --signature-policy "OR('Org1MSP.peer', 'Org2MSP.peer')"


    '
}

function main(){
    init
    generateCryptoConfig
    generateChannelArtifacts
    # with this you can have your network which you could run the docker compose file of cli to start the network 

    createChannel
}
main