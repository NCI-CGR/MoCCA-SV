#!/DCEG/Resources/Tools/perl/5.18.0/bin/perl -w

use strict;
use warnings;
# use DateTime;
use POSIX qw(strftime);
# use constant DATETIME => strftime("%Y%m%d_%H%M%S", localtime);
use Capture::Tiny ':all';
use List::MoreUtils qw(uniq);
#use Getopt::Long;
use YAML::Tiny;
use Array::Diff;
# use Data::Dumper;  # used for debugging only

@ARGV == 1 or die "
usage: $0 [options] full/path/config.yaml
";

my $config = $ARGV[0];
chomp($config);

######################## Get and check parameters ########################

# Open the config and make an error handler so that the script dies on malformed YAML config file, including duplicate keys
die "ERROR: Cannot read config file.\n" if (! -r "$config" || ! -s "$config");
my $yaml;

{
    local $SIG{__WARN__} = sub {
        die "ERROR: Config file problem: @_";
    };
    $yaml = YAML::Tiny->read("$config");
}

# # Make directory for output and logs
# my $outDir = make_dir($yaml->[0]->{outDir}); 
# my $logDir = make_dir($yaml->[0]->{logDir});

# # Make log file for output from this wrapper
# open(my $log, '>', $logDir."SV_wrapper.log.".DATETIME) or die "ERROR: Could not write to ".$logDir.".SV_wrapper.log.".DATETIME."\n";

# Make an error handler to print any die error messages to the SV_wrapper.log file
    # just print to stdout; it will either be redirected into the cluster log or printed to the screen if run interactively
# local $SIG{__DIE__} = sub {
#     my ($message) = @_;
#     print $log $message;
# };

# Check that required directories exist
my $execDir = check_dir($yaml->[0]->{execDir});
my $inDir = check_dir($yaml->[0]->{inDir});

# Get queue/workflow parameters from config file and check them
# my $queue = $yaml->[0]->{queue};
# chomp($queue);
# die "ERROR: Unrecognized queue in config file.\n" if ($queue !~ /^[x]{0,2}long\.q$|^all\.q$|^research\.q$|^seq-alignment\.q$|^seq-calling[2]*\.q$|^seq-gvcf\.q$/);

my $numJobs = $yaml->[0]->{maxNumJobs};
chomp($numJobs);

