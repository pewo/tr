#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;
use Tr;

my($debug) = 0;
GetOptions (
	"debug=i"  => \$debug
) or die("Error in command line arguments\n");

print "Tr Version: $Tr::VERSION\n";

my($tr) = new Tr( debug => $debug , color => 1);

$tr->reportmenu();
