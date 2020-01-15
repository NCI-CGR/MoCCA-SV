# MoCCA-SV: Modular Calling, Comparison, and Annotation of Structural Variants

## Overview

### I.  Description

This pipeline coordinates and monitors the submission of a list of bams for structural variant discovery, and comparison/annotation of results.  You may opt to run calling alone, annotation alone, or both sequentially.  Multiple callers are included with MoCCA-SV, and additional callers may be added.  The pipeline may be run on an HPC or in a local environment.  Details are described in subsequent sections.

### II.  Dependencies

To run MoCCA-SV, you will need:
- python v3
- snakemake
- perl v5.18+
- singularity v2+

### III.  Analysis modes

One of the following analysis modes may be specified in the configuration file:
1. Tumor/Normal: for matched tumor/normal pairs; set analysisMode to 'TN'
2. Tumor only: for tumor samples with no paired normal; set analysisMode to 'TO' (under development)
3. De novo: for trios to detect de novo SVs in the proband; set analysisMode to 'de_novo' 
4. Germline: for germline samples; set analysisMode to 'germline' 

### IV.  Run modes

The pipeline has three run modes available; select one in the configuration file under "runMode":
1. callOnly: perform SV calling on user-specified bams
2. annotateOnly: annotate and compare user-specified SV caller outputs 
3. callAndAnnotate: call SVs and annotate (user only has to specify the initial bam inputs for this mode; caller outputs are automatically detected)

### V.  Callers available

Select from the following callers in the configuration file under "callers":
- svaba
- manta
- delly
- breakdancer

To add a caller, three new elements are required: a snakefile to run the calling, a caller_to_bed script to convert the output to bed format, and a container recipe file with the caller installed. Please see the developer's guide below for more details.


## User's guide

### I.  Input requirements

#### A.  Required for all run modes:
- Edited config.yaml (note that you can customize the name and location of this file)
- Sample file (required format and contents depend on run mode and analysis mode; see subsequent section for details)

#### B.  Required for __callOnly__ or __callAndAnnotate__ run modes:
- Reference genome (with our without indices; the pipeline will generate any missing index files)
- Sorted and indexed bam files

#### C.  Required for annotateOnly run mode:
- Caller output

### II.  Sample file formats

- Sample files for __callOnly__ or __callAndAnnotate__ run modes:
  - Tumor/normal mode:
    - Three space-delimited, headerless columns: sample name, tumor bam, normal bam
    - File names only - not path (the path is specified in config.yaml as "inDir")
      - The pipeline is currently set up such that all bams are assumed to be in the same directory
    - Example:

    ```
    301_pair 301_4E_tumor.bam 301_2A_blood.bam 
    275_pair 275_1B_tumor.bam 275_3A_blood.bam 
    275met_pair 275_2C_tumor.bam 275_3A_blood.bam 
    Best_pair 123_3S.bam 456_2M.bam 
    ```

  - De novo mode:
    - Four space-delimited, headerless columns: family ID, parent1 bam, parent2 bam, child bam
    - File names only
    - Example:

    ```
    Family_A mom.bam dad.bam child.bam
    F1234_1 parentA.bam parentB.bam child_1.bam
    F1234_2 parentA.bam parentB.bam child_2.bam
    ```

  - Tumor only mode:
  - Germline mode:
    - Two space-delimited, headerless columns: subject ID, bam
    - File name only (no path)
    - Example:

    ```
    Patient1 15324.bam
    Patient2 pt2.bam
    ```

- Sample files for __annotateOnly__ mode:
  - Note that this sample file is automatically generated if MoCCA-SV is used to call the data
  - Space-delimited with header line
  - Header: sample caller1 caller2 ...
  - File names with full paths
  - Example:

  ```
  sample svaba delly
  A101 /path/to/SV_out1.vcf /path/to/A101.out
  ```

### III.  Comparison and annotation

#### A. SV comparison methods

We employ two different methods to compare SVs across callers and to public SV databases.  For intra-chromosomal SVs, we use percent reciprocal overlap (e.g., to be considered comparable, SV1 must overlap at least X% of SV2, and SV2 must overlap at least X% of SV1).  For intra-chromosomal insertions, we first pad by a number of bases up- and down-stream, then apply percent reciprocal overlap.  For inter-chromosomal SVs, we look for overlap within a window surrounding each breakend.  

