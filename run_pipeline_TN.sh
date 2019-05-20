#!/bin/sh

module load python3/3.7.0 sge perl singularity/3.0.1
unset module
cmd="qsub -q long.q -V -j y -S /bin/sh -o ${PWD} ${PWD}/SV_wrapper.sh ${PWD}/config_TN.yaml"
echo "Command run: $cmd"
eval $cmd
