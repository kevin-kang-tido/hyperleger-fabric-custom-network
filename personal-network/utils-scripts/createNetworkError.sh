#!/bin/bash

# Constants
FABRIC_BIN_PATH="/home/zoe/Documents/first_blockchain_network/fabric-sample/bin"
CRYPTO_CONFIG_PATH="crypto-config.yaml"
CHANNEL_NAME="channeldemo"
GENESIS_BLOCK="channel-artifacts/genesis.block"
CHANNEL_TX="channel-artifacts/channel.tx"
ORG1_ANCHOR_TX="channel-artifacts/Org1Anchor.tx"
ORG2_ANCHOR_TX="channel-artifacts/Org2Anchor.tx"
DOCKER_COMPOSE_FILE="docker-compose-cli.yaml"

# Initialization
function init() {
    echo "Adding the bin of hyperledger fabric to the PATH..."
    export PATH=$PATH:$FABRIC_BIN_PATH
}

# Generate crypto artifacts
function generateCryptoConfig() {
    echo "Generating crypto-config artifacts..."
    cryptogen generate --config=$CRYPTO_CONFIG_PATH --output=crypto-config
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate crypto-config artifacts."
        exit 1
    fi
}

# Generate channel artifacts
function generateChannelArtifacts() {
    echo "Generating channel-artifacts..."
    echo "1. Creating the genesis block..."
    configtxgen -profile OrdererGenesis -outputBlock $GENESIS_BLOCK -channelID channelorderergenesis
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create the genesis block."
        exit 1
    fi

    echo "2. Generating channel configuration transaction..."
    configtxgen -profile ChannelDemo -outputCreateChannelTx $CHANNEL_TX -channelID $CHANNEL_NAME
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate channel configuration transaction."
        exit 1
    fi

    echo "3. Generating anchor peer transaction (Org1)..."
    configtxgen -profile ChannelDemo -outputAnchorPeersUpdate $ORG1_ANCHOR_TX -channelID $CHANNEL_NAME -asOrg Org1MSP
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate anchor peer transaction for Org1."
        exit 1
    fi

    echo "4. Generating anchor peer transaction (Org2)..."
    configtxgen -profile ChannelDemo -outputAnchorPeersUpdate $ORG2_ANCHOR_TX -channelID $CHANNEL_NAME -asOrg Org2MSP
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate anchor peer transaction for Org2."
        exit 1
    fi
}

# Start the network
function upNetwork() {
    echo "Starting the network..."
    echo COMPOSE_PROJECT_NAME=net > .env
    echo CURRENT_DIR=$PWD >> .env
    docker-compose -f $DOCKER_COMPOSE_FILE up -d
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start the network."
        exit 1
    fi
}

# Set organization environment variables
function setOrgEnv() {
    local org=$1
    local peer=$2
    local port=$3

    echo "Setting the environment variables for $org..."
    export CORE_PEER_LOCALMSPID="${org}MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/peers/${peer}.${org}.personal-network.com/tls/ca.crt"
    export CORE_PEER_MSPCONFIGPATH="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/users/Admin@${org}.personal-network.com/msp"
    export CORE_PEER_ADDRESS="${peer}.${org}.personal-network.com:${port}"
    export ORDERER_CA="/opt/gopath/fabric-samples/personal-network/crypto-config/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem"
}

# Create channel
function createChannel() {
    upNetwork

    echo "Creating channel on Org1 via the CLI container..."
    docker exec -it cli bash -c "
        export CORE_PEER_LOCALMSPID='Org1MSP'
        export CORE_PEER_TLS_ROOTCERT_FILE='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/peers/peer0.org1.personal-network.com/tls/ca.crt'
        export CORE_PEER_MSPCONFIGPATH='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/users/Admin@org1.personal-network.com/msp'
        export CORE_PEER_ADDRESS='peer0.org1.personal-network.com:7051'
        export ORDERER_CA='/opt/gopath/fabric-samples/personal-network/crypto-config/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem'

        echo 'Creating the channel...'
        peer channel create -o orderer.personal-network.com:7050 -c $CHANNEL_NAME -f /opt/gopath/fabric-samples/personal-network/channel-artifacts/channel.tx --tls --cafile \$ORDERER_CA
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to create the channel.'
            exit 1
        fi

        echo 'Joining the channel...'
        peer channel join -b ${CHANNEL_NAME}.block --tls --cafile \$ORDERER_CA
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to join the channel.'
            exit 1
        fi

        echo 'Updating the anchor peer on Org1...'
        peer channel update -o orderer.personal-network.com:7050 -c $CHANNEL_NAME -f /opt/gopath/fabric-samples/personal-network/channel-artifacts/Org1Anchor.tx --tls --cafile \$ORDERER_CA
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to update the anchor peer for Org1.'
            exit 1
        fi

        export CORE_PEER_LOCALMSPID='Org2MSP'
        export CORE_PEER_TLS_ROOTCERT_FILE='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/peers/peer0.org2.personal-network.com/tls/ca.crt'
        export CORE_PEER_MSPCONFIGPATH='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/users/Admin@org2.personal-network.com/msp'
        export CORE_PEER_ADDRESS='peer0.org2.personal-network.com:7051'
        
        echo 'Joining the channel on Org2...'
        peer channel join -b ${CHANNEL_NAME}.block --tls --cafile \$ORDERER_CA
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to join the channel on Org2.'
            exit 1
        fi

        echo 'Updating the anchor peer on Org2...'
        peer channel update -o orderer.personal-network.com:7050 -c $CHANNEL_NAME -f /opt/gopath/fabric-samples/personal-network/channel-artifacts/Org2Anchor.tx --tls --cafile \$ORDERER_CA
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to update the anchor peer for Org2.'
            exit 1
        fi
    "
}

