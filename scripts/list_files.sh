#!/bin/bash

inFile=$1
sample=$2

echo $inFile | tr " " "\n" | sed "s/^/$sample /"