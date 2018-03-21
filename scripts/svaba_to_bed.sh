#!/bin/sh

input=$1
sample=$2
outDir=$3
varType="SPAN=-1"

awk '{FS=OFS="\t"}{print $0, NR}' $input | grep -v "^#" | grep -v $varType | awk '{FS=OFS="\t"} {print $1, $2, gensub(/.*[[:blank:]][atcgnNATCG]*[\[\]]chr[0-9MXY]+:([0-9]+)[\[\]].*/, "\\1", "g"), $NF}' | awk '{FS=OFS="\t"} ($2<$3){print $0} ($2>$3){print $1,$3,$2,$4} ($2==$3){print $1,$2,$3+1,$4}' > $outDir$sample"_intra.bed"
awk '{FS=OFS="\t"}{print $0, NR}' $input | grep -v "^#" | grep  $varType | awk '{FS=OFS="\t"} {print $1, $2 - 1, $2, $NF}' > $outDir$sample"_end1.bed"
awk '{FS=OFS="\t"}{print $0, NR}' $input | grep -v "^#" | grep  $varType | awk '{FS=OFS="\t"} {print gensub(/.*[[:blank:]][atcgnNATCG]*[\[\]](chr[0-9MXY]+):[0-9]+[\[\]].*/, "\\1", "g"), gensub(/.*[[:blank:]][atcgnNATCG]*[\[\]]chr[0-9MXY]+:([0-9]+)[\[\]].*/, "\\1", "g") - 1, gensub(/.*[[:blank:]][atcgnNATCG]*[\[\]]chr[0-9MXY]+:([0-9]+)[\[\]].*/, "\\1", "g"), $NF}' > $outDir$sample"_end2.bed"
