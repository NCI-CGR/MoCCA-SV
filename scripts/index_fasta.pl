#!/DCEG/Resources/Tools/perl/5.18.0/bin/perl -w

use strict;
use warnings;
use Bio::DB::Fasta;

@ARGV == 1 or die "
usage: $0 path/to/refgenome.fa[fasta]
";

my $ref = $ARGV[0];
chomp($ref);

my $db = Bio::DB::Fasta->new($ref);
