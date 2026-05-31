#!/bin/bash

echo "Installing $1"

sudo apt-get install $1

echo "Successfully insalled $1"

sudo systemctl $1
