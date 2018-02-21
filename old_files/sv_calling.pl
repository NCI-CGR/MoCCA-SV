#!/DCEG/Resources/Tools/perl/5.18.0/bin/perl -w
# Author: BZ

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use File::Compare;
use POSIX;
use Fcntl qw(:flock);
use Math::BigInt;
use Config;

my $max_failure = 3; # maximum number of failures allowed for the same job.
my $waiting_interval = 60; # waiting time between check_jobs tasks.
my $max_running = 300; # maximum running time allowed for the same job. only running jobs are considered with "r/s/S/T/h" status. The actually waiting time = $waiting_interval * $max_running ~ 5 hrs
my $outlog = "";
my $emailFlag = 0; #0: No error; 1: too many failure; 2: wait too long; 3: both 1 and 2.
my $usr = "";
my $domain = "";
my $resume = 0;
my $job_limit = 5000;

GetOptions(
  "log:s" => \$outlog,
  "usr:s" => \$usr,
  "domain:s" => \$domain,
  "resume" => \$resume,
  "jobs:n" => \$job_limit,
);

@ARGV == 2 or 
  die "
usage: $0 [options] bam_pair.list parameters.config

  where options are:
    -log out.log        The log file.
    -usr username       For email message.
    -domain domainname  For email message.
    -resume             Resume a previously unfinished run. Note: Any change in the command line or input files will cause problems in a resumed run.
    -jobs               Limit the number of jobs that can be submitted to the queues.

";

my ($bam_listIN, $param_fileIN) = @ARGV;
die "Error: number of jobs should be greater than zero.\n" unless ($job_limit > 0);

#==================================
# Step 1: Get the input information
#==================================

my $date = get_current_date();
my $currentusr = `whoami`;
chomp($currentusr);
my $dir = `pwd`;
chomp($dir);

my $available_jobs = $job_limit;

# Make sure the working directory is clean for a clean run.
if(! $resume) {
  die "Error: tmp_working and results folders already exist. Can't start a clean run. Use -resume option if you want to resume a previously unfinished run.\n" if((-d "tmp_working") && (-d "results"));

  die "Error: tmp_working or results folder already exists. Previous run seems not successful. Please remove/rename the folder and try again.\n" if((-d "tmp_working") || (-d "results"));

  die "Error: failed to create directory: tmp_working\n" if(!mkdir("tmp_working"));
  die "Error: failed to create directory: results\n" if(!mkdir("results"));

} else {
  die "Error: tmp_working and/or results folder(s) is missing. Can't resume a previously unfinished run.\n" if((! -d "tmp_working") || (! -d "results"));
}

# Make the local copy for input maps if they are not local.
my ($bam_list, $param_file, $total_files) = local_file($bam_listIN, $param_fileIN);  

die "Error: failed to change directory: tmp_working\n" if(!chdir("tmp_working")); 


# Output log file
if($outlog eq "") {
  $outlog = "$bam_list.log";
} else { $outlog = $outlog.".log"; }

$outlog = "../"."$outlog";

$usr ||= $currentusr;  
append_line($outlog,"$date\nUser: $currentusr\nDirectory: $dir\n",1);

# Get parameters and map info.
append_line($outlog,"Reading parameters...\n",1);

my $paramset = get_paramset($param_file);

if($resume) { # Resume mode..
  my $running_jobs = 0;
  append_line($outlog,"Clearing previous job status...\n",1);
  my $queue = (defined $paramset->{Queue})?$paramset->{Queue}:"";  #$defaultQueue;
  if(-s "svCalling.$bam_list.lookup~" || (-s "svCalling.$bam_list.lookup" && ! -e "svCalling.$bam_list.lookup~")) {
     clear_job_status("svCalling.$bam_list.lookup", $queue);
     $running_jobs = get_running_jobs("svCalling.$bam_list.lookup");
  }
  $available_jobs = $job_limit - $running_jobs;
  # $available_jobs = 0 if($available_jobs < 0); # Allow negetive available jobs in case the job limit is reduced during the resume run.
}

# get command for corresponding jobs
append_line($outlog,"Generating commandlines...\n",1);
my $cmdSVCalling = get_command($paramset);

