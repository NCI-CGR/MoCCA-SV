#!/bin/sh
#$ -S /bin/sh
#$ -j y
#$ -q seq-calling.q

# queue is currently hard-coded, because I can't make -q submit properly from the perl script.

snake=$1
queue=$2
execDir=$3
logDir=$4
threads=$5
numJobs=$6
configFile=$7
outDir=$8
stamp=$9

# still can't get the .o file from this guy to go to the right spot.  tried -o $dir in the perl script; wont submit job.
# export SGE_O_HOME=outdir?

source /etc/profile.d/modules.sh
module load python3/3.5.1 sge
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$execDir"sv_callers/Meerkat/src/mybamtools/lib"
cd $outDir  # this makes the breakdancer histograms go to the current working directory - maybe I want to make this a little more sophisticated and only cd if breakdancer=yes, and send it to the right spot?  maybe have the snakefile move them?

log=${snake#*/}

unset module  # this allows me to use -V in the qsub job below without getting the annoying bash_func_module errors in the output logs


if [ "$threads" = "annOnly" ]; then
	# conf=$configFile snakemake -s $execDir$snake --cluster "qsub -V -q $queue -j y -o $logDir" --jobs $numJobs --latency-wait 300 &> $logDir$log".out."$stamp
	conf=$configFile snakemake -s $execDir$snake --rerun-incomplete --cluster "qsub -V -q $queue -j y -o $logDir" --jobs $numJobs --latency-wait 300 &> $logDir$log".out."$stamp
elif [ "$threads" = "annotate" ]; then
	conf=$configFile snakemake --config inFile="${outDir}SV_files_for_annotation.txt" -s $execDir$snake --rerun-incomplete --cluster "qsub -V -q $queue -j y -o $logDir" --jobs $numJobs --latency-wait 300 &> $logDir$log".out."$stamp
else
	conf=$configFile snakemake -s $execDir$snake --rerun-incomplete --cluster "qsub -V -q $queue -j y -o $logDir -pe by_node $threads" --jobs $numJobs --latency-wait 300 &> $logDir$log".out."$stamp
fi
