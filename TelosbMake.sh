#!/bin/bash
# Data: 10/15/2015
# Author: Panitan Wongse-ammat
# This script takes two arguments which are the port number and 
# the node id of the sensor respectively.
echo "+++ Script name: $0"
if [ "$#" -ne 2 ]; then
    # check the number of arguments must be 2
    echo "+++ Illegal number of parameters !!!"
    echo "+++ This script needs two arguments:"
    echo "+++ 1. a port number and 2. a node id"
else 
    echo "+++ The port number: /dev/ttyUSB${1} | Node Id: $2"
    if [ -e /dev/ttyUSB${1} ]; then
	# check wheter the /dev/ttyUSB${1} exists or not
	sudo chmod 777 "/dev/ttyUSB${1}"
	make telosb install.$2 bsl,/dev/ttyUSB${1}
	java net.tinyos.tools.PrintfClient -comm serial@/dev/ttyUSB${1}:115200
    else 
	echo "+++ Error the /dev/ttyUSB${1} does not exist !!!"
    fi
fi
