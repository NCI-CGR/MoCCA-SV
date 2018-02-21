#!/DCEG/Resources/Tools/perl/5.18.0/bin/perl -w

# Authors:
    # BB
    # BZ

# Summary:

# Notes:
    # Add email capability?
    # add unlocking capability?
    # breakdancer histos now go to outdir; good enough?  move within snakefile?
    # cluster logs for submit.sh jobs go to home dir - can't make -o work
    # think about additional qsub statuses - see bin's script for examples of how to categorize
    # add reference indexing capability to all callers, depending on what indices are needed for each (see svaba_TN for an example) - svaba_TN, manta_TN, meerkat_TN done; delly has unclear reqs and breakdancer seems to need no ref
    # add a check to ensure there's a slash at the end of all paths provided in the config file
    # DONE figure out a better way to handle pyfow jobs with manta ** author suggested running in local over a single node - look into this
    # pyflow tasks always go to default queue (all.q) - 4h limit - change?
    # DONE Snakefile and SV_wrapper logs currently overwrite when resuming a run - change this

# to run:
    # module load perl sge
    # perl SV_wrapper.pl /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/snake_tests/config.yaml

# if directories get locked, go to locked directory and run:
    # module load python3
    # conf=/DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/snake_tests/config.yaml snakemake -s /DCEG/CGF/Bioinformatics/Production/Bari/Struct_var_pipeline_dev/pipeline/modules/Snakefile_manta_TN --unlock

# sporadic error when running all four callers:
    # Traceback (most recent call last):
    #   File "/DCEG/Resources/Tools/python3/3.5.1-shared/lib/python3.5/site-packages/snakemake/__init__.py", line 386, in snakemake
    #     no_hooks=no_hooks)
    #   File "/DCEG/Resources/Tools/python3/3.5.1-shared/lib/python3.5/site-packages/snakemake/workflow.py", line 415, in execute
    #     self.persistence.cleanup_shadow()
    #   File "/DCEG/Resources/Tools/python3/3.5.1-shared/lib/python3.5/site-packages/snakemake/persistence.py", line 118, in cleanup_shadow
    #     shutil.rmtree(self.shadow_path)
    #   File "/DCEG/Resources/Tools/python3/3.5.1-shared/lib/python3.5/shutil.py", line 484, in rmtree
    #     onerror(os.path.islink, path, sys.exc_info())
    #   File "/DCEG/Resources/Tools/python3/3.5.1-shared/lib/python3.5/shutil.py", line 482, in rmtree
    #     raise OSError("Cannot call rmtree on a symbolic link")
    # OSError: Cannot call rmtree on a symbolic link

    # check with mia/eric if they've seen this before

use strict;
use warnings;
use DateTime;
use POSIX qw(strftime);
use constant DATETIME => strftime("%Y%m%d_%H%M%S", localtime);
use Capture::Tiny ':all';
use List::MoreUtils qw(uniq);
#use Getopt::Long;
use YAML::Tiny;
# use Data::Dumper;  # used for debugging only

# my $usr = "";
# my $domain = "";

# GetOptions(
#   "usr:s" => \$usr,
#   "domain:s" => \$domain,
# );

@ARGV == 1 or die "
usage: $0 [options] full/path/config.yaml
";
#   where options are:
#       -usr <username>         For email messages.
#       -domain <domainname>    For email messages.
# ";

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

# Make directory for output and logs
my $outDir = make_dir($yaml->[0]->{outDir}); 
my $logDir = make_dir($yaml->[0]->{logDir});

# Make log file for output from this wrapper
open(my $log, '>', $logDir."SV_wrapper.log.".DATETIME) or die "ERROR: Could not write to ".$logDir.".SV_wrapper.log.".DATETIME."\n";

# Make an error handler to print any die error messages to the SV_wrapper.log file
local $SIG{__DIE__} = sub {
    my ($message) = @_;
    print $log $message;
};

# Check that required directories exist
my $execDir = check_dir($yaml->[0]->{execDir});
my $inDir = check_dir($yaml->[0]->{inDir});

# Check that required files exist
my $inFile = $yaml->[0]->{inFile};
die "ERROR: $inFile is not readable or contains no data.\n" if (! -r $inFile || ! -s $inFile);
my $refGenome = $yaml->[0]->{refGenome};
die "ERROR: $refGenome does not exist.\n" if (! -e $refGenome);

# Check that the samples file has the correct # of columns
my $mode = $yaml->[0]->{analysisMode};
chomp($mode);
check_samples_file($mode, $inFile);

