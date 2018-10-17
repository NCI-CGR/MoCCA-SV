#!/bin/sh

input=$1
sample=$2
outDir=$3
varType="BND"  # how to differentiate interchromosomal translocations (with four breakends) from insertions/deletions/duplications (two breakends)

<insert command line to transform data to bed here> > $outDir$sample"_intra.bed"
<insert command line to transform data to bed here> > $outDir$sample"_end1.bed"
<insert command line to transform data to bed here> > $outDir$sample"_end2.bed"
