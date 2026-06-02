#!/bin/bash

read -p "Enter the filepath:" filepath

if [ -f $filepath ]; then
	echo "File exists"
else
	echo "File doesn't exist"
fi
