#!/bin/bash

# Run: bash run_tests.sh &> your_output_filename
# Compare the above output to the expected results here: run_tests.out

cd /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/
module load perl sge
module list

set -x

perl SV_wrapper.pl
# usage: SV_wrapper.pl [options] path/to/config.yaml at SV_wrapper.pl line 32.

perl SV_wrapper.pl /nonexistent/test/path/config.yaml
# ERROR: Cannot read config file.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_dup_key.yaml
# ERROR: Config file problem: YAML::Tiny found a duplicate key 'svaba' in line 'yes'
#  at SV_wrapper.pl line 47.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_wrong_execDir.yaml
# ERROR: /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/piiiiiiipeline/ does not exist.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_wrong_inDir.yaml
# ERROR: /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/piiiiiiiipeline/test_cases/test_in/ does not exist.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_wrong_outDir.yaml
# ERROR: Could not create out directory at /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeliiiiine/test_cases/test_out/.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_wrong_inFile.yaml
# ERROR: /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/test_in/tests_chr3bamssssssss.txt is not readable or contains no data.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_empty_inFile.yaml
# ERROR: /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/test_in/empty.txt is not readable or contains no data.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_wrong_refGenome.yaml
# ERROR: /DCEG/CGF/Bioinformatics/Production/Bari/refGenomes/hg1999999_canonical_correct_chr_order.fa does not exist.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_5cols_inFile.yaml
# ERROR: Input bam file must have three space-separated columns for TN mode.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_tab_sep_inFile.yaml
# ERROR: Input bam file must have three space-separated columns for $mode mode.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_wrong_logDir.yaml
# ERROR: Could not create log directory at /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeliiiiiiine/test_cases/test_out/logs/.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_wrong_queue.yaml
# ERROR: Unrecognized queue.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_maxNumJobs_text.yaml
# ERROR: Number of jobs must be a positive integer.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_maxNumJobs_neg.yaml
# ERROR: Number of jobs must be a positive integer.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_maxThreads_neg.yaml
# ERROR: Threads must be a positive integer.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_maxThreads_0.yaml
# ERROR: Threads must be a positive integer.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_wrong_chrPrefix.yaml
# ERROR: Chromosome prefix can only be "chr" or "".

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_no_mode.yaml
# ERROR: Unrecognized analysis mode.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_no_callers.yaml
# ERROR: No structural variant callers were selected.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_checkInterval_0.yaml
# ERROR: Check interval must be a positive integer.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_maxWaitChecks_non_integer.yaml
# ERROR: Max checks to wait for snakejob submission must be a positive integer.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_maxRequeue_text.yaml
# ERROR: Max times to requeue jobs must be a positive integer.

perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/config_snakejob_timelimit.yaml
# Running breakdancer workflow in TN mode.
# See logs/Snakefile_breakdancer_TN.out for details.
# Your job 8660744 ("submit.sh") has been submitted
# 
# ERROR: No snakejobs submitted within the time limit.

# perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/
# # 

# perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/
# # 

# perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/
# # 

# perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/
# # 

# perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/
# # 

# perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/test_cases/
# # 