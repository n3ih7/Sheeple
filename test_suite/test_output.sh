#!/bin/bash

for i in `ls *.sh`
do
    to_compared=`echo $i | sed 's/sh/pl/g'`
    ../sheeple_9_local_test.pl $i
    echo "Now at \"$i\""
    if diff z $to_compared > /dev/null 2>&1; then 
        echo "GOOD" 
    else 
        echo "DIFFERENT!"
    fi
done

rm z