#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use File::Path qw( make_path rmtree );
use Cpanel::JSON::XS qw( decode_json encode_json );
use File::Slurp;
use Data::Dumper;
use Time::Piece;
use Sort::Versions;

### JOB-ARCHIVE
my $localtime = localtime;
my $epochtime = $localtime->epoch;
my $targetDir = './cc-backend/var/job-archive';
my @Clusters;
my $src = './data/job-archive';

# Get clusters by folder
opendir my $dh, $src  or die "can't open directory: $!";
while ( readdir $dh ) {
    chomp; next if $_ eq '.' or $_ eq '..'  or $_ eq 'job-archive';

    my $cluster = $_;
    push @Clusters, $cluster;
}

# start for jobarchive
foreach my $cluster ( @Clusters ) {
  print "Starting to update startTime in job-archive for $cluster\n";

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

        # NOTE Start meta.json iteration here
        # my $random_number = int(rand(UPPERLIMIT)) + LOWERLIMIT;
        # Set new startTime: Between 5 days and 1 day before now

				#  Remove id from attributes
				$json->{startTime} = $epochtime - (int(rand(432000)) + 86400);
				$json->{stopTime} = $json->{startTime} + $json->{duration};

				$target .= $json->{startTime};

				if ( not -d $target ){
          # print "Writing files\n";

					# print "$cluster/$level1/$level2\n";
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
print "Done for job-archive\n";
sleep(2);

## CHECKPOINTS
chomp(my $checkpointStart=`date --date 'TZ="Europe/Berlin" 0:00 7 days ago' +%s`);
my $halfday = 43200;
my $targetDirCheckpoints = './data/cc-metric-store_new';
my $srcCheckpoints = './data/cc-metric-store';
my @ClustersCheckpoints;

# Get clusters by folder
opendir my $dhc, $srcCheckpoints  or die "can't open directory: $!";
while ( readdir $dhc ) {
    chomp; next if $_ eq '.' or $_ eq '..'  or $_ eq 'job-archive';

    my $cluster = $_;
    push @ClustersCheckpoints, $cluster;
}

# start for checkpoints
foreach my $cluster ( @ClustersCheckpoints ) {
  print "Starting to update startTime in checkpoint-files for $cluster\n";

	opendir my $dhLevel1, "$srcCheckpoints/$cluster" or die "can't open directory: $!";
	while ( readdir $dhLevel1 ) {
		chomp; next if $_ eq '.' or $_ eq '..';
		my $level1 = $_;

		if ( -d "$srcCheckpoints/$cluster/$level1" ) {

			my $srcCheckpoints = "$srcCheckpoints/$cluster/$level1/";
			my $target = "$targetDirCheckpoints/$cluster/$level1/";
      my $oldsrc = $srcCheckpoints;
      my @files;

			if ( -e "$srcCheckpoints/1609459200.json") { # 1609459200 == First Checkpoint time in latest dump
				@files = read_dir($srcCheckpoints);
        my $length = @files;
        if (!@files || $length != 14) { # needs 14 files == 7 days worth of data
          next;
        }
			}

      if ( ! -e "$srcCheckpoints/1609459200.json") {
        # rmtree $oldsrc;
        next;
      }

      my @sortedFiles = sort { versioncmp($a,$b) } @files; # sort alphanumerically: _Really_ start with index == 0 == 1609459200.json

      while (my ($index, $file) = each(@sortedFiles)) {
        # print "$file\n";
        my $str = read_file("$srcCheckpoints/$file");
        my $json = decode_json($str);

        my $timestamp = $checkpointStart + ($index * $halfday);
        my $oldTimestamp = $json->{from};

        # print "$oldTimestamp -> $timestamp in $srcCheckpoints\n";

        $json->{from} = $timestamp;

        foreach my $metric (keys %{$json->{metrics}}) {
          $json->{metrics}->{$metric}->{start} -= $oldTimestamp;
          $json->{metrics}->{$metric}->{start} += $timestamp;
        }

        my $targetFile = "$target/$timestamp.json";
        make_path($target);
        $str = encode_json($json);
        write_file("$targetFile", $str);
      }

				# if ( not -d $target ){
        #   print "Writing files\n";
        #
				# 	print "$cluster/$level1/$level2\n";
				# 	make_path($target);
        #
      	# 	$str = encode_json($json);
				# 	write_file("$target/meta.json", $str);
        #
				# 	$str = read_file("$srcCheckpoints/data.json");
				# 	write_file("$target/data.json", $str);
        # } else {
        #   #rmtree $src;
        # }
		}
	}
}
print "Done for checkpoints\n";