$max_failure = $paramset->{MaxFailure} if(defined $paramset->{MaxFailure});
$max_running = $paramset->{MaxRunning} if(defined $paramset->{MaxRunning});
$waiting_interval = $paramset->{WaitInterval} if(defined $paramset->{WaitInterval});

#=============================================
# Step 2: Submit cluster jobs and check status
#=============================================

append_line($outlog,"Starting SV calling ...\n",1);

# job submission
submit_SVCalling($paramset, $bam_list, "svCalling.$bam_list.lookup", $cmdSVCalling, $total_files) if(! -e "svCalling.$bam_list.lookup");

# check jobs
append_line($outlog,"Checking SVCalling jobs...\n",1);
while(check_jobs("svCalling.$bam_list.lookup", $max_failure, $max_running, "$paramset->{BinSVCalling}")) { # Customize for different SV command. 
     sleep $waiting_interval;
}

$date = get_current_date();
append_line($outlog,"SVcalling jobs finished.\n$date\n",1);

my $total_output = `ls *.vcf | wc -l`;
chomp($total_output);
$total_output = $total_output/8;
print "Total number of file pairs processed: $total_output\n";

die "Error: total number of output files $total_output doesn't match total number of input files $total_files.\n" if($total_output != $total_files);

generate_output($paramset->{BinSVCalling});

die "Error: failed to change directory: ../ But this is the last step, all of your resutls are good to go. No worries.\n" if(!chdir("../"));


#==================================
# Sub functions
#==================================

sub generate_output
{
  my ($out_flag) = @_;
  if($out_flag eq "snowman") {
    if(! -d "../results/snowman_somatic/" && ! -d "../results/snowman_somatic/") {
      die "Error: failed to create directory: ../results/snowman_somatic/, please go to tmp_working folder to check your results.\n" if(!mkdir("../results/snowman_somatic/")); 
      die "Error: failed to create directory: ../results/snowman_germline/, please go to tmp_working folder to check your results.\n" if(!mkdir("../results/snowman_germline/"));
      system("cp *.germline*.vcf ../results/snowman_germline/") == 0  
          or die "Error: copy *.germline*.vcf failed. Please go to tmp_working folder to check your results.\n";
      system("cp *.somatic*.vcf ../results/snowman_somatic/") == 0  
          or die "Error: copy *.somatic*.vcf failed. Please go to tmp_working folder to check your results.\n";      
      append_line($outlog,"See results/ for output.\n",1);
    } else {
       my $time_stamp = `date +%Y.%m.%d.%H.%M.%S`;
       if($?) {  
         append_line($outlog,"Warning: $bam_list.all.output already exists under results/. File is not copied. Please go to tmp_working folder to check your results.\n",1);
       } else {
         chomp($time_stamp);
         die "Error: failed to create directory: ../results/snowman_somatic/, please go to tmp_working folder to check your results.\n" if(!mkdir("../results/snowman_somatic.$time_stamp/")); 
         die "Error: failed to create directory: ../results/snowman_germline/, please go to tmp_working folder to check your results.\n" if(!mkdir("../results/snowman_germline.$time_stamp/"));
         system("cp *.germline*.vcf ../results/snowman_germline.$time_stamp/") == 0  
             or die "Error: copy *.germline*.vcf failed. Please go to tmp_working folder to check your results.\n";
         system("cp *.somatic*.vcf ../results/snowman_somatic.$time_stamp/") == 0  
             or die "Error: copy *.somatic*.vcf failed. Please go to tmp_working folder to check your results.\n";           
         append_line($outlog,"Warning: files already exist under results/. See results/*.$time_stamp/\n",1);
       }  
    }
  } else {;} # Reserved for other SV caller
}


sub get_current_date
{
  my $current_dt = `date`;
  chomp($current_dt);
  return $current_dt;
}


sub get_running_jobs
{
  my ($job_lookup) = @_;
  my $running_jobs = 0;
 
  open(my $log, '<', $job_lookup) or die "Cannot open $job_lookup: $!";
  while (<$log>) {
     chomp; 
     my @jobStats = split(/\:\:/, $_);

     if($jobStats[0] !~ /^\d+$/ || $jobStats[2] eq "") {
        append_line($outlog, "Warning: unrecognized record $_, skip.\n",0);
        next;
     }   
     $running_jobs++ if($jobStats[0] > 0);
  }   
  return $running_jobs;
}


