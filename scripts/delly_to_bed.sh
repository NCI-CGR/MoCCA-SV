#!/bin/sh

input=$1
sample=$2
outDir=$3
varType="BND"

if [[ $input = *.gz ]]; then
    zcat $input | awk '{FS=OFS="\t"}{print $0, NR}' | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} ($0 !~ /^#/ && $2!=0){print $1, $2 - 1, $2, $NF} ($0 !~ /^#/ && $2==0){print $1, $2, $2+1, $NF}' > $outDir$sample"_end1.bed"
    zcat $input | awk '{FS=OFS="\t"}{print $0, NR}' | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} ($0 !~ /^#/){print gensub(/.*;CHR2=([chrGLhs37d]*[0-9MTXY.]+);.*/, "\\1", "g"), gensub(/.*;END=([0-9]+);.*/, "\\1", "g") - 1, gensub(/.*;END=([0-9]+);.*/, "\\1", "g"), $NF}' > $outDir$sample"_end2.bed"
    zcat $input | awk '{FS=OFS="\t"}{print $0, NR}' | grep -v "SVTYPE=$varType" | awk '{FS=OFS="\t"} ($0 !~ /^#/){print $1, $2, gensub(/.*;END=([0-9]+);.*/, "\\1", "g"), $NF}' | awk '{FS=OFS="\t"} ($2<$3){print $0} ($2>$3){print $1,$3,$2,$4} ($2==$3){print $1,$2,$3+1,$4}' >> $outDir$sample"_intra.bed"
else
    awk '{FS=OFS="\t"}{print $0, NR}' $input | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} ($0 !~ /^#/ && $2!=0){print $1, $2 - 1, $2, $NF} ($0 !~ /^#/ && $2==0){print $1, $2, $2+1, $NF}' > $outDir$sample"_end1.bed"
    awk '{FS=OFS="\t"}{print $0, NR}' $input | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} ($0 !~ /^#/){print gensub(/.*;CHR2=([chrGLhs37d]*[0-9MTXY.]+);.*/, "\\1", "g"), gensub(/.*;END=([0-9]+);.*/, "\\1", "g") - 1, gensub(/.*;END=([0-9]+);.*/, "\\1", "g"), $NF}' > $outDir$sample"_end2.bed"
    awk '{FS=OFS="\t"}{print $0, NR}' $input | grep -v "SVTYPE=$varType" | awk '{FS=OFS="\t"} ($0 !~ /^#/){print $1, $2, gensub(/.*;END=([0-9]+);.*/, "\\1", "g"), $NF}' | awk '{FS=OFS="\t"} ($2<$3){print $0} ($2>$3){print $1,$3,$2,$4} ($2==$3){print $1,$2,$3+1,$4}' >> $outDir$sample"_intra.bed"
fi
