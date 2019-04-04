#!/bin/bash

inFile=$1
outFile1=$2
outFile2=$3


i=0

# separate out SVs spanning <=10bp
awk -v out1="$outFile1" -v out2="$outFile2" -v counter="$i" '{FS=OFS="\t"} {if($3-$2<=10) {print $0 > out1; counter++} else {print $0 > out2}}' $inFile

# handle case of no SVs <=10bp
if [ $i -eq 0 ]; then
    touch $outFile1
fi
