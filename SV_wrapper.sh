#!/bin/sh

# to run on SGE: just run bash script "run_pipeline.sh", or:
    # module load python3/3.7.0 sge perl singularity
        # earlier versions of python may throw an error like this one: https://bitbucket.org/snakemake/snakemake/issues/1015/singularity-error-typeerror-unorderable
    # unset module
    # qsub -q xlong.q -V -j y -S /bin/sh -o ${PWD} ${PWD}/SV_wrapper.sh ${PWD}/config.yaml

set -euo pipefail

die() {
    echo "ERROR: $* (status $?)" 1>&2
    exit 1
}

configFile=""
if [ $# -eq 0 ]; then
    echo "Please specify config file with full path."
    exit 1
else 
    configFile=$1
fi

if [ ! -f "$configFile" ]; then
    echo "Config file not found."
    exit 1
fi

# note that this will only work for simple, single-level yaml
# this also requires a whitespace between the key and value pair in the config (except for the cluster command, which requires single or double quotes)
execDir=$(awk '($0~/^execDir/){print $2}' $configFile | sed "s/['\"]//g")
logDir=$(awk '($0~/^logDir/){print $2}' $configFile | sed "s/['\"]//g") 
inDir=$(awk '($0~/^inDir/){print $2}' $configFile | sed "s/['\"]//g") 
outDir=$(awk '($0~/^outDir/){print $2}' $configFile | sed "s/['\"]//g") 
tempDir=$(awk '($0~/^tempDir/){print $2}' $configFile | sed "s/['\"]//g")
refGenome=$(awk '($0~/^refGenome/){print $2}' $configFile | sed "s/['\"]//g")
refDir=${refGenome%/*}
numJobs=$(awk '($0~/^maxNumJobs/){print $2}' $configFile | sed "s/['\"]//g")
latency=$(awk '($0~/^latency/){print $2}' $configFile | sed "s/['\"]//g")
clusterLine=$(awk '($0~/^clusterMode/){print $0}' $configFile | sed "s/\"/'/g")  # allows single or double quoting of the qsub command in the config file
clusterMode='"'$(echo $clusterLine | awk -F\' '($0~/^clusterMode/){print $2}')'"'

# check config file for errors
perl ${execDir}/scripts/check_config.pl $configFile

if [ ! -d "$logDir" ]; then
    mkdir -p "$logDir" || die "mkdir ${logDir} failed"
fi

if [ ! -d "$outDir" ]; then
    mkdir -p "$outDir" || die "mkdir ${outDir} failed"
fi

DATE=$(date +"%Y%m%d%H%M")
cd $outDir  # snakemake passes $PWD to singularity and binds it as the home directory, and then works relative to that path.
sing_arg='"'$(echo "-B ${inDir}:/input,${tempDir}:/scratch,${refDir}:/ref,${outDir}:/output,${execDir}:/exec")'"'

cmd=""
if [ "$clusterMode" == '"'"local"'"' ]; then
    cmd="conf=$configFile snakemake -p -s ${execDir}/Snakefile_SV_scaffold --use-singularity --singularity-args ${sing_arg} --rerun-incomplete &> ${logDir}/MoCCA-SV_${DATE}.out"
elif [ "$clusterMode" = '"'"unlock"'"' ]; then  # put in a convenience unlock
    cmd="conf=$configFile snakemake -p -s ${execDir}/Snakefile_SV_scaffold --unlock"
elif [ "$clusterMode" = '"'"dryrun"'"' ]; then  # put in a convenience dry run
    cmd="conf=$configFile snakemake -n -p -s ${execDir}/Snakefile_SV_scaffold"
else
    cmd="conf=$configFile snakemake -p -s ${execDir}/Snakefile_SV_scaffold --use-singularity --singularity-args ${sing_arg} --rerun-incomplete --cluster ${clusterMode} --jobs $numJobs --latency-wait ${latency} &> ${logDir}/MoCCA-SV_${DATE}.out"
    # --nt - keep temp files - can use while developing, especially for compare and annotate module.
fi

echo "Command run: $cmd"
eval $cmd 
