#!/DCEG/Resources/Tools/perl/5.18.0/bin/perl -w

use strict;
use warnings;
use POSIX qw(strftime);
use Capture::Tiny ':all';
use List::MoreUtils qw(uniq);
use YAML::Tiny;
use Array::Diff;

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

# Check that required directories exist
my $execDir = check_dir($yaml->[0]->{execDir}); 

my $latency = $yaml->[0]->{latency};
chomp($latency);
die "ERROR: Latency must be a positive integer.\n" if ($latency !~ /^[0-9]+$/);

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
    die "ERROR: Unrecognized analysis mode.\n" if ($anMode !~ /TN|TO|de_novo|germline/)
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
    # Check that required files and directories  exist    
    die "ERROR: $inFile is not readable or contains no data.\n" if (! -r $inFile || ! -s $inFile);
    die "ERROR: $refGenome does not exist.\n" if (! -e $refGenome);
    my $inDir = check_dir($yaml->[0]->{inDir});

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
    my @line = split(' ', $firstLine);
    @line = @line[1..$#line];
    my $diff = Array::Diff->diff(\@line, \@callers);
    die "ERROR: Headers from $annFile do not match callers listed in config file.\n" if ($diff->count);
}


print "$config passes all checks.\n";


#####################################################################################################
############################################ Subroutines ############################################
#####################################################################################################

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