sub get_command
{
  my ($paramset) = @_;
  my $cmdSVCalling;

  die "Error: no binary directory defined.\n" if(! defined $paramset->{ExecDir});

  # get SV calling command
  if(defined $paramset->{BinSVCalling} && -x "$paramset->{ExecDir}/$paramset->{BinSVCalling}" && -s $paramset->{RefVCF}) {
    if(defined $paramset->{Param}) {
      $cmdSVCalling = "$paramset->{ExecDir}/$paramset->{BinSVCalling} $paramset->{Param} -G $paramset->{RefVCF}";
    } else {
      $cmdSVCalling = "$paramset->{ExecDir}/$paramset->{BinSVCalling} -G $paramset->{RefVCF}";
    }
  } else { die "Error: failed to generate SV calling command.\n"; } 
  return $cmdSVCalling;
}


sub clear_job_status
{
  my ($job_lookup, $queue) = @_;
  if (! -e "$job_lookup~") {
    system("cp $job_lookup $job_lookup~") == 0 
      or die "Error: failed to create the backup file $job_lookup~\n";
  }
  
  if(-e "$job_lookup") {
    system("rm $job_lookup") == 0 
      or die "Error: failed to generate new file $job_lookup\n";
  }

  open(my $fh_in, '<', "$job_lookup~") or die "Cannot read $job_lookup~: $!";  

  open(my $fh_out, '>', $job_lookup) or die "Cannot create $job_lookup: $!";

  while (<$fh_in>) {
     chomp; 
     my @jobStats = split(/\:\:/, $_);

     if($jobStats[0] !~ /^\d+$/ || $jobStats[2] eq "") {
        append_line($outlog, "Warning: unrecognized record $_.\n",0);
        print $fh_out "$_\n"; # still keep it.
        next;
     }
     if($jobStats[5] == -1) {
       print $fh_out "$jobStats[0]\:\:$jobStats[1]\:\:$jobStats[2]\:\:$queue\:\:0\:\:-1\:\:0\n";
     } else {
       print $fh_out "$jobStats[0]\:\:$jobStats[1]\:\:$jobStats[2]\:\:$queue\:\:0\:\:0\:\:0\n";
     }
  }
  
  close $fh_out;
  close $fh_in;

  my $fh_in_count = `cat $job_lookup~ | wc -l`;
  my $fh_out_count = `cat $job_lookup | wc -l`;

  if($fh_in_count == $fh_out_count && $fh_in_count > 0) {
    system("rm $job_lookup~") == 0 
      or die "Error: failed to remove the backup file $job_lookup~\n";     
  } else { die "Error: clear job status failed or the file is empty.\n"; }  
  
}

