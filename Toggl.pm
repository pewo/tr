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

sub readfile {
	my($self) = shift;
	my($file) = shift;
	my(@content) = ();

	if ( open(IN,"<$file") ) {
		$self->debug(5,"Reading $file");
		foreach ( <IN> ) {
			chomp;
			push(@content,$_);
		}
		close(IN);
	}
	return(@content);
}	

sub trim {
	my($self) = shift;
	my($str) = shift;
	return($str) unless ( defined($str) );
	$str =~	s/#.*//;
	$str =~	s/^\s*//;
	$str =~	s/\s*$//;
	return($str);
}
	
sub readprojfile {
	my($self) = shift;
	my($file) = shift;
	my(@content) = $self->readfile($file);

	my(%proj);
	my($id) = undef;
	my($comment) = undef;
	my($line) = 0;
	my(%allproj);
	foreach ( @content ) {
		$line++;
		$self->debug(5,"line $line in $file: $_");
		my($str) = $self->trim($_);

		my($key,$value) = split(/=/,$str);
		next unless ( $key );
		next unless ( $value );
		$self->debug(9,"key=[$key], value=[$value]");
		#
		# id=100
		# enable=yes
		# comment=som text
		#
		if ( $key =~ /id/i ) {
			$id=$value;
		}
		next unless ( $id );
		$allproj{$id}{$key}=$value;
	}
	# Clear all project with enable=n
	foreach $id ( sort keys %allproj ) {
		my($enable) = $allproj{$id}{enable};
		if ( $enable ) {
			next if ( $enable =~ /^n/i );
		}
		my($comment) = $allproj{$id}{comment};
		unless ( $comment ) {
			$comment = "project id $id";
		}
		$proj{$id}=$comment;
	}
	return(%proj);
}
	

sub readprojfiles {
	my($self) = shift;
	my($projdir);
	my($projects) = 0;
	my(%proj);
	foreach $projdir ( split(/:/,$self->togglproj() ) ) {
		$self->debug(5,"projdir=$projdir");
		my($projfile);
		foreach $projfile ( <$projdir/*.proj> ) {
			$self->debug(5,"projfile=$projfile");
			my(%projfile) = $self->readprojfile($projfile);
			foreach ( keys %projfile ) {
				$proj{$_}=$projfile{$_};
				$projects++;
			}
		}
	}
	unless ( $projects ) {
		die "No projects, exiting...\n";
	}
	return(%proj);
}
1;
