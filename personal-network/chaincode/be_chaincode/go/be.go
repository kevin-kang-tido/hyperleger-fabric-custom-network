package main

import (
	"encoding/json"
	"fmt"
	"strconv"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides function for managing a car
type SmartContract struct {
	contractapi.Contract
}

// SimpleAsset implements as simple chaincode to manage an asset
type Product struct {
	Brand string `json:"brand"`
	Price int    `json:"price"`
	Count int    `json:"count"`
}

// QueryResult structure used for handling result of query
type QueryResult struct {
	Key    string `json:"Key"`
	Record *Product
}

/* Init called during chaincode instantiation to initialize any data.
Note that chaincode upgrade also calls this function to reset or migrate data */

func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	// set up any varialbes or asset here by calling the sub.PutState() method
	products := []Product{
		Product{Brand: "Apple", Price: 1000, Count: 10},
		Product{Brand: "Samsung", Price: 800, Count: 20},
		Product{Brand: "Huawei", Price: 600, Count: 30},
		Product{Brand: "Xiaomi", Price: 400, Count: 40},
		Product{Brand: "Oppo", Price: 300, Count: 50},
	}

	for i, product := range products {
		productAsBytes, _ := json.Marshal(product)
		err := ctx.GetStub().PutState("PRODUCT"+strconv.Itoa(i), productAsBytes)
		if err != nil {
			return fmt.Errorf("Failed to put to world state. %s", err.Error())
		}
	}
	return nil
}

func (s *SmartContract) QueryAllProducts(ctx contractapi.TransactionContextInterface) ([]QueryResult, error) {
	startkey := "PRODUCT0"
	endkey := "PRODUCT999"

	resultsIterator, err := ctx.GetStub().GetStateByRange(startkey, endkey)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close() // defer is used to close the iterator after the function has finished executing
	results := []QueryResult{}

	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		product := new(Product)                                             // create a new product object
		_ = json.Unmarshal(queryResponse.Value, product)                    // unmarshal the product object
		queryResult := QueryResult{Key: queryResponse.Key, Record: product} // create a new query result object
		results = append(results, queryResult)                              // append the query result object to the results array
	}
	return results, nil
}

// Create the product

func (s *SmartContract) CreateProduct(ctx contractapi.TransactionContextInterface, productNumber string, brand string, price int, count int) error {
	product := Product{
		Brand: brand,
		Price: price,
		Count: count,
	}

	productAsBytes, _ := json.Marshal(product)
	return ctx.GetStub().PutState(productNumber, productAsBytes)
}

// ChangeProductPrice updates the price of the product with the given details

func (s *SmartContract) ChangeProductPrice(ctx contractapi.TransactionContextInterface, productNumber string, newPrice int) error {
	productAsBytes, err := ctx.GetStub().GetState(productNumber)
	if err != nil {
		return fmt.Errorf("Failed to read the product: %s", err.Error())
	}

	product := new(Product)
	_ = json.Unmarshal(productAsBytes, product)
	product.Price = newPrice

	productAsBytes, _ = json.Marshal(product)
	return ctx.GetStub().PutState(productNumber, productAsBytes)
}

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		fmt.Printf("Error creating product chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting product chaincode: %s", err.Error())
	}
}
