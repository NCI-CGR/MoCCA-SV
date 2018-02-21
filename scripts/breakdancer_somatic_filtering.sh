#!/bin/bash

# filterg out false positives
# column 9 = quality score; column 10 = number of supporting reads
inFile=$1
qual_threshold=$2
num_reads=$3

awk -v q1=$qual_threshold -v n1=$num_reads '{FS=OFS="\t"} $1 ~ /^#/{print $0; next} $1 !~ /^#/ && $9 >= q1 && $10 >= n1{print $0}' $inFile