# Get queue/workflow parameters from config file and check them
my $queue = $yaml->[0]->{queue};
chomp($queue);
die "ERROR: Unrecognized queue.\n" if ($queue !~ /^[x]{0,2}long\.q$|^all\.q$|^research\.q$|^seq-alignment\.q$|^seq-calling[2]*\.q$|^seq-gvcf\.q$/);
my $threads = $yaml->[0]->{maxThreads};
chomp($threads);
die "ERROR: Threads must be a positive integer.\n" if ($threads !~ /^[1-9]+[0-9]*$/);
my $numJobs = $yaml->[0]->{maxNumJobs};
chomp($numJobs);
die "ERROR: Number of jobs must be a positive integer.\n" if ($numJobs !~ /^[1-9]+[0-9]*$/);
my $checkInterval = $yaml->[0]->{checkInterval};
chomp($checkInterval);
die "ERROR: Check interval must be a positive integer.\n" if ($checkInterval !~ /^[1-9]+[0-9]*$/);
my $maxWaitChecks = $yaml->[0]->{maxWaitChecks};
chomp($maxWaitChecks);
die "ERROR: Max checks to wait for snakejob submission must be a positive integer.\n" if ($maxWaitChecks !~ /^[1-9]+[0-9]*$/);
my $maxRequeue = $yaml->[0]->{maxRequeue};
chomp($maxRequeue);
die "ERROR: Max times to requeue jobs must be a positive integer.\n" if ($maxRequeue !~ /^[1-9]+[0-9]*$/);
my $chr = $yaml->[0]->{chrPrefix};  # currently only for annotation - would like to check ref genome and/or representative bam against this to ensure a match
chomp($chr);
die "ERROR: Chromosome prefix can only be \"chr\" or \"\".\n" if ($chr ne "chr" && $chr ne "");
# Pull the caller names into an array so this can be easily expanded if new callers are added
my @callers;
for (@{$yaml->[0]->{callers}}) { 
    push @callers, $_;
}
die "ERROR: No structural variant callers were selected.\n" if (! @callers);

my $annotation = $yaml->[0]->{addAnnotation};
chomp($annotation);
die "ERROR: addAnnotation must be yes/no.\n" if ($annotation !~ /yes|no/i);

# ######################## Submit jobs ########################

# # Run the appropriate workflow(s)
# my @submitJobs;  # an array with the job IDs for each of the "submit.sh" qsub jobs (one per caller) - these jobs will keep running for as long as the submitted snakefile is running

# # Iterate through items in an array of caller names, to allow for easy caller addition
# if ($mode eq "TN" || $mode eq "de_novo" || $mode eq "germline" || $mode eq "TO") {
#     foreach (@callers) {
#         print $log "Running $_ workflow in $mode mode.\n";
#         print $log "See logs/Snakefile_".$_."_".$mode.".out.".DATETIME." for details.\n";
#         push(@submitJobs, submit_workflow($log, "Snakefile\_".$_."\_".$mode, $execDir, $logDir, $threads, $queue, $numJobs, $config, DATETIME));
#         sleep 30;
#     }
# }
# else { die "ERROR: Unrecognized analysis mode.\n"; }

# ######################## Check on jobs ########################

# # Check on submitted jobs; automatically requeue Eqw a few times

# my %jobs;  # hash of arrays that contain the job ID and other relevant info that gets printed to the SV_wrapper log file
# my $checkJobsFlag = 0;

# # initial check if the submit.sh jobs are running
# foreach (@submitJobs) {
#     if (`qstat | grep \"^$_\"` ne "") {
#         $checkJobsFlag++;
#     }
# }

# my $allDoneFlag = 1;  # set to 0 when all jobs are done ("done" means finished or in error)
# my $waitTime = 0;  # set a max time to wait for the first sub-job to be submitted - user sets max in config file
# while(($checkJobsFlag > 0 || $allDoneFlag != 0) && $waitTime < $maxWaitChecks) {  # while any of the submit.sh jobs are still running, or while any job IDs refer to jobs that are still running, keep looping
#     sleep $checkInterval;
#     get_snake_jobs($logDir, \%jobs, $maxRequeue);  # get the job IDs of the snakejobs from the log files

#         ###########TODO: test this.  can set shell to something non-existent (eg -S /) to make it go into Eqw.

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
# # Note - the way this is structured, it will keep looping until all callers are done.  This might be annoying if one caller is much slower than the others, for example.
# # May consider refactoring at some point to have one loop per caller used.

######################## Check on logs ########################

