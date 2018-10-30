#!/bin/sh

# to run: 
# module load python3 sge perl
# unset module
# qsub -q xlong.q -V -j y -S /bin/sh -o ${PWD} ${PWD}/SV_wrapper.sh ${PWD}/config.yaml

configFile=$1

if [ $# -eq 0 ]; then
    echo "Please specify config file with full path."
    exit 1
fi

if [ ! -f $configFile ]; then
    echo "Config file not found."
    exit 1
fi

# note that this will only work for simple, single-level yaml
# this also requires a whitespace between the key and value pair in the config (except for the cluster command, which requires single or double quotes)
execDir=$(awk '($0~/^execDir/){print $2}' $configFile | sed "s/'//g")

# insert config file checking script here!
perl ${execDir}/scripts/check_config.pl $configFile

logDir=$(awk '($0~/^logDir/){print $2}' $configFile | sed "s/'//g") 
outDir=$(awk '($0~/^outDir/){print $2}' $configFile | sed "s/'//g") 
numJobs=$(awk '($0~/^maxNumJobs/){print $2}' $configFile | sed "s/'//g")
clusterLine=$(awk '($0~/^clusterMode/){print $0}' $configFile | sed "s/\"/'/g")  # allows single or double quoting of the qsub command in the config file
clusterMode='"'$(echo $clusterLine | awk -F\' '($0~/^clusterMode/){print $2}')'"'



if [ ! -d $logDir ]; then
    mkdir -p $logDir
fi

DATE=$(date +"%Y%m%d%H%M")

if [ "$clusterMode" = "local" ]; then
    cmd="conf=$configFile snakemake -p -s ${execDir}/Snakefile_SV_wrapper --rerun-incomplete &> ${logDir}/MoCCA-SV_${DATE}.out"
# elif [ "$cluster" = "unlock" ]  # put in a convenience unlock?
#   cmd="conf=$configFile snakemake -p -s ${execDir}/Snakefile_SV_wrapper --unlock"
else
    cmd="conf=$configFile snakemake -p -s ${execDir}/Snakefile_SV_wrapper --rerun-incomplete --cluster ${clusterMode} --jobs $numJobs --latency-wait 300 &> ${logDir}/MoCCA-SV_${DATE}.out"
fi

echo "Command run: $cmd"
eval $cmd  # exec $cmd
