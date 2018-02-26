#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;
use Toggl;

my($start);
my($end);
my($debug) = 0;
GetOptions (
	"start=i" => \$start,
	"end=i" => \$end,
	"debug=i"  => \$debug
) or die("Error in command line arguments\n");

print "Toggl Version: $Toggl::VERSION\n";

my($toggl) = new Toggl( debug => $debug );
my($week) = $toggl->week();
my($year) = $toggl->year();

# 
# If start or end is negative, use it as relative to current week
# i.e if it is week 8 and start is -2, then start or end will be 6
#
$start = $week unless ( $start );
if ( $start < 0 ) {
	my($old) = $start;
	$start = $week + $start;
	$toggl->debug(5,"Changing start from $old to $start");
}

$end = $week unless ( $end );
if ( $end < 0 ) {
	my($old) = $end;
	$end = $week + $end;
	$toggl->debug(5,"Changing end from $old to $end");
}
if ( $start > $end ) {
	die "Start($start) week has to be less then end($end)\n";
}

#print Dumper(\$toggl);

#print "week=$week\n";
#print "year=$year\n";

#my(%proj) = $toggl->readprojfiles();
#print "Projetcs:\n";
#print Dumper(\%proj);

my(%time) = $toggl->readcurrtimefile();
#print "Timefile:\n";
#print Dumper(\%time);

my(@report) = $toggl->weekreport(\%time);
#print "Weekreport:\n";
#print Dumper(\@report);

