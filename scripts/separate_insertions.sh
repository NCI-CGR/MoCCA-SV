#!/bin/bash

inFile=$1
outFile1=$2
outFile2=$3


i=0
j=0

# separate out SVs spanning <=10bp
awk -v out1="$outFile1" -v out2="$outFile2" -v i="$i" -v j="$j" '{FS=OFS="\t"} {if($3-$2<=10) {print $0 > out1; i++} else {print $0 > out2; j++}}' $inFile

# handle case of no SVs <=10bp
if [ $i -eq 0 ]; then
    touch $outFile1
fi

# handle case of no SVs >10 bp
if [ $j -eq 0 ]; then
    touch $outFile2
fi