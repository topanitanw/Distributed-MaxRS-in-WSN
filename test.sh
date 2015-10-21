#!/bin/bash -x
x="Mango"
y="Pickle"
x="$x $y"
echo "$x"
x="Master"
# print 'Master' without a whitespace i.e. print Mastercard as a one word #
echo "${x}card"
if [ -f test.sh ]; then
    echo "test.sh"
else 
    echo "not test.sh"
fi
if [ -e /dev/ttyUSB0 ]; then
    echo "0"
else 
    echo "not 0"
fi

