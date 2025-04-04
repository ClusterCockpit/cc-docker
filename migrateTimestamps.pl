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
my $archiveTarget = './cc-backend/var/job-archive';
my $archiveSrc = './data/job-archive-source';
my @ArchiveClusters;

# Get clusters by job-archive/$subfolder
# opendir my $dh, $archiveSrc  or die "can't open directory: $!";
# while ( readdir $dh ) {
#     chomp; next if $_ eq '.' or $_ eq '..'  or $_ eq 'job-archive' or $_ eq 'version.txt';

#     my $cluster = $_;
#     push @ArchiveClusters, $cluster;
# }

# # start for jobarchive
# foreach my $cluster ( @ArchiveClusters ) {
#   print "Starting to update start- and stoptimes in job-archive for $cluster\n";

# 	opendir my $dhLevel1, "$archiveSrc/$cluster" or die "can't open directory: $!";
# 	while ( readdir $dhLevel1 ) {
# 		chomp; next if $_ eq '.' or $_ eq '..';
# 		my $level1 = $_;

# 		if ( -d "$archiveSrc/$cluster/$level1" ) {
# 			opendir my $dhLevel2, "$archiveSrc/$cluster/$level1" or die "can't open directory: $!";
# 			while ( readdir $dhLevel2 ) {
# 				chomp; next if $_ eq '.' or $_ eq '..';
# 				my $level2 = $_;
# 				my $jobSource = "$archiveSrc/$cluster/$level1/$level2";
# 				my $jobTarget = "$archiveTarget/$cluster/$level1/$level2/";
#         my $jobOrigin = $jobSource;
#         # check if files are directly accessible (old format) else get subfolders as file and update path
#         if ( ! -e "$jobSource/meta.json") {
# 					my @folders = read_dir($jobSource);
#           if (!@folders) {
#             next;
#           }
#           # Only use first subfolder for now TODO
# 					$jobSource = "$jobSource/".$folders[0];
# 				}
#         # check if subfolder contains file, else remove source and skip
#         if ( ! -e "$jobSource/meta.json") {
#           # rmtree $jobOrigin;
#           next;
#         }

# 				my $rawstr = read_file("$jobSource/meta.json");
# 				my $json = decode_json($rawstr);

#         # NOTE Start meta.json iteration here
#         # my $random_number = int(rand(UPPERLIMIT)) + LOWERLIMIT;
#         # Set new startTime: Between 5 days and 1 day before now

# 				#  Remove id from attributes
# 				$json->{startTime} = $epochtime - (int(rand(432000)) + 86400);
# 				$json->{stopTime} = $json->{startTime} + $json->{duration};

#         # Add starttime subfolder to target path
# 				$jobTarget .= $json->{startTime};

#         # target is not directory
# 				if ( not -d $jobTarget ){
#           # print "Writing files\n";
# 					# print "$cluster/$level1/$level2\n";
# 					make_path($jobTarget);

#       		my $outstr = encode_json($json);
# 					write_file("$jobTarget/meta.json", $outstr);

# 					my $datstr = read_file("$jobSource/data.json.gz");
# 					write_file("$jobTarget/data.json.gz", $datstr);
#         } else {
#           # rmtree $jobSource;
#         }
# 			}
# 		}
# 	}
# }
# print "Done for job-archive\n";
# sleep(1);

## CHECKPOINTS
chomp(my $checkpointStart=`date --date 'TZ="Europe/Berlin" 0:00 7 days ago' +%s`);
my $halfday = 43200;
my $checkpTarget = './data/cc-metric-store/checkpoints';
my $checkpSource = './data/cc-metric-store-source/checkpoints';
my @CheckpClusters;

# Get clusters by cc-metric-store/$subfolder
opendir my $dhc, $checkpSource  or die "can't open directory: $!";
while ( readdir $dhc ) {
    chomp; next if $_ eq '.' or $_ eq '..'  or $_ eq 'job-archive';

    my $cluster = $_;
    push @CheckpClusters, $cluster;
}

# start for checkpoints
foreach my $cluster ( @CheckpClusters ) {
  print "Starting to update checkpoint filenames and data starttimes for $cluster\n";

	opendir my $dhLevel1, "$checkpSource/$cluster" or die "can't open directory: $!";
	while ( readdir $dhLevel1 ) {
		chomp; next if $_ eq '.' or $_ eq '..';
    # Nodename as level1-folder
		my $level1 = $_;

		if ( -d "$checkpSource/$cluster/$level1" ) {

			my $nodeSource = "$checkpSource/$cluster/$level1/";
			my $nodeTarget = "$checkpTarget/$cluster/$level1/";
      my $nodeOrigin = $nodeSource;
      my @files;

			if ( -e "$nodeSource/1609459200.json") { # 1609459200 == First Checkpoint time in latest dump
				@files = read_dir($nodeSource);
        my $length = @files;
        if (!@files || $length != 14) { # needs 14 files == 7 days worth of data
          next;
        }
			} else {
        # rmtree $nodeOrigin;
        next;
      }

      my @sortedFiles = sort { versioncmp($a,$b) } @files; # sort alphanumerically: _Really_ start with index == 0 == 1609459200.json

      if ( not -d $nodeTarget ){
        # print "processing files for $level1 \n";
        make_path($nodeTarget);

        while (my ($index, $file) = each(@sortedFiles)) {
          # print "$file\n";
          my $rawstr = read_file("$nodeSource/$file");
          my $json = decode_json($rawstr);

          my $newTimestamp = $checkpointStart + ($index * $halfday);
          # Get Diff from old Timestamp
          my $timeDiff = $newTimestamp - $json->{from};
          # Set new timestamp
          $json->{from} = $newTimestamp;

          foreach my $metric (keys %{$json->{metrics}}) {
            $json->{metrics}->{$metric}->{start} += $timeDiff;
          }

          my $outstr = encode_json($json);
          write_file("$nodeTarget/$newTimestamp.json", $outstr);
        }
      } else {
        # rmtree $nodeSource;
      }
		}
	}
}
print "Done for checkpoints\n";
