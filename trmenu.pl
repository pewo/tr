#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;
use FindBin;
use lib $FindBin::Bin;
use Tr;

my($debug) = 0;

GetOptions (
	"d|debug=i"  => \$debug,
) or die("Error in command line arguments\n");

my($tr) = new Tr( debug => $debug, testmode => 0, color => 1 );

unless ( -t STDIN ) {	# We're either reading from a file or pipe
	my(%times) = $tr->readtimefile(); #if no argument to readtimefile, read from STDIN
	exit($tr->menu(%times));
}

while(1) { $tr->menu(); }
