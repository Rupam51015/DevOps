#!/bin/bash

function create_user() {
	read -p "Enter Username: " username
	sudo useradd -m $username
}

function verify_user() {
	if  sudo cat /etc/passwd | grep -iq "$username" ; then
		echo "User verified"
	else
		echo "User not verified"
	fi
	
}	

function show_disk() {
	echo "Available Storage:"
	df -h | awk 'NR == 2 { print $2 }'
}
