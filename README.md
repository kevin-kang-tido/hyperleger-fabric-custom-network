## Note 
Getting started with created own blockchain network which includes. 

1. Setup network from scratch 
2. Deploy the chaincode 
3. Interact with the chaincode 
4. Using the Hyperledger explorer in order to view the network 

## Getting Start 
-- start network 
# just network create



-- logs  to peero an org1

docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" \
-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/peers/peer0.org1.personal-network.com/tls/ca.crt" \
-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/users/Admin@org1.personal-network.com/msp" \ 



-- -- # share all ledger to all org1 and org2
export ORDERER_CA=/opt/gopath/fabric-samples/personal-network/crypto-config/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem
export PEER_ORG1_TLSROOTCERTFILES=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/peers/peer0.org1.personal-network.com/tls/ca.crt
export PEER_ORG2_TLSROOTCERTFILES=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/peers/peer0.org2.personal-network.com/tls/ca.crt

-- 
-- init data to ledger 
peer chaincode invoke -o orderer.personal-network.com:7050 \
    --tls true --cafile $ORDERER_CA -C channeldemo \
    -n becc --peerAddresses peer0.org1.personal-network.com:7051 \
    --tlsRootCertFiles $PEER_ORG1_TLSROOTCERTFILES --peerAddresses peer0.org2.personal-network.com:7051 \
    --tlsRootCertFiles $PEER_ORG2_TLSROOTCERTFILES \
    --isInit -c '{"function":"initLedger","Args":[]}'

-- query all prouct 
peer chaincode query -C channeldemo -n becc -c '{"Args":["queryAllProducts"]}'

 -- deploy hyperleger ui dashboard
# just explorer start 
        -->  hyperleger ui dashboard
		"username": "exploreradmin1212i",
		"password": "exploreradminpw888i"

-- destroy network 
# just network destroy
# just explorer destroy 
