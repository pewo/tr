#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;
use FindBin;
use lib $FindBin::Bin;
use Tr;

my($debug) = 0;

GetOptions (
	"debug=i"  => \$debug
) or die("Error in command line arguments\n");

my($tr) = new Tr( debug => $debug, testmode => 0, color => 1 );

while(1) { $tr->menu(); }
