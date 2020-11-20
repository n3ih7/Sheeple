#!/bin/dash
for c_file in *.c
do
    gcc -c $c_file
done