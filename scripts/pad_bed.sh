#!/bin/bash

pad=$1
inFile=$2
genome=$3
outFile=$4

bedtools slop -b $pad -i <(sort -k1,1 -k2,2n $inFile) -g $genome > $outFile