#### B. Annotation

We include three categories of annotation in the final output file:
1. Genomic context (non-reciprocal percent overlap with regions in UCSC browser's RepeatMasker, SegDups, and Telomere/Centromere tracks)
2. Public data (identity, as defined in section A, with SVs reported by 1000 Genomes, ClinGen, ClinVar, and DGV)
  - Insertions (defined as SVs <10bp) in the public datasets have been padded by +/- 500bp
  - Three public datasets are pulled from dbvar
    - 1000 Genomes (estd219): 66k variant regions from healthy individuals in the 1000 Genomes Consortium Phase3 Integrated SV dataset
    - ClinVar (nstd102): 765 SVs with clinical assertions
    - ClinGen (nstd37): laboratory-submitted data - 33,378 SVs with clinical assertions as classified by the original submitter
  - DGV data is from the relevant UCSC browser track and consists of intra-chromosomal SVs from healthy individuals
3. Geneset (any amount of overlap with RefSeq transcripts/gene names)

See our publication (____) for additional details.  Parameters defining these comparisons are user-configurable; see subsequent section.

### IV.  Editing the config.yaml

__Basic analysis parameters__

- `analysisMode:` Enter one value for analysisMode (TN, TO, germline, de_novo)
- `callers:` Select callers to run by providing a list in YAML format
  - The name used for the caller in the config file must match (including case) the caller name used in `modules/Snakefile_<caller>_<runMode>` and in `scripts/<caller>_to_bed.sh`, e.g.:  
    modules/Snakefile_DELLY_TN, scripts/delly_to_bed.sh, config file 'Delly2': NO  
    modules/Snakefile_delly_TN, scripts/delly_to_bed.sh, config file 'delly': YES
- `runMode:` Select one runMode by setting one option to 'yes' and the others to 'no'
- `refGenome:` Provide the full path and filename for a reference fasta
- `genomeBuild:` Record the genome build (either 'hg19' or 'b37')

__Annotation parameters__

- `annotateFile:` If using annotateOnly mode, provide the `/full/path/to/SV_files_for_annotation.txt`
  - This is the file indicating which caller outputs to compare and annotate.  If MoCCA-SV was used to generate the caller outputs, the file will be created for you and named SV_files_for_annotation.txt; otherwise you can manually create and name your own file in this format.  
- `annotationParams:` This section allows you to customize the stringency with which various comparisons are made.  
  - `interchromPadding:` base pairs to add on either side of the breakend to be used to find overlap when comparing inter-chromosomal SVs
  - `insertionPadding:` base pairs to add on either side of an insertion to find overlap when comparing across callers and annotating
  - `crossCallerOverlap:` minimum reciprocal overlap required to count as an intersection in other callers' data on the same subject
  - `genomicContextOverlap:` what % of an SV must reside in a queried region (repeat, segdup, centro/telomeric) to count as an intersection
  - `publicDataOverlap:` minimum reciprocal overlap required to count as an intersection (DGV, ClinVar, ClinGen, 1KG)

__Samples to analyze__
- `inFile:` Provide the full path and sample file that is appropriate for the analysis mode (TN, TO, germline, de_novo); N/A if using annotateOnly mode

__Directories__
- `inDir:` Location of the input BAM files (N/A if annotateOnly)
- `execDir:` Location of pipeline 
- `outDir:` Desired location for output files 
- `logDir:` Desired location for log files
- `tempDir:` Temporary or scratch directory, used for rapidly created and deleted files generated by parallelizable callers 

__Cluster parameters__
- `clusterMode:` 
  - If you are running on an HPC, provide the string you want to use to submit jobs.  Examples:
    ```
    'qsub -V -S /bin/sh -q queue.q -o /my/path/SV_out/logs -j y'
    # or
    'sbatch --get-user-env -D /my/path/SV_out --mem=8g'
    ```
  - If you are not on a cluster, you can run in local mode by entering `'local'`
  - If snakemake has locked the working directory, you can unlock by entering `'unlock'`
- `latency:` Enter the number of seconds to wait for snakemake to detect rule output.  Use 300+ if running on a cluster.
- `maxNumJobs:` Enter the maximum number of jobs to run in parallel; N/A if running locally
- `maxThreads:` Assign the number of threads for each caller listed in `callers:` above, in matching order.  For callers that can not use multi-threading, assign 1.  Assign 1 if running locally and/or without multi-threading.


### V.  To run

- Copy config.yaml to your directory
- Edit config.yaml and save
- Run `SV_wrapper.sh /full/path/config.yaml` as appropriate for your environment (e.g. on an HPC using the SGE job scheduler, run `qsub -q <queue> SV_wrapper.sh /full/path/config.yaml`)
    

### VI.  To monitor pipeline

- Look in log directory (specified in config file) for snakemake logged stdout `MoCCA-SV_DATETIME.out`
- Look in same log directory as above for logs for each rule (e.g. `snakejob.delly_call.119.sh.o123456`; file names will vary depeneding on environment)
- Look in log directory for SV_wrapper.log.DATETIME.  Example output:

  ```
  /path/to/config.yaml passes all checks.
  Command run: conf=/path/to/config.yaml snakemake -p -s /path/to/Snakefile_SV_scaffold --use-singularity --singularity-args "-B /path/to/input:/input,/ttemp/sv:/scratch,/path/to/refGenomes:/ref,/path/to/SV_out:/output,/path/to/pipeline:/exec" --rerun-incomplete --cluster "qsub -V -S /bin/sh -q queue.q -o /path/to/SV_out/logs -j y" --jobs 8 --latency-wait 300 &> /path/to/SV_out/logs/MoCCA-SV_201904041317.out
  ```

  - Note that for troubleshooting, you can re-run the command printed in this log with additional snakemake command line options, like `-n` for a dry run or `--dag ... | dot -Tsvg > dag.svg` to visualize the directed acyclic graph.  See snakemake documentation for more details.


### VI. Output

MoCCA-SV has two main outputs: SV calls from each caller, and the union of all callers for each sample along with comparison and annotation information.
  1. Each caller run will write to its own directory (e.g. delly run in tumor/normal mode will create and write to a directory called `delly_TN`).  See the individual callers' documentation for descriptions of output.
  2. Running in callAndAnnotate or callOnly modes will create the directory `compare_and_annotate`.  This directory contains the files `intrachromosomal_SVs_<sample>`, which contain the superset of SVs from all callers.  *NOTE: this is under development, and inter-chromosomal SVs are being integrated currently.*

Example output directory structure is as follows.  Exact output will depend upon run mode and analysis mode selected.

```
|--- user/defined/output_dir/
   |--- delly_TN/
   |--- svaba_TN/
   |--- logs/
   |  |--- MoCCA-SV_<datetime>.out
   |--- SV_files_for_annotation.txt
   |--- compare_and_annotate/
      |--- intrachromosomal_SVs_sampleA
      |--- intrachromosomal_SVs_sampleB
```
Headers from file `intrachromosomal_SVs_<sample>`:

|Field|Description|
|---|---|
|#CHROM|chromosome|
|pos1|upstream breakend|
|pos2|downstream breakend|
|svaba|count of comparable SVs in svaba (based on % reciprocal overlap); "orig" if this SV originated from this caller|
|breakdancer|count of comparable SVs in svaba (based on % reciprocal overlap); "orig" if this SV originated from this caller|
|delly|count of comparable SVs in svaba (based on % reciprocal overlap); "orig" if this SV originated from this caller|
|manta|count of comparable SVs in svaba (based on % reciprocal overlap); "orig" if this SV originated from this caller|
|caller_count|total number of callers reporting a comparable SV at this position|
|match_region|chrom and outer coordinates of a matching pair of SVs in the format chr:end1-end2; serves as a key to find pairwise matches in the superset call data|
|RepeatMasker|count of overlaps between SV and repeat regions|
|SegDups|count of overlaps between SV and segmentally duplicated regions|
|Telo_Centro|count of overlaps between SV and telomeric or centromeric regions|
|1KG_sv_type|SV type reported for each overlapping SV (e.g. "copy_number_gain")|
|1KG_pheno|phenotype reported for each overlapping SV ("healthy" for 1000 Genomes)|
|1KG_clinical_assertion|determination of clinical significance of SV ("na" for 1000 Genomes)|
|ClinGen_sv_type|SV type reported for each overlapping SV (e.g. "copy_number_gain")|
|ClinGen_pheno|phenotype reported for each overlapping SV (e.g. "Developmental_delay")|
|ClinGen_clinical_assertion|determination of clinical significance of SV (e.g. "Benign" or "Pathogenic")|
|ClinVar_sv_type|SV type reported for each overlapping SV (e.g. "copy_number_gain")|
|ClinVar_pheno|phenotype reported for each overlapping SV (e.g. "Developmental_delay")|
|ClinVar_clinical_assertion|determination of clinical significance of SV (e.g. "Benign" or "Pathogenic")|
|DGV_sv_type|SV type reported for each overlapping SV (e.g. "copy_number_gain")|
|DGV_pheno|phenotype reported for each overlapping SV ("healthy" for DGV)|
|DGV_clinical_assertion|determination of clinical significance of SV ("na" for DGV)|
|RefSeq_transcripts|semicolon-delimited list of transcripts overlapping the SV|
|RefSeq_genes|semicolon-delimited list of gene names overlapping SV|
|Original_caller_output|all fields from the original caller's output, delimited by a double underscore "__"|

*Think about differences for inter-chrom SVs, e.g. instead of all overlapping genes, just report those that the break ends reside in?  or all genes within x bp?*

## Developer's guide

### I.  Pipeline architecture

MoCCA-SV is a Snakemake pipeline controlled by a user-configurable YAML file.  The file Snakefile_SV_scaffold pulls in other sets of rules based on the chosen configuration options, and for either of the two calling run modes, runs a few rules that are required regardless of caller choice.  The scaffold dictates which sets of rules to include based on the analysis mode and the list of callers.  Snakefiles in the `modules/` directory contain the sets of rules that pertain to a given caller and analysis mode.  They are named accordingly, e.g. `modules/Snakefile_delly_TN` contains the rules to run delly on tumor/normal samples.  The scaffold matches the callers and analysis mode listed in the config to the modules/Snakefiles in order to include the applicable rules, but in such a way as to minimize code changes required to add new callers.  


### II.  To add callers

There are three steps required to add a caller:
1.  Construct a Snakefile, named `modules/Snakefile_<caller>_<anMode>`, to run the new caller in a given analysis mode.  You may start with the appropriate `TEMPLATE_Snakefile_caller_<anMode>` file found in the `modules/` directory.  Note that many variables are sourced from the config file in Snakefile_SV_scaffold and are available in snakefiles that are included from the scaffold.  Be sure that the caller name used in this filename is identical to the caller name you use in the config file.
2.  Add a shell script to the `scripts/` directory to convert the new caller's output to bed format.  This can generally be done in three awk statements; to start, see `scripts/TEMPLATE_caller_to_bed.sh` file.  Like in step 1, ensure that you use the same caller name to name this script.
3.  Create a container with the caller (and any other dependencies) installed.  This can be a singularity container or a docker container, preferably hosted on a public-facing hub.  You may start with `TEMPLATE_singularity_recipe`.  Be sure you are running the relevant rules in your snakefile within the container.

# Citations:

This pipeline was initially described here:
- Ballew BJ, Yeager M, Hicks B, Zhu B. MoCCA-SV: A Flexible Ensemble Framework for Structural Variant Analysis. Poster session presented at: 19th Annual General Meeting of Advances in Genome Biology and Technology (AGBT); 2019 Feb 27 – Mar 3, Marco Island FL.  

This pipeline currently uses the following callers:
- Wala JA et al. SvABA: genome-wide detection of structural variants and indels by local assembly (2018). Genome Res, 28(4):581-91.
- Chen K et al. BreakDancer: an algorithm for high-resolution mapping of genomic structural variation (2009). Nat Methods, 6(9):677-81.
- Rausch T et al. DELLY: structural variant discovery by integrated paired-end and split-read analysis (2012). Bioinformatics, 28(18):i333-i339.
- Chen X et al. Manta: rapid detection of structural variants and indels for germline and cancer sequencing applications (2016). Bioinformatics, 32(8):1220-2.

This pipeline uses the following workflow management and containerization solutions:
- Köster J et al. Snakemake--a scalable bioinformatics workflow engine (2012). Bioinformatics, 28(19): 2520–2.
- Kurtzer GM, et al. Singularity: Scientific containers for mobility of compute (2017). PLoS ONE, 12(5): e0177459.
- Sochat V, et al. Enhancing reproducibility in scientific computing: Metrics and registry for Singularity containers (2017). PLoS ONE, 12(11): e0188511.
