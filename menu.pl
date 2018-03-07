#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;
use Toggl;

my($debug) = 0;
GetOptions (
	"debug=i"  => \$debug
) or die("Error in command line arguments\n");

print "Toggl Version: $Toggl::VERSION\n";

my($toggl) = new Toggl( debug => $debug, testmode => 0 );

while(1) {
	#my(%time) = $toggl->readcurrtimefile();

	#my($res) = $toggl->weekreport(\%time);
	#print $res;

	#$toggl->menu(\%time);
	$toggl->menu();
}
