#!/bin/sh

input=$1
sample=$2
outDir=$3
varType="BND"

zcat $input | awk '{FS=OFS="\t"}{print $0, NR}' | grep -v "^#" | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} {print $1, $2 - 1, $2, $NF}'  > $outDir$sample"_end1.bed"
zcat $input | awk '{FS=OFS="\t"}{print $0, NR}' | grep -v "^#" | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} {print gensub(/.*[[:blank:]][ACGTNnacgt\[\]]*(chr[0-9MXY]+):.*/, "\\1", "g"), gensub(/.*[[:blank:]][atcgnNATCG]*[\[\]]chr[0-9MXY]+:([0-9]+)[\[\]].*/, "\\1", "g") - 1, gensub(/.*[[:blank:]][atcgnNATCG]*[\[\]]chr[0-9MXY]+:([0-9]+)[\[\]].*/, "\\1", "g"), $NF}' > $outDir$sample"_end2.bed"
zcat $input | awk '{FS=OFS="\t"}{print $0, NR}' | grep -v "^#" | grep -v "SVTYPE=$varType" | awk '{FS=OFS="\t"} {print $1, $2, gensub(/.*[[:blank:]]END=([0-9]+);.*/, "\\1", "g"), $NF}' | awk '{FS=OFS="\t"} ($2<$3){print $0} ($2>$3){print $1,$3,$2,$4} ($2==$3){print $1,$2,$3+1,$4}' >> $outDir$sample"_intra.bed"
# zcat "${inDir}manta_TN/${sample}/results/variants/somaticSV.vcf.gz" | awk '{FS=OFS="\t"}{print $0, NR}' | grep -v "^#" | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} {print $1, $2 - 1, $2, $NF}'  > $outDir$sample"_end1.bed"
# zcat "${inDir}manta_TN/${sample}/results/variants/somaticSV.vcf.gz" | awk '{FS=OFS="\t"}{print $0, NR}' | grep -v "^#" | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} {print gensub(/.*[[:blank:]][ACGTNnacgt\[\]]*(chr[0-9MXY]+):.*/, "\\1", "g"), gensub(/.*[[:blank:]][atcgnNATCG]*[\[\]]chr[0-9MXY]+:([0-9]+)[\[\]].*/, "\\1", "g") - 1, gensub(/.*[[:blank:]][atcgnNATCG]*[\[\]]chr[0-9MXY]+:([0-9]+)[\[\]].*/, "\\1", "g"), $NF}' > $outDir$sample"_end2.bed"
# zcat "${inDir}manta_TN/${sample}/results/variants/somaticSV.vcf.gz" | awk '{FS=OFS="\t"}{print $0, NR}' | grep -v "^#" | grep -v "SVTYPE=$varType" | awk '{FS=OFS="\t"} {print $1, $2, gensub(/.*[[:blank:]]END=([0-9]+);.*/, "\\1", "g"), $NF}' | awk '{FS=OFS="\t"} ($2<$3){print $0} ($2>$3){print $1,$3,$2,$4} ($2==$3){print $1,$2,$3+1,$4}' >> $outDir$sample"_intra.bed"