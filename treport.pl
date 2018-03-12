#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;
use FindBin;
use Tr;
use lib $FindBin::Bin;

my($date);
my($debug) = 0;
GetOptions (
	"date=s" => \$date,
	"debug=i"  => \$debug
) or die("Error in command line arguments\n");

#print "Tr Version: $Tr::VERSION\n";

my($tr) = new Tr( debug => $debug , color => 1);
print $tr->formatcurrweekreport();
#print $tr->formatcurrweekreport("csv","#");
#print $tr->formatcurrweekreport("html");

#$tr->reportmenu();