my $clusterMode = $yaml->[0]->{clusterMode};
chomp($clusterMode);
if ($clusterMode =~ /^[A-Za-z0-9.,\-_\/'" ]+$/ && $clusterMode !~ /local/) {
    die "ERROR: Number of jobs (maxNumJobs in config file) must be a positive integer.\n" if ($numJobs !~ /^[1-9]+[0-9]*$/);
}
elsif ($clusterMode !~ /^[A-Za-z0-9.,\-_\/'" ]+$/) {
    die "ERROR: Unacceptable characters in clusterMode.\n";
}

# my $checkInterval = $yaml->[0]->{checkInterval};
# chomp($checkInterval);
# die "ERROR: checkInterval in config file must be a positive integer.\n" if ($checkInterval !~ /^[1-9]+[0-9]*$/);
# my $maxWaitChecks = $yaml->[0]->{maxWaitChecks};
# chomp($maxWaitChecks);
# die "ERROR: Max checks to wait for snakejob submission (maxWaitChecks in config file) must be a positive integer.\n" if ($maxWaitChecks !~ /^[1-9]+[0-9]*$/);
# my $maxRequeue = $yaml->[0]->{maxRequeue};
# chomp($maxRequeue);
# die "ERROR: Max times to requeue jobs (maxRequeue in config file) must be a positive integer.\n" if ($maxRequeue !~ /^[1-9]+[0-9]*$/);

my $build = $yaml->[0]->{genomeBuild};
chomp($build);
die "ERROR: genomeBuild in config file can only be hg19 or b37.\n" if ($build ne "hg19" && $build ne "b37");
my @paramArray = ("interchromPadding", "crossCallerOverlap", "genomicContextOverlap", "publicDataOverlap");
my $param;
foreach (@paramArray) {
    $param = $yaml->[0]->{annotationParams}->{$_};
    die "ERROR: $_ in config file must be a number.\n" if ($param !~ /^[0-9.]+$/);
}

# check run modes
my @runModeArray = ("callAndAnnotate", "callOnly", "annotateOnly");
my $runMode;
my $yesFlag = 0;
foreach (@runModeArray) {
    my $currMode = $yaml->[0]->{runMode}->{$_};
    die "ERROR: $_ in config file must be yes/no.\n" if ($currMode !~ /yes|no/i);
    if ($currMode =~ /yes/i) {
        $yesFlag++;
        $runMode = $_;
    }
}
die "ERROR: A single runMode must be selected in config file.\n" if $yesFlag != 1;

# get analysis mode
my $anMode;
if ($runMode !~ /annotateOnly/) {
    $anMode = $yaml->[0]->{analysisMode};
    chomp($anMode);
    die "ERROR: Unrecognized analysis mode.\n" if ($anMode !~ /TN|TO|de novo|germline/)
}

# Pull the caller names and threads for each into an array so this can be easily expanded if new callers are added
# check snakefile and/or to_bed scripts depending on run mode
my @callers;
for (@{$yaml->[0]->{callers}}) { 
    push @callers, $_;
    if ($runMode =~ /callAndAnnotate|callOnly/) {
        my $sf = $execDir."/modules/Snakefile_".$_."_".$anMode;
        die "ERROR: $sf not found.  Check that callers, execDir, and analysisMode are correct in config file.\n" if (! -e $sf);
    }
    if ($runMode =~ /callAndAnnotate|annotateOnly/) {
        my $script = $execDir."/scripts/".$_."_to_bed.sh";
        die "ERROR: No executable file found for $script.  Check execDir and callers in config file.\n" if (! -x $script);
    }
}
die "ERROR: No structural variant callers were selected in config file.\n" if (! @callers);

# checks for parameters that are not required for annotateOnly mode:
my $inFile = $yaml->[0]->{inFile};
my $refGenome = $yaml->[0]->{refGenome};
my @threads;
if ($runMode !~ /annotateOnly/) {
    # Check that required files exist    
    die "ERROR: $inFile is not readable or contains no data.\n" if (! -r $inFile || ! -s $inFile);
    die "ERROR: $refGenome does not exist.\n" if (! -e $refGenome);

    # Check that the samples file has the correct # of columns
    check_samples_file($anMode, $inFile);

    # check array of max threads values for each caller
    if ($clusterMode !~ /local/) {
        for (@{$yaml->[0]->{maxThreads}}){
            push @threads, $_;
            die "ERROR: Threads must be positive integers.\n" if ($_ !~ /^[1-9]+[0-9]*$/);
        }
        die "ERROR: Threads must be specified for each caller.\n" if (scalar @threads != scalar @callers);
    }

    # Check for chr consistency
    my $cmd;
    if ($build =~ /hg19/) {
        $cmd = "head -n3 $refGenome | grep -c '>chr'";
    }
    elsif ($build =~ /b37/) {
        $cmd = "head -n3 $refGenome | grep -c '>[0-9]'";
    }
    my $stdout = capture {
        system($cmd);
    };
    die "ERROR: genomeBuild and refGenome have inconsistent chromosome notations.\n" if ($stdout == 0);
}

# checks for parameters required only for annotateOnly mode:
if ($runMode =~ /annotateOnly/) {
    my $annFile = $yaml->[0]->{annotateFile};
    die "ERROR: $annFile is not readable or contains no data.\n" if (! -r $annFile || ! -s $annFile);
    open(my $fh, '<', $annFile) or die "ERROR: Could not open $annFile.\n";
    my $firstLine = <$fh>;
    chomp($firstLine);
    close $fh;
    my @line = split(/ /, $firstLine);
    @line = @line[1..$#line];
    my $diff = Array::Diff->diff(\@line, \@callers);
    die "ERROR: Headers from $annFile do not match callers listed in config file.\n" if ($diff->count);
}


print "$config passes all checks.\n";














# ######################## Submit jobs ########################

# # Run the appropriate workflow(s)
# my @submitJobs;  # an array with the job IDs for each of the "submit.sh" qsub jobs (one per caller) - these jobs will keep running for as long as the submitted snakefile is running

# # Iterate through items in an array of caller names, to allow for easy caller addition
# #if (($anMode eq "TN" || $anMode eq "de_novo" || $anMode eq "germline" || $anMode eq "TO") && $runMode !~ /annotateOnly/) {
# if ($runMode !~ /annotateOnly/) {
#     my $i = 0;
#     foreach (@callers) {
#         print $log "Running $_ workflow in $anMode analysis mode.\n";
#         print $log "See logs/Snakefile_".$_."_".$anMode.".out.".DATETIME." for details.\n";
#         push(@submitJobs, submit_workflow($log, "Snakefile\_".$_."\_".$anMode, $execDir, $logDir, $threads[$i], $queue, $numJobs, $config, DATETIME));
#         $i++;
#         sleep 30;
#     }
# }
# # elsif ($runMode !~ /annotateOnly/) { 
# #     die "ERROR: Unrecognized analysis mode.\n";  # this should never be reached, as it will get caught when searching for the snakefile_caller_mode
# # }

# ######################## Check on jobs ########################

# # Check on submitted jobs; automatically requeue Eqw a few times

# my %jobs;  # hash of arrays that contain the job ID and other relevant info that gets printed to the SV_wrapper log file
# my $checkJobsFlag = 0;

# # initial check if the submit.sh jobs are running
# foreach (@submitJobs) {  # array will be empty if runMode=annotateOnly
#     if (`qstat | grep \"^$_\"` ne "") {
#         $checkJobsFlag++;
#     }
# }

# my $allDoneFlag = 1;  # set to 0 when all jobs are done ("done" means finished or in error)
# my $waitTime = 0;  # set a max time to wait for the first sub-job to be submitted - user sets max in config file
# while(($checkJobsFlag > 0 || $allDoneFlag != 0) && $waitTime < $maxWaitChecks && $runMode !~ /annotateOnly/) {  # while any of the submit.sh jobs are still running, or while any job IDs refer to jobs that are still running, keep looping
#     sleep $checkInterval;
#     get_snake_jobs($logDir, \%jobs, $maxRequeue);  # get the job IDs of the snakejobs from the log files

#         #TODO: test this.  can set shell to something non-existent (eg -S /) to make it go into Eqw.

#     # note that this sub and the one below call a private sub that evaluates the jobs and acts based on status (r/Eqw/etc)
#     if (-e $outDir."manta*/*/workspace/pyflow.data/logs/pyflow_log.txt") {
#         get_pyflow_jobs(\%jobs, $outDir, $maxRequeue);  # get the job IDs of the pyflowTasks from the pyflow log in a subdirectory of the manta output
#     }
#     $allDoneFlag = print_job_status($log, \%jobs, $maxRequeue);  # returns a 0 if all jobs are done (either finished or in error)
#     # above will return 0 if no jobs have been submitted yet, but that's ok, because the parent submit.sh job will still be running
#     $checkJobsFlag = 0;
#     foreach (@submitJobs) {
#         if (`qstat | grep \"^$_\"` ne "") {
#             $checkJobsFlag++;
#         }
#     }
#     if (!%jobs) {  # timeout if no jobs (besides the initial submit job) are submitted (e.g. if the directory is locked)
#         $waitTime++;
#     }
#     # print Dumper(\%jobs)."\n";  # debugging
# }
# if ($waitTime >= $maxWaitChecks) {
#     foreach (@submitJobs) {
#         `qdel $_`;
#     }
#     die "ERROR: No snakejobs submitted within the time limit.\n";
# }
# # Note - this will keep looping until all callers are done. 

# ######################## Check on logs ########################

# # check the log files for successful completion (there will be one of these logs per caller, regardless of number of samples)
# my $callerSuccessCount = 0;
# if ($runMode !~ /annotateOnly/) {
#     foreach (@callers) {
#         my $file = $logDir."Snakefile_".$_."_".$anMode.".out.".DATETIME;
#         if (-r $file && -s $file) {
#             open(my $fh, '<', $file) or die "ERROR: Could not open $file.\n";
#             while (my $line = <$fh>) {
#                 chomp($line);
#                 if ($line =~ /100%/) {
#                     print $log "$file finished successfully.\n";
#                     $callerSuccessCount++;
#                     last;
#                 }
#                 elsif ($line =~ /error/i && $runMode =~ /callOnly/i) {
#                     print $log "$file contains an error.\n";
#                     last;
#                 }
#                 elsif ($line =~ /error/i && $runMode =~ /callAndAnnotate/i) {
#                     print $log "$file contains an error.  Annotation pipeline will not be started.\n";
#                     last;
#                 }
#                 else { next; } 
#             }
#             close $fh;
#         }
#     }
# }

# ######################## Add annotation ########################

# # prep annotation input file
# # TODO: consider prepping file for all callers that finish successfully, even if some are in error?
# my $arrSize = scalar @callers;
# if ($callerSuccessCount == $arrSize) {
#     my %samples;
#     foreach (@callers) {
#         my $file = $outDir."SV_files_for_annotation_".$_.".txt";
#         open(my $fh, '<', $file) or die "ERROR: Could not open $file.\n";
#         while (<$fh>) {
#             chomp;
#             my ($labels, $data) = split(/\s+/, $_);
#             push @{$samples{$labels}}, $data;
#         }
#         close $fh;
#         #`rm $file` or warn "Unable to delete $file.\n"; TODO remove intermediate per-caller txt file to clean up?  will this work with backticks?
#     }
#     my $outFile = $outDir."SV_files_for_annotation.txt";
#     open(my $fh, '>', $outFile) or die "ERROR: Could not open $outFile.\n";
#     foreach my $k (keys %samples) {
#         print $fh "$k @{$samples{$k}}\n";
#     }
#     close $fh;
# }

# # kick off annotation pipeline if all callers have finished successfully
# if ($callerSuccessCount == $arrSize && $runMode =~ /callAndAnnotate/) {
#     print $log "Adding annotation.\n";
#     print $log "See logs/Snakefile_compare_and_annotate.out.".DATETIME." for details.\n";
#     my $annoJobID = submit_workflow($log, "Snakefile\_compare\_and\_annotate", $execDir, $logDir, "annotate", $queue, $numJobs, $config, DATETIME);
# }
# elsif ($runMode =~ /annotateOnly/) {
#     print $log "Adding annotation.\n";
#     print $log "See logs/Snakefile_compare_and_annotate.out.".DATETIME." for details.\n";
#     my $annoJobID = submit_workflow($log, "Snakefile\_compare\_and\_annotate", $execDir, $logDir, "annOnly", $queue, $numJobs, $config, DATETIME);   
# }
# #TODO: add monitoring of the annotation snake jobs
# # note that currently I get all snake job IDs from the log files.  can I make snakemake output them and grab them from that log?

# close $log;

#####################################################################################################
############################################ Subroutines ############################################
#####################################################################################################

# sub make_dir
# {
#     my $dir = shift;
#     chomp($dir);
#     $dir =~ s|/?$|/|;  # ensure the path has a single trailing slash
#     if (! -d $dir) {
#         mkdir($dir) or die "ERROR: Could not create directory at $dir.\n";
#     } 
#     return $dir;
# }

sub check_dir
{
    my $dir = shift;
    chomp($dir);
    $dir =~ s|/?$|/|;
    die "ERROR: $dir does not exist.\n" if (! -d $dir);
    return $dir;
}

sub check_samples_file
{
    my ($anMode, $inFile) = @_;
    open(my $in, '<', $inFile) or die "ERROR: Could not open $inFile.\n";
    my $firstLine = <$in>;
    chomp($firstLine);
    close $in;
    my @line = split(/ /, $firstLine);
    die "ERROR: Input bam file must have three space-separated columns for $anMode mode.\n" if ($anMode eq "TN" && scalar(@line) != 3);
    # die "ERROR: Input bam file must have ____ space-separated columns for $anMode mode.\n" if ($anMode eq "TO" && scalar(@line) != _);
    die "ERROR: Input bam file must have four space-separated columns for $anMode mode.\n" if ($anMode eq "de_novo" && scalar(@line) != 4);
    # die "ERROR: Input bam file must have ____ space-separated columns for $anMode mode.\n" if ($anMode eq "germline" && scalar(@line) != _);
}


# sub submit_workflow
# {
#     my ($log, $snake, $execDir, $logDir, $threads, $queue, $numJobs, $config, $stamp) = @_;
#     my @sub = ("qsub", $execDir."scripts/submit.sh", "modules/$snake", $queue, $execDir, $logDir, $threads, $numJobs, $config, $outDir, $stamp);
#     my $stdout;
#     my $stderr;
#     my $exit;
#     ($stdout, $stderr, $exit) = capture {
#         # join array into sentence, then pass string to system
#         system(@sub);  # use system here (which returns exit status and results in stdout job submission info, eg { Your job 8660745 ("submit.sh") has been submitted } ), rather than backticks (which returns stdout)
#     };
#     if ($exit == 0) {
#         my ($jobid) = $stdout =~ /^Your job ([0-9]+)/;  # extract the job ID
#         print $log "$stdout\n";
#         return $jobid;
#     }
#     else { die "ERROR: Failed to submit job to cluster: exit code $exit\n"; }
# }

# sub get_snake_jobs
# {
#     my ($logDir, $jobs_ref, $maxRequeue) = @_;  # where to read sge log files (set in config), reference to hash of arrays %jobs, max times to requeue Eqw

#     opendir(my $dh, $logDir) or die "ERROR: Can't access log directory $logDir.";
#     while (my $file = readdir($dh)) {
#         if ($file =~ /^\S+\.o[0-9]+\b/){
#             my ($jobID) = $file =~ /^\S+\.o([0-9]+)\b/;  # capture the jobID from the log file name (which will look something like "snakejob.svaba_call.1.sh.o8558015")
#             check_jobs($file, $jobID, $jobs_ref, $maxRequeue);
#         }
#     }
#     closedir($dh);
# }

# sub get_pyflow_jobs
# {
#     my ($jobs_ref, $outDir, $maxRequeue) = @_;  # reference to hash of arrays %jobs, path to manta output (set in config), max times to requeue Eqw

#     # capture the job ID from the pyflow log
#     # only do this if the log file exists
#     # otherwise, this will generate error messages while you wait for the bam filtering step to finish and manta to start
#     push(my @pyflow_jobs, `grep -Eo \"Task submitted to sge queue with job_number: [0-9]+\$\" cd $outDir/manta*/*/workspace/pyflow.data/logs/pyflow_log.txt | awk \'\{print \$8\}\'`);
#     chomp(@pyflow_jobs);

#     # print join("\n", @pyflow_jobs);  # debugging
#     foreach my $jobID (@pyflow_jobs) {
#         check_jobs("pyflowTask", $jobID, $jobs_ref, $maxRequeue);
#     }
# }

# sub check_jobs
# {
#     my ($file, $jobID, $jobs_ref, $maxRequeue) = @_;  # log file that the job ID was taken from ("pyflowTask" for pyflowTask jobs), submitted job ID, reference to hash of arrays, max times to requeue Eqw


#     # TODO: experiment with making grep more precise.  do I need the -E flag to use \b etc?
#     my $state = `qstat | grep \"$jobID\" | awk \'{print \$5}\'`;  # get the state from qstat - note that for really quick jobs, the state will be blank 
#     chomp($state);

#     # populate a hash of arrays: job ID as key; file name [0], run status [1], and # times submitted [2] as array entries
#     if (!exists ${$jobs_ref}{$jobID}) {
#         # initial addition of a job to the hash
#         ${$jobs_ref}{$jobID} = [ $file, $state, "1" ];
#     }
#     elsif ($state =~ /Eqw/ && ${$jobs_ref}{$jobID}[2] < $maxRequeue) { 
#         # this will re-queue at most 3 times if in Eqw 
#         # note that Eric says qresub plays nicely with snakemake
#         ${$jobs_ref}{$jobID}[2]++;
#         `qresub $jobID`;
#         # do I need to capture the resub job ID and add it to the hash?  or will it create a new log file or qstat line and get captured that way?
#     }
#     elsif ($state eq "" && ${$jobs_ref}{$jobID}[1] eq "Finished") {  # do nothing if it's already marked as finished
#         ;
#     }
#     elsif ($state eq "") {
#         ${$jobs_ref}{$jobID}[1] = "Finished";  # for jobs that were running and have finished without error
#     }
#     elsif ($state =~ /e/) {  # for jobs that error out
#         ${$jobs_ref}{$jobID}[1] = $state;
#         # placeholder - print error to log and send email?
#     }
#     else { 
#         ${$jobs_ref}{$jobID}[1] = $state; 
#     }  # if it already exists in the hash, then update the state
# }

# sub print_job_status
# {
#     my ($log, $jobs_ref, $maxRequeue) = @_;  # reference to hash of arrays, max times to requeue Eqw
#     my $finishedCount = 0;  # count all jobs that finish without error
#     my $errorCount = 0;  # count all jobs that enter an error state
#     if (%jobs) {  # once hash is populated (to avoid printing out blank headers while jobs are still getting started)
#         my $dt = DateTime->now;
#         print $log "$dt\n";
#         print $log "JobID Log State #Submissions\n";
#         foreach my $job ( sort keys %$jobs_ref ) {
#             print $log "$job @{ ${$jobs_ref}{$job} }\n";
#             if (${$jobs_ref}{$job}[1] =~ /\bFinished\b/) {
#                 $finishedCount++;
#             }
#             elsif(${$jobs_ref}{$job}[1] =~ /Eqw/ && ${$jobs_ref}{$job}[2] >= $maxRequeue) {
#                 $errorCount++;  # count Eqw the same as e (below) if it won't run after $maxRequeue tries
#             }
#             elsif(${$jobs_ref}{$job}[1] =~ /e/) {
#                 $errorCount++;  # for jobs that error out
#             }
#         }
#         print $log "\n";
#     }
#     my $totalJobs = keys %$jobs_ref;
#     return $totalJobs - ($finishedCount + $errorCount);  # this returns 0 if all jobs are either finished or in error; keeps looping otherwise
# }
