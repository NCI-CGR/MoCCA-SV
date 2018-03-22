# SV_calling_pipeline (IN PROGRESS)

### I.  Description

This pipeline coordinates and monitors the submission of a list of bams for structural variant discovery, and annotation of results.  It consists of:
- SV_wrapper.sh: to submit the pipeline to the cluster
- config.yaml: configuration file
- SV_wrapper.pl: a perl script that 
  - checks config.yaml for issues
  - submits to the cluster the correct Snakefiles based on the user's selection of callers and mode
  - monitors the submitted jobs and requeues if necessary
  - checks the Snakefile log files for completion or error status
- modules/Snakefiles: one Snakefile for each caller/mode combination
- scripts/submit.sh: a bash script that SV_wrapper.pl calls to submit the Snakefiles to the cluster
- scripts/<caller>_to_bed.sh: a bash script that converts each caller's output to bed format
- scripts/<all others>: various scripts that are called within Snakefiles
- sv_callers/: a directory containing the callers used by the pipeline
- test_cases/: a directory containing test config files, test data, and a test script to run all tests

### II.  Run modes

The pipeline has three run modes available:
1. callOnly: perform SV calling on user-specified bams
2. annotateOnly: annotate and compare user-specified SV caller outputs 
3. callAndAnnotate: call SVs and annotate (user only has to specify the initial bam inputs for this mode; caller outputs are automatically detected)

### III.  SV callers

Callers available:
- Svaba
- Manta
- Delly
- Breakdancer
- Meerkat (in progress)

To add a caller, two new files are required: a snakefile to run the calling, and a caller_to_bed script to convert the output to bed format.

### IV.  Analysis modes

Analysis modes available:
1. Tumor/Normal: for matched tumor/normal pairs
2. Tumor only: for tumor samples with no paired normal (in progress)
3. De novo: for trios to detect de novo SVs in the proband (in progress)
4. Germline: for germline samples (in progress)

### V.  Input requirements

- Edited config.yaml (note that you can customize the name of this file)
- Reference genome
- Sorted and indexed bam files
- For __callOnly__ or __callAndAnnotate__ run modes, text file of samples to analyze
  - For tumor/normal mode
    - Three columns: sample name, tumor bam, normal bam
    - File names only - not path (the path is specified in config.yaml as "inDir")
      - The pipeline is currently set up such that all bams must be in the same directory
    - Space-delimited
    - No header
    - Example:

    ```
    301_pair 301_4E_tumor.bam 301_2A_blood.bam 
    275_pair 275_1B_tumor.bam 275_3A_blood.bam 
    275met_pair 275_2C_tumor.bam 275_3A_blood.bam 
    Best_pair 123_3S_tumor.bam 456_2M_blood.bam 
    ```
- For __annotateOnly mode__, text file of SV caller outputs
  - Space-delimited
  - Header: sample caller1 caller2 ...
  - File names with full paths
  - Example:
  ```
  sample svaba delly
  A101 /path/to/SV_out1.vcf /path/to/A101.out
  ```

### VI.  To run

- Copy config.yaml to your directory
- Edit config.yaml
- `qsub -q <queue> SV_wrapper.sh /full/path/config.yaml`
    - This wrapper script pulls the execution directory from the yaml file to run the perl script
    
### VII.  To monitor pipeline

- Look in log directory (specified in config file) for individual snakefile log files: Snakefile_<caller>_<analysis mode>.out.DATETIME for calling run modes, Snakefile_compare_and_annotate.out.DATETIME for annotation run modes
- Look in log directory for SV_wrapper.log.DATETIME, which monitors submission of workflows to the cluster and checks the Snakefiles above for completion/error status

### VIII.  Output directory structure example

- Tumor/normal mode
- Five callers selected in config.yaml

```
> sample_run
    > breakdancer_TN
        > calls (initial unfiltered SV calls)
        > somatic (somatic filter only)
        > somatic_filtered (somatic SV calls filtered for quality)
    > delly_TN
        > calls
        > somatic
    > manta_TN
        > sample_name
            > results
                > variants
    > svaba_TN
        > calls
    > meerkat_TN
        - TBD
    > logs
        - SV_wrapper.log (monitors jobs submitted to the cluster; automatically requeues Eqw jobs; final line will indicate completion or error status for overall pipeline)
        - Snakefile_caller1_<mode>.out
        - Snakefile_caller2_<mode>.outc
        - Snakefile_caller3_<mode>.out
        - etc.
```

        
