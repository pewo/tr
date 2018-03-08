#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;
use Toggl;

my($debug) = 0;
my($home) = $ENV{HOME};
$ENV{TOGGLPROJ} = "/proj/sysadm/toggl:$home/.toggl";

GetOptions (
	"debug=i"  => \$debug
) or die("Error in command line arguments\n");

print "Toggl Version: $Toggl::VERSION\n";

my($toggl) = new Toggl( debug => $debug, testmode => 0, color => 1 );

while(1) { $toggl->menu(); }