sub check_jobs
{
  my ($job_lookup, $max_failure, $max_running, $job_flag) = @_;
  my $appendlines = "";

  # $available_jobs = 0 if($available_jobs < 0);
  
  if (! -e "$job_lookup~") {
    system("cp $job_lookup $job_lookup~") == 0 
      or die "Error: failed to create the backup file $job_lookup~\n";
  } else {
    system("cp -f $job_lookup~ $job_lookup") == 0 
      or die "Error: failed to restore the backup file $job_lookup~\n";
  }

  open(my $log, '+<', $job_lookup) or die "Cannot open $job_lookup: $!";
  flock($log, LOCK_EX) or die "Error: lock $job_lookup failed.\n";
  my $write_pos = 0;
  while (<$log>) {
     chomp; 
     my @jobStats = split(/\:\:/, $_);

     if($jobStats[0] !~ /^\d+$/ || $jobStats[2] eq "") {
        append_line($outlog, "Warning: unrecognized record $_, skip.\n",0);
        next;
     }
     
     if($jobStats[5] > $max_failure && $emailFlag != 1 && $emailFlag != 3) {
       my $message = ""; 
       if($jobStats[0] > 0) {
         $message = "Error: job $jobStats[2] exceeds the maximum number of failures allowed.\nCheck the following files under tmp_working folder for more details:\n$jobStats[1].e$jobStats[0]\n$jobStats[1].o$jobStats[0]\n$jobStats[1].log\n"; 
       } else {
         $message = "Error: job $jobStats[2] exceeds the maximum number of failures allowed.\nJob can not be submitted to the queue.\n";
       }

       if($domain ne "") {
         my $to = "$usr\@"."$domain"; 
         my $from = ""; # default sender.
         my $subject = "Error on the running pipeline";
         sendEmail($to, $from, $subject, $message);
       }  
       if($emailFlag == 0) {$emailFlag = 1;} else {$emailFlag = 3;}
       append_line($outlog, $message,1);
       die "$message";
     } 

     if($jobStats[4] > $max_running && $emailFlag != 2 && $emailFlag != 3) {
       my $message = "Warning: job $jobStats[2] exceeds the maximum running time allowed.\n";
       if($domain ne "") {
         my $to = "$usr\@"."$domain"; 
         my $from = ""; # default sender.
         my $subject = "Warning on the running pipeline";
         sendEmail($to, $from, $subject, $message);
       }
       if($emailFlag == 0) {$emailFlag = 2;} else {$emailFlag = 3;} 
       append_line($outlog, $message,1);
     } 

     if($jobStats[0] == 0) { # initial un-submitted jobs or previous failed submission, resubmit. 
       
       if ($available_jobs > 0) {
         $jobStats[5]++;
         if($jobStats[5] > $max_failure) {
           $appendlines = $appendlines."$jobStats[0]\:\:$jobStats[1]\:\:$jobStats[2]\:\:$jobStats[3]\:\:$jobStats[4]\:\:$jobStats[5]\:\:$jobStats[6]\n";
         } else {
           my ($jobID, $outputName) = job_submitter($jobStats[2], $jobStats[3], $jobStats[1]);
           $jobStats[4] = 0;
           $appendlines = $appendlines."$jobID\:\:$jobStats[1]\:\:$jobStats[2]\:\:$jobStats[3]\:\:$jobStats[4]\:\:$jobStats[5]\:\:$jobStats[6]\n";
           append_line($outlog, "Warning: failed submission $jobStats[1]. Errors: $jobStats[5]. Job re-submitted.\n",1) if($jobStats[5] >=1);
           $available_jobs-- if($jobID > 0);
         }
       } else { # Keep jobs if the limit is reached.
         my $read_pos = tell $log;
         seek $log, $write_pos, 0;
         print $log "$_\n";
         $write_pos = tell $log;
         seek $log, $read_pos, 0;
       }
       next;
     
     }
     my $jobCmd = "qstat | sed \'s/^ *//\' | grep \"^$jobStats[0] \" | awk -F\" +\" \'{print \$5}\'";   # Need to exclude Eqw, dr jobs.
     my $jobCmdRt = `$jobCmd`;  # Check system failure.
     if($?) { $jobCmdRt = "Error"; } else { chomp($jobCmdRt); }
     
     if($jobCmdRt eq "r" || $jobCmdRt eq "s" || $jobCmdRt eq "S" || $jobCmdRt eq "T" || $jobCmdRt eq "h") {
       $jobStats[4]++; 
       $appendlines = $appendlines."$jobStats[0]\:\:$jobStats[1]\:\:$jobStats[2]\:\:$jobStats[3]\:\:$jobStats[4]\:\:$jobStats[5]\:\:$jobStats[6]\n";
       next;
     } elsif($jobCmdRt eq "dr" || $jobCmdRt eq "Eqw" || $jobCmdRt eq "E") {
       $jobStats[5]++;
       if($jobStats[5] > $max_failure) {
         $appendlines = $appendlines."$jobStats[0]\:\:$jobStats[1]\:\:$jobStats[2]\:\:$jobStats[3]\:\:$jobStats[4]\:\:$jobStats[5]\:\:$jobStats[6]\n";
         $available_jobs++;
       } else {
         my ($jobID, $outputName) = job_submitter($jobStats[2], $jobStats[3], $jobStats[1]);
         $jobStats[4] = 0;
         $appendlines = $appendlines."$jobID\:\:$jobStats[1]\:\:$jobStats[2]\:\:$jobStats[3]\:\:$jobStats[4]\:\:$jobStats[5]\:\:$jobStats[6]\n";
         append_line($outlog, "Warning: job in the error status $jobStats[1]. Errors: $jobStats[5]. Re-submitted. Please clean the error job promptly to ensure the total number of jobs won't exceed the limit.\n",1); 
         $available_jobs++ if($jobID == 0);
       }     
       next;       
     } elsif ($jobCmdRt eq "") { # job finished in queue 
       if(! check_job_finish($jobStats[1],$job_flag,$jobStats[0])) { # check output results
         if($jobStats[6] == 1) { # job not finished. re-submit 
           $jobStats[5]++;
           if($jobStats[5] > $max_failure) {
              $appendlines = $appendlines."$jobStats[0]\:\:$jobStats[1]\:\:$jobStats[2]\:\:$jobStats[3]\:\:$jobStats[4]\:\:$jobStats[5]\:\:$jobStats[6]\n";
              $available_jobs++;
           } else {
             my ($jobID, $outputName) = job_submitter($jobStats[2], $jobStats[3], $jobStats[1]);
             $jobStats[4] = 0;
             $appendlines = $appendlines."$jobID\:\:$jobStats[1]\:\:$jobStats[2]\:\:$jobStats[3]\:\:$jobStats[4]\:\:$jobStats[5]\:\:0\n"; 
             append_line($outlog, "Warning: job failed $jobStats[1]. Errors: $jobStats[5]. Re-submitted.\n",1);
             $available_jobs++ if($jobID == 0);
           } 
         } else { # wait a little bit more in case job just finished but output file isn't there yet.
           $appendlines = $appendlines."$jobStats[0]\:\:$jobStats[1]\:\:$jobStats[2]\:\:$jobStats[3]\:\:$jobStats[4]\:\:$jobStats[5]\:\:1\n";
         }
       } else {  $available_jobs++; }  
       next;      
     } else { # $jobCmdRt =~ /^[qwdEhrRsStT]+$/ all other status, keep the record.
       append_line($outlog, "Warning: get job status failed or unrecognized job status: $jobCmdRt. Will wait.\n",1) if($jobCmdRt !~ /^[qwdEhrRsStT]+$/ || $jobCmdRt eq "Error");
       my $read_pos = tell $log;
       seek $log, $write_pos, 0;
       print $log "$_\n";
       $write_pos = tell $log;
       seek $log, $read_pos, 0;
     } 
     
  }
  truncate($log, $write_pos) or die "Error: truncate $job_lookup failed.\n";
  flock($log, LOCK_UN) or die "Error: unlock $job_lookup failed.\n";
  close $log;
  append_line($job_lookup,$appendlines,0) if($appendlines ne "");

  if (-e "$job_lookup~") {
    system("rm $job_lookup~") == 0 
      or die "Error: failed to remove the backup file $job_lookup~\n";
  } else {
    append_line($outlog, "Warning: backup file already removed.\n",1);
  }
  
  my $runningJobs = `cat $job_lookup | wc -l`;
  if($?) {
    append_line($outlog, "Warning: count remaining jobs failed. Will retry.\n",1);
    return 1;
  }
  chomp($runningJobs);
  die "Error: count $job_lookup failed.\n" if($runningJobs !~ /^\d+$/); # must be a number.
  return $runningJobs;
}


