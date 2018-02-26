package Object;

use strict;
use Carp;
use vars qw($VERSION);

$VERSION = '0.01';

sub set($$$) {
        my($self) = shift;
        my($what) = shift;
        my($value) = shift;

        $what =~ tr/a-z/A-Z/;

        $self->{ $what }=$value;
        return($value);
}

sub get($$) {
        my($self) = shift;
        my($what) = shift;

        $what =~ tr/a-z/A-Z/;
        my $value = $self->{ $what };

        return($self->{ $what });
}

sub new {
        my $proto  = shift;
        my $class  = ref($proto) || $proto;
        my $self   = {};

        bless($self,$class);

        my(%args) = @_;

        my($key,$value);
        while( ($key, $value) = each %args ) {
                $key =~ tr/a-z/A-Z/;
                $self->set($key,$value);
        }

        return($self);
}

package Toggl;

use strict;
use Carp;
use Data::Dumper;
use Storable qw(lock_store lock_retrieve);
use POSIX;

$Toggl::VERSION = '0.01';
@Toggl::ISA = qw(Object);

sub new {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $self  = {};
        bless($self,$class);

	my(%defaults) = ( weekformat => "%V", togglhome => "$ENV{HOME}/.toggl" );
        my(%hash) = ( %defaults, @_) ;
        while ( my($key,$val) = each(%hash) ) {
                $self->set($key,$val);
        }
	$self->currweek($self->week());
	if ( defined($ENV{TOGGLPROJ}) ) {
		$self->togglproj($ENV{TOGGLPROJ});
	}

	unless ( $self->togglhome() ) {
		croak "togglhome is not defined\n";
	}

	unless ( $self->togglproj() ) {
		$self->togglproj($self->togglhome());
	}

        return($self);
}

sub debug {
	my($self) = shift;
	my($level) = shift;
	my($str) = shift;
	
	my($debug) = $self->get("debug");
	return  unless ( $debug );
	return  unless ( $debug >= $level );
	chomp($str);
	print "DEBUG($level): " . localtime(time) . " $str ***\n";
}

sub _accessor {
	my($self) = shift;
	my($key) = shift;
	my($value) = shift;
	if ( defined($value) ) {
		$self->debug(9,"Setting $key to $value");
		return ($self->set($key,$value));
	}
	else {
		return ($self->get($key));
	}
}
	

sub currweek { return ( shift->_accessor("_currweek",shift) ); }
sub togglhome { return ( shift->_accessor("togglhome",shift) ); }
sub togglproj { return ( shift->_accessor("togglproj",shift) ); }

sub week {
	my($self) = shift;
	my($sec) = shift;
	$sec = time unless ( defined $sec );
	my($week) =  POSIX::strftime($self->get("weekformat"),localtime($sec));
	return ( sprintf("%02.2d",$week) );
}

sub readprojfiles {
	my($self) = shift;
	my($projdir);
	foreach $projdir ( split(/:/,$self->togglproj() ) ) {
		$self->debug(5,"projdir=$projdir");
		my($projfile);
		foreach $projfile ( <$projdir/*.proj> ) {
			$self->debug(5,"projfile=$projfile");
		}
	}
}
1;