# Deploy chaincode
function deployChaincode() {
    echo "Deploying chaincode..."
    docker exec -it cli bash -c "
        echo 'Packaging the chaincode...'
        peer lifecycle chaincode package becc.tar.gz --path /opt/gopath/src/chain/be_chaincode/go/ --lang golang --label becc_1
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to package the chaincode.'
            exit 1
        fi

        echo 'Installing the chaincode on Org1...'
        peer lifecycle chaincode install becc.tar.gz
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to install the chaincode on Org1.'
            exit 1
        fi
        
        export CORE_PEER_LOCALMSPID='Org2MSP'
        export CORE_PEER_TLS_ROOTCERT_FILE='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/peers/peer0.org2.personal-network.com/tls/ca.crt'
        export CORE_PEER_MSPCONFIGPATH='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/users/Admin@org2.personal-network.com/msp'
        export CORE_PEER_ADDRESS='peer0.org2.personal-network.com:7051'

        echo 'Installing the chaincode on Org2...'
        peer lifecycle chaincode install becc.tar.gz
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to install the chaincode on Org2.'
            exit 1
        fi
        
        echo 'Querying the installed chaincode...'
        output=\$(peer lifecycle chaincode queryinstalled)
        package_id=\$(echo \"\$output\" | grep -oP 'Package ID: \K[^,]+')
        export CC_PACKAGE_ID=\$package_id

        echo 'Approving the chaincode on Org1...'
        export CORE_PEER_LOCALMSPID='Org1MSP'
        export CORE_PEER_TLS_ROOTCERT_FILE='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/peers/peer0.org1.personal-network.com/tls/ca.crt'
        export CORE_PEER_MSPCONFIGPATH='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/users/Admin@org1.personal-network.com/msp'
        export CORE_PEER_ADDRESS='peer0.org1.personal-network.com:7051'
        
        peer lifecycle chaincode approveformyorg -o orderer.personal-network.com:7050 --tls --cafile \$ORDERER_CA --channelID $CHANNEL_NAME --name becc --version 1 --init-required --package-id \$CC_PACKAGE_ID --sequence 1 --signature-policy \"OR('Org1MSP.peer', 'Org2MSP.peer')\"
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to approve the chaincode on Org1.'
            exit 1
        fi

        echo 'Approving the chaincode on Org2...'
        export CORE_PEER_LOCALMSPID='Org2MSP'
        export CORE_PEER_TLS_ROOTCERT_FILE='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/peers/peer0.org2.personal-network.com/tls/ca.crt'
        export CORE_PEER_MSPCONFIGPATH='/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/users/Admin@org2.personal-network.com/msp'
        export CORE_PEER_ADDRESS='peer0.org2.personal-network.com:7051'

        peer lifecycle chaincode approveformyorg -o orderer.personal-network.com:7050 --tls --cafile \$ORDERER_CA --channelID $CHANNEL_NAME --name becc --version 1 --init-required --package-id \$CC_PACKAGE_ID --sequence 1 --signature-policy \"OR('Org1MSP.peer', 'Org2MSP.peer')\"
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to approve the chaincode on Org2.'
            exit 1
        fi

        echo 'Committing the chaincode...'
        peer lifecycle chaincode commit -o orderer.personal-network.com:7050 --tls true --cafile \$ORDERER_CA --channelID $CHANNEL_NAME --name becc --peerAddresses peer0.org1.personal-network.com:7051 --tlsRootCertFiles /opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/peers/peer0.org1.personal-network.com/tls/ca.crt --peerAddresses peer0.org2.personal-network.com:7051 --tlsRootCertFiles /opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/peers/peer0.org2.personal-network.com/tls/ca.crt --version 1 --sequence 1 --init-required --signature-policy \"OR('Org1MSP.peer', 'Org2MSP.peer')\"
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to commit the chaincode.'
            exit 1
        fi

        echo 'Querying the committed chaincode...'
        peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name becc
        if [ $? -ne 0 ]; then
            echo 'Error: Failed to query the committed chaincode.'
            exit 1
        fi
    "
}

# Main function
function main() {
    init
    generateCryptoConfig
    generateChannelArtifacts
    createChannel
    deployChaincode
}

main
