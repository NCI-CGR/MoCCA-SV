#!/bin/sh

input=$1
sample=$2
outDir=$3
varType="BND"

# source /etc/profile.d/modules.sh
# module load bcftools
# bcftools view "${inPath}delly_TN/somatic/${sample}_INV.bcf" > $outDir$sample"_all.txt"
# bcftools view "${inPath}delly_TN/somatic/${sample}_INS.bcf" >> $outDir$sample"_all.txt"
# bcftools view "${inPath}delly_TN/somatic/${sample}_DEL.bcf" >> $outDir$sample"_all.txt"
# bcftools view "${inPath}delly_TN/somatic/${sample}_DUP.bcf" >> $outDir$sample"_all.txt"
# bcftools view "${inPath}delly_TN/somatic/${sample}_BND.bcf" >> $outDir$sample"_all.txt"

awk '{FS=OFS="\t"}{print $0, NR}' $input | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} ($0 !~ /^#/){print $1, $2 - 1, $2, $NF}' > $outDir$sample"_end1.bed"
awk '{FS=OFS="\t"}{print $0, NR}' $input | grep "SVTYPE=$varType" | awk '{FS=OFS="\t"} ($0 !~ /^#/){print gensub(/.*;CHR2=([chrGLhs37d]*[0-9MTXY.]+);.*/, "\\1", "g"), gensub(/.*;END=([0-9]+);.*/, "\\1", "g") - 1, gensub(/.*;END=([0-9]+);.*/, "\\1", "g"), $NF}' > $outDir$sample"_end2.bed"
awk '{FS=OFS="\t"}{print $0, NR}' $input | grep -v "SVTYPE=$varType" | awk '{FS=OFS="\t"} ($0 !~ /^#/){print $1, $2, gensub(/.*;END=([0-9]+);.*/, "\\1", "g"), $NF}' | awk '{FS=OFS="\t"} ($2<$3){print $0} ($2>$3){print $1,$3,$2,$4} ($2==$3){print $1,$2,$3+1,$4}' >> $outDir$sample"_intra.bed"


# source /etc/profile.d/modules.sh
# module load bcftools
# if [[ $inFile == *BND* ]]; then
# 	name=${outFile%.bed}
# 	bcftools view $inFile | awk '{FS="\t"} ($0 !~ /^#/){print $1, $2 - 1, $2}' > $name"_end1.bed"
# 	bcftools view $inFile | awk '{FS="\t"} ($0 !~ /^#/){print gensub(/.*;CHR2=(chr[0-9]+);.*/, "\\1", "g"), gensub(/.*;END=([0-9]+);.*/, "\\1", "g") - 1, gensub(/.*;END=([0-9]+);.*/, "\\1", "g")}' > $name"_end2.bed"
# else
# 	bcftools view $inFile | awk '{FS="\t"} ($0 !~ /^#/){print $1, $2, gensub(/.*;END=([0-9]+);.*/, "\\1", "g")}' >> $outFile
# fi