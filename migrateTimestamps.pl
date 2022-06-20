#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use File::Path qw( make_path rmtree );
use String::CamelCase qw(camelize);
use Cpanel::JSON::XS qw( decode_json encode_json );
use File::Slurp;
use Data::Dumper;
use Data::Walk;
use Scalar::Util qw( reftype );
use Time::Piece;

## NOTE: Based on Jan: migrateCC-jobArchive.pl

my $FIRST=1;
my @METRICS = ('flops_any', 'cpu_load', 'mem_used', 'flops_sp',
    'flops_dp', 'mem_bw',  'cpi', 'cpi_avg', 'clock', 'rapl_power');

my %UNITS = (
    'flops_any' => 'GF/s',
    'cpu_load' => 'load',
    'mem_used' => 'GB',
    'flops_sp' => 'GF/s',
    'flops_dp' => 'GF/s',
    'mem_bw' => 'GB/s',
    'clock' => 'MHz',
    'rapl_power' => 'W'
);

sub process {
if ( $Data::Walk::type eq 'HASH' && !($Data::Walk::index%2)) {

    if ( ! $FIRST ) {
        my $key = $_;
        if ( ! grep( /^$key$/, @METRICS) ) {
            my $str = lcfirst(camelize($key));
            my $hashref = $Data::Walk::container;
            my $value = delete ${$hashref}{$key};
            ${$hashref}{$str} = $value;
        }
    }

    if ( $FIRST ) {
        $FIRST = 0;
    }
}
}

my $localtime = localtime;
my $epochtime = $localtime->epoch;
my $targetDir = './cc-backend/var/job-archive';
my @Clusters;
my $src = './data/job-archive';

chomp($checkpointStart=`date --date 'TZ="Europe/Berlin" 0:00 7 days ago' +%s`);
my $halfday = 43200;
my $targetDirCheckpoints = './data/cc-metric-store_new'
my $srcCheckpoints = './data/cc-metric-store'
my @ClustersCheckpoints

## Get Clusters
opendir my $dh, $src  or die "can't open directory: $!";

while ( readdir $dh ) {
    chomp; next if $_ eq '.' or $_ eq '..'  or $_ eq 'job-archive';

    my $cluster = $_;
    push @Clusters, $cluster;
}

opendir my $dhc, $srcCheckpoints  or die "can't open directory: $!";

while ( readdir $dhc ) {
    chomp; next if $_ eq '.' or $_ eq '..'  or $_ eq 'job-archive';

    my $cluster = $_;
    push @ClustersCheckpoints, $cluster;
}

# start for jobarchive
foreach my $cluster ( @Clusters ) {
  print "Starting to update startTime for $cluster\n";

	opendir my $dhLevel1, "$src/$cluster" or die "can't open directory: $!";
	while ( readdir $dhLevel1 ) {
		chomp; next if $_ eq '.' or $_ eq '..';
		my $level1 = $_;

		if ( -d "$src/$cluster/$level1" ) {
			opendir my $dhLevel2, "$src/$cluster/$level1" or die "can't open directory: $!";
			while ( readdir $dhLevel2 ) {
				chomp; next if $_ eq '.' or $_ eq '..';
				my $level2 = $_;
				my $src = "$src/$cluster/$level1/$level2";
				my $target = "$targetDir/$cluster/$level1/$level2/";

                my $oldsrc = $src;
				if ( ! -e "$src/meta.json") {
					my @files = read_dir($src);
                    if (!@files) {
                        next;
                    }
					$src = "$src/".$files[0];
				}

                if ( ! -e "$src/meta.json") {
                    rmtree $oldsrc;
                    next;
                }
				my $str = read_file("$src/meta.json");
				my $json = decode_json($str);
				$FIRST = 1;
				walk \&process, $json;

        # NOTE Start meta.json iteration here
        # my $random_number = int(rand(UPPERLIMIT)) + LOWERLIMIT;
        # Set new startTime: Between 5 days and 1 day before now

				#  Remove id from attributes
				$json->{startTime} = $epochtime - (int(rand(432000)) + 86400);
				$json->{stopTime} = $json->{startTime} + $json->{duration};

				$target .= $json->{startTime};

				if ( not -d $target ){
          print "Writing files\n";

					print "$cluster/$level1/$level2\n";
					make_path($target);

      		$str = encode_json($json);
					write_file("$target/meta.json", $str);

					$str = read_file("$src/data.json");
					write_file("$target/data.json", $str);
        } else {
          #rmtree $src;
        }
			}
		}
	}
}

print "Done\n";
