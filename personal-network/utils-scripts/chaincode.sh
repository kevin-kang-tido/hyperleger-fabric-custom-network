function initChaincode(){
    docker exec -it cli bash -c '
        setOrgEnv(){
            local org=$1
            local peer=$2
            local port=$3
            # Convert the first letter to uppercase and the rest to lowercase
            local org_uppercase="$(tr '[:lower:]' '[:upper:]' <<< ${org:0:1})${org:1}"

            echo "1. Setting the env variables for <<$org_uppercase>>..."
            export CORE_PEER_LOCALMSPID="${org_uppercase}MSP"
            export CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/peers/${peer}.${org}.personal-network.com/tls/ca.crt"
            export CORE_PEER_MSPCONFIGPATH="/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/${org}.personal-network.com/users/Admin@${org}.personal-network.com/msp"
            export CORE_PEER_ADDRESS="${peer}.${org}.personal-network.com:${port}"
            
            echo "2. Exporting the orderer CA..."
            export ORDERER_CA="/opt/gopath/fabric-samples/personal-network/crypto-config/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem"
        }
        export FABRIC_LOGGING_SPEC=INFO 
        setOrgEnv "org2" "peer0" "7051"
        export PEER_BE1_TLSROOTCERTFILES=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/peers/peer0.org1.personal-network.com/tls/ca.crt
        export PEER_BE2_TLSROOTCERTFILES=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/peers/peer0.org2.personal-network.com/tls/ca.crt

        echo "Querying the chaincode..."
        peer lifecycle chaincode querycommitted \
        --channelID channeldemo \
        --name becc

        echo "1. Invoking the chaincode... 🚀"
        peer chaincode invoke \
        -o orderer.personal-network.com:7050 \
        --tls true \
        --cafile $ORDERER_CA \
        --channelID channeldemo \
        -n becc \
        --peerAddresses peer0.org1.personal-network.com:7051 \
        --tlsRootCertFiles $PEER_BE1_TLSROOTCERTFILES \
        --peerAddresses peer0.org2.personal-network.com:7051 \
        --tlsRootCertFiles $PEER_BE2_TLSROOTCERTFILES \
        --isInit -c '\''{"function":"initLedger","Args":[]}'\''
    

        echo "2. Querying the chaincode... 🚀"
        peer chaincode query \
        --channelID channeldemo \
        -n becc \
        -c '\''{"Args":["queryAllProducts"]}'\'' | jq
        


        echo "3. Invoking the chaincode ( ChangeProductPrice )... 🚀"
        peer chaincode invoke \
        -o orderer.personal-network.com:7050 \
        --tls true \
        --cafile $ORDERER_CA \
        -C channeldemo \
        -n becc \
        --peerAddresses peer0.org1.personal-network.com:7051 \
        --tlsRootCertFiles $PEER_BE1_TLSROOTCERTFILES \
        --peerAddresses peer0.org2.personal-network.com:7051 \
        --tlsRootCertFiles $PEER_BE2_TLSROOTCERTFILES \
        -c '\''{"function":"ChangeProductPrice","Args":["PRODUCT0", "555"]}'\''


        echo "2. Querying the chaincode (to see the changes)... 🚀"
        peer chaincode query \
        --channelID channeldemo \
        -n becc \
        -c '\''{"Args":["queryAllProducts"]}'\'' | jq
    '
    }
initChaincode