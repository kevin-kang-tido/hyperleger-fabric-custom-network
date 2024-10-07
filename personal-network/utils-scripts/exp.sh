#!/bin/bash

output="Installed chaincodes on peer:
Package ID: myccv1:a7ca45a7cc85f1d89c905b775920361ed089a364e12a9b6d55ba75c965ddd6a9, Label: myccv"

extract_package_id(){
    local output="$1"
    package_id=$(echo "$output" | grep -oP 'Package ID: \K[^,]+')
    echo "$package_id"
}
 
echo "Output is : $output"
echo "-------------------------------------------"
CC_PACKAGE_ID=$(extract_package_id "$output")
echo "CC_PACKAGE_ID is : $CC_PACKAGE_ID"