sub submit_SVCalling  
{
   my ($paramset, $bam_list, $job_lookup, $cmdSVCalling, $total_files) = @_;
   my $outputflag = 1;

   if (-e "$job_lookup.tmp") {
    system("rm $job_lookup.tmp") == 0 
      or die "Error: failed to remove the temp file $job_lookup.tmp\n";
   } 
   
   open(my $list, '<', $bam_list) or die "Error: Cannot open $bam_list: $!";
  
   my $out_index=1; 
   while(my $bam_file = <$list>) {
      chomp($bam_file);
      my @bam_pair = split(/\s+/, $bam_file);
      
      my ($baseT,$dirT,$extT) = fileparse($bam_pair[0], qr/\.[^.]*/);
      my ($baseN,$dirN,$extN) = fileparse($bam_pair[1], qr/\.[^.]*/);
      my $output = "sv_$out_index.$baseT.$baseN"; 
      my $cmdSV = "$cmdSVCalling -t $bam_pair[0] -n $bam_pair[1] -a $output";
      my $queue = (defined $paramset->{Queue})?$paramset->{Queue}:"";
      append_line($outlog,"$cmdSV\n",0) if($outputflag < 5); 
      append_line($outlog,"$cmdSV\n....\n",0) if($outputflag == 5); # print out upto 5 commandlines   
      $outputflag++;         
       
      # job lookup table format: jobID::jobName::command::queue::waiting::error::finishflag
      append_line("$job_lookup.tmp","0\:\:$output\:\:$cmdSV\:\:$queue\:\:0\:\:-1\:\:0\n",0);   # pseudo job submission.   
      $out_index++;
   }

   my $lineJobs = `cat $job_lookup.tmp | wc -l`;
   chomp($lineJobs);
   die "Error: number of submitted jobs doesn't match $job_lookup.tmp" if($lineJobs != $total_files); # verify all the jobs are recorded.
   die "Error: failed to generate $job_lookup file.\n" if(system("mv $job_lookup.tmp $job_lookup") != 0);
   append_line($outlog,"Total $lineJobs SV calling jobs submitted.\n",1);
}


