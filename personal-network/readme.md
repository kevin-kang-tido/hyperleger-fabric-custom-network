## Note 

```bash
just network create
just network destroy 
```

## Understaning the flow 
With the version 2.2.x 
* Orderer still uses a bootstrap file ( genesis block ) to initialize the system channel 
* This file is usually specified in the `orderer.yaml` under a parameter called `Genereal.BootstrapFile ` or `General.BootstrapMethod`
## After you have deployed the chaincode to the network 

```bash 
export ORDERER_CA=/opt/gopath/fabric-samples/personal-network/crypto-config/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem
export PEER_ORG1_TLSROOTCERTFILES=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org1.personal-network.com/peers/peer0.org1.personal-network.com/tls/ca.crt
export PEER_ORG2_TLSROOTCERTFILES=/opt/gopath/fabric-samples/personal-network/crypto-config/peerOrganizations/org2.personal-network.com/peers/peer0.org2.personal-network.com/tls/ca.crt
 
peer chaincode invoke -o orderer.personal-network.com:7050 \
    --tls true --cafile $ORDERER_CA -C channeldemo \
    -n becc --peerAddresses peer0.org1.personal-network.com:7051 \
    --tlsRootCertFiles $PEER_ORG1_TLSROOTCERTFILES --peerAddresses peer0.org2.personal-network.com:7051 \
    --tlsRootCertFiles $PEER_ORG2_TLSROOTCERTFILES \
    --isInit -c '{"function":"initLedger","Args":[]}'

peer chaincode query -C channeldemo -n becc -c '{"Args":["queryAllProducts"]}'
```

## Errors 

> **Note**: because i have used different version of iamge between the orderer and the peer , which are the main reason in which it shows this errors 
* Inspect the certificates 
```bash
openssl x509 -in signcerts/Admin\@org1.personal-network.com-cert.pem \
    -text -noout
echo $CORE_PEER_MSPCONFIGPATH
echo $CORE_PEER_ADDRESS
echo $CORE_PEER_LOCALMSPID
echo $CORE_PEER_TLS_ROOTCERT_FILE
```
`Error: proposal failed (err: rpc error: code = Unknown desc = error validating proposal: access denied: channel [] creator org unknown, creator is malformed)`
* Understanding the error 
  * proposal failed: attemps to submit the propposal failed 
  * rpc error: code = Unknown desc = error validating proposal: the rpc call failed : Remote Procedure Call . This suggests there were error in the communication between the different part of the system 
  * access denied: seems like you are not allow to perform the actions 
  * channel [] creator org unknown, creator is malformed: the channel is unknown and the creator is malformed: The system doesn't recognize the organization that created the channel you're trying to join 
    * This could be : 
      * The channel name might be missing ( indicate by empty brace)


* Approve for the chaincode 
```bash

export ORDERER_CA=/opt/gopath/fabric-samples/personal-network/crypto-config/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem
export CC_PACKAGE_ID=becc_1:4a94196ea5fc84342e77bd755a1e45d97134801a859a49431e20b89bd7074fbc
 peer lifecycle chaincode approveformyorg -o orderer.personal-network.com:7050 --tls --cafile $ORDERER_CA --channelID channeldemo --name becc --version 1 --init-required --package-id $CC_PACKAGE_ID  --sequence 1 --signature-policy "OR('Org1MSP.peer', 'Org2MSP.peer')"


/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/personal-network.com/orderers/orderer.personal-network.com/msp/tlscacerts/tlsca.personal-network.com-cert.pem
```
`Error: timed out waiting for txid on all peers`
These are the possible errors for this : 
* Peers are not responding or are unreachable
* Issue with the network connectivity betweeen peers and orderer 