#!/usr/bin/env python3

import os

# snakemake -s modules/Snakefile_delly_somatic --cluster "qsub -o /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/snake_tests/ -j y -pe by_node 2" --jobs 100 --latency-wait 300

conf = os.environ.get("conf")
configfile: conf
execDir = config['execDir']
parentDir = config['outDir']
workingDir = parentDir + 'delly_TN/'
dataDir = config['inDir']
bamList = config['inFile']
nt = config['maxThreads']
ref = config['refGenome']

# read in a file where each row has the pair name, tumor file name, normal file name
# this could change depending on functionality required, eg
# if tumor and normal bams have the same name but are in different directories
# (currently assuming same directory for T and N)
bamDict = {}
allBams = []
with open(bamList) as f:
    for line in f:
        (fam, parent1, parent2, child) = line.split()
        bamDict[fam] = (dataDir + parent1, dataDir + parent2, dataDir + child)
        allBams.extend((dataDir + parent1, dataDir + parent2, dataDir + child))

TYPES = ['DEL', 'DUP', 'INV', 'BND', 'INS']

def get_parent1_bam(wildcards):
    (parent1, parent2, child) = bamDict[wildcards.sample]
    return parent1


def get_parent1_index(wildcards):
    (parent1, parent2, child) = bamDict[wildcards.sample]
    return parent1 + '.bai'


def get_parent2_bam(wildcards):
    (parent1, parent2, child) = bamDict[wildcards.sample]
    return parent2


def get_parent2_index(wildcards):
    (parent1, parent2, child) = bamDict[wildcards.sample]
    return parent2 + '.bai'


def get_child_bam(wildcards):
    (parent1, parent2, child) = bamDict[wildcards.sample]
    return child


def get_child_index(wildcards):
    (parent1, parent2, child) = bamDict[wildcards.sample]
    return child + '.bai'

rule all:
    input:
        expand(workingDir + 'somatic/{sample}_{type}.bcf', sample=bamDict.keys(), type=TYPES)
        # expand(workingDir + 'somatic/{sample}/samples.tsv', sample=bamDict.keys()),
        # expand(workingDir + 'calls/{sample}_{type}.bcf', sample=bamDict.keys(), type=TYPES)

rule delly_call_individual_samples:
    input:
        sample = '{bam}',
        sampleIndex = '{bam}.bai',
        ref = ref
    params:

    output:
        workingDir + 'calls/{bam}_{type}.bcf'
    shell:
        '{params.path}delly_v0.7.7_parallel_linux_x86_64bit call \
            -t {params.tp} \
            -o {output} \
            -g {input.ref} \
            {input.sample}'
            #-x /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/sv_callers/delly/excludeTemplates/human.hg19.excl.tsv \
            # exclude file?
            # or, wildcards.type instead of params

rule delly_merge:
    input:
        expand(workingDir + 'calls/{bam}_{{type}}.bcf', bam=allBams)
    params:
        tp = '{type}',
        path = execDir + 'sv_callers/'
    output:
    shell:
        '{params.path}delly_v0.7.7_parallel_linux_x86_64bit merge \
            -t {params.tp} \
            -m 500 \
            -n 1000000 \
            -o $working_dir$family.$i.bcf \
            -b 500 \
            -r 0.5 \
            {input}'






rule delly_create_tsv:
    input:
        t = get_tumor_bam,
        tIndex = get_tumor_index,
        n = get_normal_bam,
        nIndex = get_normal_index
    output:
        workingDir + 'somatic/{sample}_samples.tsv'
    params:
        path = execDir + 'scripts/'
    shell:
        'module load samtools;'
        '{params.path}create_tsv.sh {input.t} tumor {output};'
        '{params.path}create_tsv.sh {input.n} control {output}'
    # tab-delimited sample description file where the first column is the sample id (as in the VCF/BCF file) and the second column is either tumor or control

rule delly_pre_filter:
    input:
        bcf = workingDir + 'calls/{sample}_{type}.bcf',
        tsv = workingDir + 'somatic/{sample}_samples.tsv'
    params:
        tp = '{type}',
        path = execDir + 'sv_callers/'
    output:
        workingDir + 'somatic/{sample}_{type}.bcf'
    shell:
        '{params.path}delly_v0.7.7_parallel_linux_x86_64bit filter \
            -t {params.tp} \
            -f somatic \
            -o {output} \
            -s {input.tsv} \
            {input.bcf}'
            # tab-delimited sample description file where the first column is the sample id (as in the VCF/BCF file) and the second column is either tumor or control
# Getting an error: Sample type for REBC_REBC_UA0193_A90G-10A-01D_blood_A is neither tumor nor control
# maybe need ".bam" on end?



# rule delly_re_genotype:
#     input:
#     output:
#     shell:
#         'delly call -t DEL -g hg19.fa -v t1.pre.bcf -o geno.bcf -x hg19.excl tumor1.bam control1.bam ... controlN.bam'

# rule delly_post_filter:
#     input:
#     output:
#     shell:
#         'delly filter -t DEL -f somatic -o t1.somatic.bcf -s samples.tsv geno.bcf'