# Check .e, .o and other files to verify the finish of the job
sub check_job_finish
{
  my ($basename,$job_flag,$job_ID) = @_;
  if($job_flag eq "snowman") {
    if(-s "$basename.snowman.germline.indel.vcf" && -s "$basename.snowman.germline.sv.vcf" && -s "$basename.snowman.somatic.indel.vcf" && -s "$basename.snowman.somatic.sv.vcf" && -s "$basename.snowman.unfiltered.germline.indel.vcf" && -s "$basename.snowman.unfiltered.germline.sv.vcf" && -s "$basename.snowman.unfiltered.somatic.indel.vcf" && -s "$basename.snowman.unfiltered.somatic.sv.vcf" && -s "$basename.e$job_ID" && -s "$basename.o$job_ID") {
      my $file_stats = `tail -1 $basename.e$job_ID`;
      chomp($file_stats);
      return 1 if($file_stats eq "Done with snowman");    
    }
    return 0;
  } else { ;} #Reserved for other SV calling.
}


sub sendEmail
{
  my ($to, $from, $subject, $message) = @_;
  my $sendmail = '/usr/lib/sendmail';
  if(open(my $email, "|$sendmail -oi -t")) {
    print $email "From: $from\n";
    print $email "To: $to\n";
    print $email "Subject: $subject\n\n";
    print $email "$message\n";
    close $email;
  } else { append_line($outlog, "Warning: sending email failed.\n",1); }
} 


