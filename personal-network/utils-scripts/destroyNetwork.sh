#!/bin/bash

echo "..........Destroying network........."
echo "Removing containers and its volumes ........"
docker compose down -v 


echo "Removing old channel-artifacts artifacts...."
rm -rf channel-artifacts/*
echo "Removing old crypto-config artifacts...."
rm -rf crypto-config/*