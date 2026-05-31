#!/bin/bash

# an argument is the keyword written after filename

<<comment

This is a multiline comment

Usage of arguments ./argument.sh Rupam Anamika

comment

echo "0th argument is: $0"
echo "First argument is: $1"

echo "Second argument is: $2"

echo "Thirt argument is: $3"

echo "count : $#"
