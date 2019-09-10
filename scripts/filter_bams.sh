#!/bin/sh

inFile=$1
outFile=$2

# samtools view -h $inFile | awk '{FS=OFS="\t"} ($7 ~ /\*/ && $2 ~ /65|81|97|113|129|145|161|177/) || $7 !~ /\*/ || $0 ~ /^@/ {print $0}' | samtools view -b > $outFile
    # for whatever reason, reads with the above flags still choke in manta
samtools view -h $inFile | awk '{FS=OFS="\t"} $7 !~ /\*/ || $0 ~ /^@/{print $0}' | samtools view -b > $outFile
