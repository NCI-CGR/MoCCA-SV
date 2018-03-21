#!/bin/bash

input=$1
sample=$2
outDir=$3
varType="CTX"

awk '{FS=OFS="\t"}{print $0, NR}' $input | grep -v "^#" | grep -E "\s$varType\s" | awk '{FS=OFS="\t"} {print $1, $2 - 1, $2, $NF}' > $outDir$sample"_end1.bed"
awk '{FS=OFS="\t"}{print $0, NR}' $input | grep -v "^#" | grep -E "\s$varType\s" | awk '{FS=OFS="\t"} {print $4, $5 - 1, $5, $NF}' > $outDir$sample"_end2.bed"
awk '{FS=OFS="\t"}{print $0, NR}' $input | grep -v "^#" | grep -vE "\s$varType\s" | awk '{FS=OFS="\t"} {print $1, $2, $5, $NF}' | awk '{FS=OFS="\t"} ($2<$3){print $0} ($2>$3){print $1,$3,$2,$4} ($2==$3){print $1,$2,$3+1,$4}' >> $outDir$sample"_intra.bed"