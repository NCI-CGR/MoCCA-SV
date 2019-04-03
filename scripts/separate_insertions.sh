#!/bin/bash

inFile=$1
outFile1=$2
outFile2=$3


# separate out SVs spanning <=10bp
awk -v out1=$outFile1 -v out2=$outFile2 '{FS=OFS="\t"} ($3-$2<=10){print $0 > "out1"} else {print $0 > "out2"}' $inFile
