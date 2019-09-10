#!/bin/bash

inBam=$1
sampleType=$2
outFile=$3

numSamples=$(samtools view -H $inBam | grep -Eo "\bSM:\S+\b" | uniq | wc -l)

if [ "$numSamples" -lt "1" ]; then
	echo "ERROR: no SM tag detected in $inBam."
	exit 1
elif [ "$numSamples" -gt "1" ]; then
	echo "ERROR: more than one SM tag detected in $inBam."
	exit 1
else
	sampleName=$(samtools view -H $inBam | grep -Eo "\bSM:\S+\b" | uniq)
	echo "$sampleName"$'\t'"$sampleType" | sed 's/SM://' >> $outFile
fi