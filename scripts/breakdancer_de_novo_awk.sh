#!/bin/bash
p1_bam=$1
p2_bam=$2
sv_file=$3
awk '{FS=OFS="\t"} $1 ~ /^#/ || ($0 !~ /$p1_bam/ && $0 !~ /$p2_bam/) {print $0}' $sv_file