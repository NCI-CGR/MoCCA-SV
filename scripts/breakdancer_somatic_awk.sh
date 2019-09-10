#!/bin/bash
normal_bam=$1
sv_file=$2
awk -v var="${normal_bam##*/}" '{FS=OFS="\t"} ($1 ~ /^#/ || $11 !~ var){print $0}' $sv_file