# check the log files for successful completion (there will be one of these logs per caller, regardless of number of samples)
my $callerSuccessCount = 0;
foreach (@callers) {
    # my $file = $logDir."Snakefile_".$_."_".$mode.".out.".DATETIME;
    my $file = $logDir."Snakefile_".$_."_".$mode.".out.20180220_161249";
    if (-r $file && -s $file) {
        open(my $fh, '<', $file) or die "ERROR: Could not open $file.\n";
        while (my $line = <$fh>) {
            chomp($line);
            if ($line =~ /100%/) {
                # print $log "$file finished successfully.\n";
                print "$file finished successfully.\n";
                $callerSuccessCount++;
                last;
            }
            elsif ($line =~ /error/i && $annotation =~ /no/i) {
                # print $log "$file contains an error.\n";
                print "$file contains an error.\n";
                last;
            }
            elsif ($line =~ /error/i && $annotation =~ /yes/i) {
                # print $log "$file contains an error.  Annotation pipeline will not be started.\n";
                print "$file contains an error.  Annotation pipeline will not be started.\n";
                last;
            }
            else { next; } 
        }
        close $fh;
    }
}

######################## Add annotation ########################

# kick off annotation pipeline if all callers have finished successfully
my $arrSize = scalar @callers;
if ($callerSuccessCount == $arrSize && $annotation =~ /yes/i) {
    foreach (@callers) {
        my $file = $execDir."/scripts/".$_."_to_bed.sh";
        die "ERROR: No executable file found for $file.\n" if (! -x $file);
    }
    print $log "Adding annotation.\n";
    print $log "See logs/Snakefile_compare_and_annotate.out.".DATETIME." for details.\n";
    my $annoJobID = submit_workflow($log, "Snakefile\_compare\_and\_annotate", $execDir, $logDir, "annotate", $queue, $numJobs, $config, DATETIME);
}
#TODO: add monitoring of the annotation snake jobs
# note that currently I get all snake job IDs from the log files.  can I make snakemake output them and grab them from that log?

close $log;

#####################################################################################################
############################################ Subroutines ############################################
#####################################################################################################

sub make_dir
{
    my $dir = shift;
    chomp($dir);
    $dir =~ s|/?$|/|;  # ensure the path has a single trailing slash
    if (! -d $dir) {
        mkdir($dir) or die "ERROR: Could not create directory at $dir.\n";
    } 
    return $dir;
}

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
    my ($mode, $inFile) = @_;
    open(my $in, '<', $inFile) or die "ERROR: Could not open $inFile.\n";
    my $firstLine = <$in>;
    chomp($firstLine);
    close $in;
    my @line = split(/ /, $firstLine);
    die "ERROR: Input bam file must have three space-separated columns for $mode mode.\n" if ($mode eq "TN" && scalar(@line) != 3);
    # die "ERROR: Input bam file must have ____ space-separated columns for $mode mode.\n" if ($mode eq "TO" && scalar(@line) != _);
    die "ERROR: Input bam file must have four space-separated columns for $mode mode.\n" if ($mode eq "de_novo" && scalar(@line) != 4);
    # die "ERROR: Input bam file must have ____ space-separated columns for $mode mode.\n" if ($mode eq "germline" && scalar(@line) != _);
}


sub submit_workflow
{
    my ($log, $snake, $execDir, $logDir, $threads, $queue, $numJobs, $config, $stamp) = @_;
    my @sub = ("qsub", $execDir."scripts/submit.sh", "modules/$snake", $queue, $execDir, $logDir, $threads, $numJobs, $config, $outDir, $stamp);
    my $stdout;
    my $stderr;
    my $exit;
    ($stdout, $stderr, $exit) = capture {
        # join array into sentence, then pass string to system
        system(@sub);  # use system here (which returns exit status and results in stdout job submission info, eg { Your job 8660745 ("submit.sh") has been submitted } ), rather than backticks (which returns nothing)
    };
    if ($exit == 0) {
        my ($jobid) = $stdout =~ /^Your job ([0-9]+)/;  # extract the job ID
        print $log "$stdout\n";
        return $jobid;
    }
    else { die "ERROR: Failed to submit job to cluster: exit code $exit\n"; }
}

# sub get_snake_jobs
# {
#     my ($logDir, $jobs_ref, $maxRequeue) = @_;  # where to read sge log files (set in config), reference to hash of arrays %jobs, max times to requeue Eqw

#     opendir(my $dh, $logDir) or die "ERROR: Can't access log directory.";
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
