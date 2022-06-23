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
use REST::Client;

### INFLUXDB
my $newCheckpoints = './data/cc-metric-store/checkpoints';
my @CheckpClusters;
my $verbose = 1;
my $restClient = REST::Client->new();
$restClient->setHost('http://localhost:8087'); # Adapt port here!
$restClient->addHeader('Authorization', "Token 74008ea2a8dad5e6f856838a90c6392e"); # compare .env file
$restClient->addHeader('Content-Type', 'text/plain; charset=utf-8');
$restClient->addHeader('Accept', 'application/json');
$restClient->getUseragent()->ssl_opts(SSL_verify_mode => 0); # Temporary: Disable Cert Check
$restClient->getUseragent()->ssl_opts(verify_hostname => 0); # Temporary: Disable Cert Check

# Get clusters by cc-metric-store/$subfolder
opendir my $dhc, $newCheckpoints  or die "can't open directory: $!";
while ( readdir $dhc ) {
    chomp; next if $_ eq '.' or $_ eq '..'  or $_ eq 'job-archive';

    my $cluster = $_;
    push @CheckpClusters, $cluster;
}

# start to read checkpoints for influx
foreach my $cluster ( @CheckpClusters ) {
  print "Starting to read updated checkpoint-files into influx for $cluster\n";

	opendir my $dhLevel1, "$newCheckpoints/$cluster" or die "can't open directory: $!";
	while ( readdir $dhLevel1 ) {
		chomp; next if $_ eq '.' or $_ eq '..';
		my $level1 = $_;

		if ( -d "$newCheckpoints/$cluster/$level1" ) {
      my $nodeSource = "$newCheckpoints/$cluster/$level1/";
      my @files = read_dir($nodeSource);
      my $length = @files;
      if (!@files || $length != 14) { # needs 14 files == 7 days worth of data
        next;
      }
      my @sortedFiles = sort { versioncmp($a,$b) } @files; # sort alphanumerically: _Really_ start with index == 0 == 1609459200.json
      my $nodeMeasurement;

      foreach my $file (@sortedFiles) {
        # print "$file\n";
        my $rawstr = read_file("$nodeSource/$file");
        my $json = decode_json($rawstr);
        my $fileMeasurement;

        foreach my $metric (keys %{$json->{metrics}}) {
          my $start = $json->{metrics}->{$metric}->{start};
          my $timestep = $json->{metrics}->{$metric}->{frequency};
          my $data = $json->{metrics}->{$metric}->{data};
          my $length = @$data;
          my $measurement;

          while (my ($index, $value) = each(@$data)) {
            if ($value) {
              my $timestamp = $start + ($timestep * $index);
              $measurement .= "$metric,cluster=$cluster,hostname=$level1,type=node value=".$value." $timestamp"."\n";
            }
          }
          # Use v2 API for Influx2
          if ($measurement) {
            # print "Adding: #VALUES $length KEY $metric"."\n";
            $fileMeasurement .= $measurement;
          }
        }
        if ($fileMeasurement) {
          $nodeMeasurement .= $fileMeasurement;
        }
      }

      $restClient->POST("/api/v2/write?org=ClusterCockpit&bucket=ClusterCockpit&precision=s", "$nodeMeasurement"); # compare .env for bucket and org
      my $responseCode = $restClient->responseCode();

      if ( $responseCode eq '204') {
        if ( $verbose ) {
          print "INFLUX API WRITE: CLUSTER $cluster HOST $level1"."\n";
        };
      } else {
        if ( $responseCode ne '422' ) { # Exclude High Frequency Error 422 - Temporary!
          my $response = $restClient->responseContent();
          print "INFLUX API WRITE ERROR CODE ".$responseCode.": ".$response."\n";
        };
      };
    }
  }
}
print "Done for influx\n";
