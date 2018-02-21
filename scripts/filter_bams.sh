#!/bin/sh

inFile=$1
outFile=$2

samtools view -h $inFile | awk '{FS=OFS="\t"} $7 !~ /\*/ || $0 ~ /^@/{print $0}' | samtools view -b > $outFile