sub job_submitter
{
  my ($cmd, $queue, $jobName) = @_;
  my $dir = `pwd`;
  chomp($dir);
  die "Error: unrecognized directory.\n" if($dir !~ /^\//);
  my $jobCmd ="";
  if ($queue ne "") {
    $jobCmd = "echo \"cd $dir\necho cd $dir\nhostname\necho $cmd\n$cmd\"  | qsub -wd $dir -q $queue -N $jobName";
  } else {
    $jobCmd = "echo \"cd $dir\necho cd $dir\nhostname\necho $cmd\n$cmd\"  | qsub -wd $dir -N $jobName";
  }
  my $output =`$jobCmd`;
  chomp($output);
  if($output =~ /^Your\s+job\s+(\d+)\s+\(\"(\S+)\"\)\s+has\s+been\s+submitted$/) {
    return ($1,$2);
  } else { return (0,0); }
}


# Make local copy
sub local_file
{
  my ($bam_list, $param_file) = @_;

  die "Error: missing input file(s).\n" if(! -e $bam_list || ! -e $param_file);

  my ($param_base,$param_dir,$param_ext) = fileparse($param_file, qr/\.[^.]*/);
  my $param_local = $param_base.$param_ext;
  if (! -e "tmp_working/$param_local") {
    system("cp $param_file tmp_working/$param_local") == 0 
      or die "Error: failed to copy config file $param_file to tmp_working folder.\n";
  } else {
      die "Error: the local copy is different from the original input param file.\n" if (compare($param_file, "tmp_working/$param_local") != 0);
  }

  my ($bam_base,$bam_dir,$bam_ext) = fileparse($bam_list, qr/\.[^.]*/);
  my $bam_local = $bam_base.$bam_ext;
  if (! -e "tmp_working/$bam_local") {
    system("cp $bam_list tmp_working/$bam_local") == 0 
      or die "Error: failed to copy input file $bam_list to tmp_working folder.\n";
  } else {
      die "Error: the local copy is different from the original input optical mapset.\n" if (compare($bam_list, "tmp_working/$bam_local") != 0);
  }

  open(my $list, '<', $bam_list) or die "Error: Cannot open $bam_list: $!";  # check bam list.
  
#  Verify input bam pairs.
  my $line_num = 0;
  while(my $file = <$list>) {
      chomp($file);
      my @bam_pair = split(/\s+/, $file);
      my $bamT = $bam_pair[0];
      my $bamN = $bam_pair[1];
      die "Error: Either one or both bam pairs missing.\n" if(! -s $bamT || ! -s $bamN);
      die "Error: Identical tumor/normal bam files identified. Please verify your input.\n" if(compare($bamT, $bamN) == 0);
      
      my ($bamT_base,$bamT_dir,$bamT_ext) = fileparse($bamT, qr/\.[^.]*/);  
      if(! -s "$bamT.bai" && ! -s "$bamT_dir$bamT_base.bai") { # Check required input files
        die "Error: Missing index file $bamT.bai.\n";
      } 
      my ($bamN_base,$bamN_dir,$bamN_ext) = fileparse($bamN, qr/\.[^.]*/);  
      if(! -s "$bamN.bai" && ! -s "$bamN_dir$bamN_base.bai") { # Check required input files
        die "Error: Missing index file $bamN.bai.\n";
      }      
      $line_num++;    
  }
#  die "Error: Missing input files.\n" if($error_flag);

  return ($bam_local, $param_local, $line_num); 
}


sub append_line
{
  my ($param_file,$appendline,$check) = @_;
  return 0 if($check && check_duplicated_lines($param_file,$appendline)); # do not output same message more than twice if $check switch is used.

  open(my $fh, '>>', $param_file) or die "Can't open $param_file to write: $!\n";
  print $fh "$appendline";
  close $fh;
}

sub check_duplicated_lines
{
  my ($param_file,$appendline) = @_;
  return 0 if(! -e $param_file);
  my $lastline = `tail -1 $param_file`;
  my $nexttolast = `tail -2 $param_file | head -1`;
  chomp($appendline);
  chomp($lastline);
  chomp($nexttolast);
  if($appendline eq $lastline && $lastline eq $nexttolast) {
    return 1;
  } else { return 0; }   
}


# Get the whole set of parameters for all jobs
sub get_paramset
{
  my ($param_file) = @_;
  my %paramset = ();
  my $bin_param = "";
  open(my $fh, '<', $param_file) or die "Can't read $param_file: $!\n";
  while(<$fh>) {
    chomp;
    if(/^set\s+Param\s*=(.*);/) { # Special case for command line parameters
       $bin_param = $1;
       $bin_param =~ s/^\s+|\s+$//g; # Removing flanking whitespaces 
       if(! defined $paramset{"Param"}) {
         $paramset{"Param"} = $bin_param;
       } else {
         die "Error: the parameter Param was set more than once.\n"
       }       
    } elsif(/^set\s+([A-Za-z]+[0-9_A-Za-z]*)\s*=\s*([0-9_A-Za-z\/\.\-]+)\s*;/){ # Only allow certain characters.
       if(! defined $paramset{$1}) {
         $paramset{$1} = $2;
       } else {
         die "Error: the parameter $1 was set more than once.\n"
       }
    } else {
       append_line($outlog, "Warning: unrecognized parameter line $_.\n",1);
    } 
  }
  close  $fh;
  return \%paramset;
}





