#!/bin/sh
#$ -S /bin/sh
#$ -j y

configFile=$1

if [ $# -eq 0 ]; then
    echo "Please specify config file with full path."
    exit 1
fi

if [ ! -f $configFile ]; then
    echo "Config file not found."
    exit 1
else
    # note that this will only work for simple, single-level yaml
    execDir=$(awk '($0~/^execDir/){print $2}' $configFile | sed "s/'//g")
    cluster=$(awk '($0~/^clusterMode/){print $2}' $configFile | sed "s/'//g")

    if [ "$cluster" = "SGE" ]; then
	    source /etc/profile.d/modules.sh
	    module load sge perl
	    perl $execDir/SV_wrapper.pl $configFile
	elif [ "$cluster" = "local" ]; then
		echo "TODO: write a tiny wrapper to kick off applicable snake jobs assuming one local core"
	fi
fi
