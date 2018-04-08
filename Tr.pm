package Object;

use strict;
use Carp;

our $VERSION = 'v0.0.1';

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


package Color;

use strict;
our @ISA = qw(Object);
our @EXPORT = qw(setcolor);

sub colorcode() {
	my($self) = shift;
	my($color) = shift;

	our(%color) = (
		black       => "0;30",
		darkgray    => "1;30",
		red         => "0;31",
		lightred    => "1;31",
		green       => "0;32",
		lightgreen  => "1;32",
		brown       => "0;33",
		orange      => "0;33",
		yellow      => "1;33",
		blue        => "0;34",
		lightblue   => "1;34",
		purple      => "0;35",
		lightpurple => "1;35",
		cyan        => "0;36",
		lightcyan   => "1;36",
		lightgray   => "0;37",
		white       => "1;37",
		nocolor     => "0",
	);
	if ( $color ) {
		if ( defined($color{$color}) ) {
			return($color{$color});
		}
	}
	else {
		return($color{"nocolor"});
	}	
	return(undef);
}

sub getcolor() {
	my($self) = shift;
	my($color) = shift;
	my($code) = $self->colorcode($color);
	$self->debug(5,"Color code is $code");
	my($str) =  "\033[" . $code . "m";
	return($str);
}

sub setcolor() {
	my($self) = shift;
	my($color) = shift;
	if ( $color ) {
		$self->debug(5,"Setting color to $color");
	}
	else {
		$self->debug(5,"Resetting color");
	}
	if ( $self->color() ) {
		print $self->getcolor($color);
	}
}

package HotKey;

#https://docstore.mik.ua/orelly/perl4/cook/ch15_09.htm

our @ISA = qw(Exporter);
our @EXPORT = qw(cbreak cooked readkey);

use strict;
use POSIX qw(:termios_h);
my ($term, $oterm, $echo, $noecho, $fd_stdin);

$fd_stdin = fileno(STDIN);
$term     = POSIX::Termios->new( );
$term->getattr($fd_stdin);
$oterm    = $term->getlflag( );

$echo     = ECHO | ECHOK | ICANON;
$noecho   = $oterm & ~$echo;

sub cbreak {
    $term->setlflag($noecho);  # ok, so i don't want echo either
    $term->setcc(VTIME, 1);
    $term->setattr($fd_stdin, TCSANOW);
}

sub cooked {
    $term->setlflag($oterm);
    $term->setcc(VTIME, 0);
    $term->setattr($fd_stdin, TCSANOW);
}

sub readkey {
    my $key = '';
    cbreak( );
    sysread(STDIN, $key, 1);
    cooked( );
    return $key;
}

END { cooked( ) }

package Tr;

use strict;
use Carp;
use Data::Dumper;
use Storable qw(lock_store lock_retrieve);
use POSIX;
use utf8;
use open ':encoding(utf8)';
binmode(STDOUT, ":utf8");


our $VERSION = 'v0.2.1';
our @ISA = qw(Object HotKey Color);
use constant RED => "red";
use constant BLUE  => "blue";
use constant GREEN => "green";
use constant LIGHTGREEN => "lightgreen";

our $line = "===============================================================================";

sub new {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $self  = {};
        bless($self,$class);

	my(%defaults) = ( 
		weekformat => "%V", 
		yearformat => "%G", 
		trhome => "$ENV{HOME}/.tr"
	);
        my(%hash) = ( %defaults, @_) ;
        while ( my($key,$val) = each(%hash) ) {
                $self->set($key,$val);
        }

	#
	# Where to save timereport files
	#
	if ( defined($ENV{TRHOME}) ) {
		$self->trhome($ENV{TRHOME});
	}

	#
	# Where is the project files located
	#
	if ( defined($ENV{TRPROJ}) ) {
		$self->trproj($ENV{TRPROJ});
	}

	#
	# Check that the trhome directory is defined
	#
	my($trhome) = $self->trhome();
	unless ( $trhome ) {
		croak "trhome is not defined\n";
	}

	my($testmode) = $self->testmode();
	if ( $testmode ) {
		$testmode =~ s/\W/_/g;
		$trhome .= "_test_" . $testmode;
		$self->trhome($trhome);
	}

	#
	# Check if the trhome directory exists
	#
	if ( ! -d $trhome ) {
		chdir($trhome);
		die "chdir($trhome): $!\n";
	}

	unless ( $self->trproj() ) {
		$self->trproj($self->trhome());
	}

	my(%projects) = $self->readprojfiles();
	$self->projects(\%projects);


	$self->resettime();

	#die Dumper(\$self);
        return($self);
}

#
# Initiate all timerelated variables and filenames
#
sub resettime() {
	my($self) = shift;

	$self->currweek($self->week());
	$self->curryear($self->year());

	my($curryeardir) = $self->trhome() . "/" . $self->curryear();
	$self->curryeardir($curryeardir);
	if ( ! -d $curryeardir ) {
		mkdir($curryeardir);
		if ( ! -d $curryeardir ) {
			die "mkdir($curryeardir): $!\n";
		}
	}
	
	my($currtimefile) = $self->setcurrtimefile();
	$self->currtimefile($currtimefile);
	$self->currtimefiletmp($currtimefile . ".tmp");
}

#
# Set the current timefile to now or specified time(Epoch)
#
sub setcurrtimefile() {
	my($self) = shift;
	my($secs) = shift;
	$secs = time unless ( defined($secs) );
	my($year) = $self->year($secs);
	my($week) = $self->week($secs);
	my($currtimefile) = $self->trhome() . "/" . $year . "/" . $week . ".tf";
	$self->currtimefile($currtimefile);
	return($currtimefile);
}

#
# Send debug message to stdout
#
sub debug {
	my($self) = shift;
	my($level) = shift;
	my($str) = shift;
	
	my($debug) = $self->get("debug");
	if ( $level > 0 ) {
		return  unless ( $debug );
		return  unless ( $debug >= $level );
	}
	chomp($str);
	print "DEBUG($level): " . localtime(time) . " $str ***\n";
}

#
# Simple accessor method to set/get values in object
#
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
	

sub testmode { return ( shift->_accessor("testmode",shift) ); }
sub color { return ( shift->_accessor("color",shift) ); }
sub currweek { return ( shift->_accessor("_currweek",shift) ); }
sub curryear { return ( shift->_accessor("_curryear",shift) ); }
sub trhome { return ( shift->_accessor("trhome",shift) ); }
sub trproj { return ( shift->_accessor("trproj",shift) ); }
sub curryeardir { return ( shift->_accessor("_curryeardir",shift) ); }
sub currtimefile { return ( shift->_accessor("_currtimefile",shift) ); }
sub currtimefiletmp { return ( shift->_accessor("_currtimefiletmp",shift) ); }
sub projects { return ( shift->_accessor("_projects",shift) ); }

sub projid {
	my($self) = shift;
	my($projid) = shift;
	my($projects) = $self->projects();
	if ( defined($projid) ) {
		return($projects->{$projid});
	}
	else {
		return(%$projects);
	}
}

sub week {
	my($self) = shift;
	my($sec) = shift;
	$sec = time unless ( defined $sec );
	my($week) =  POSIX::strftime($self->get("weekformat"),localtime($sec));
	return ( sprintf("%02.2d",$week) );
}

sub year {
	my($self) = shift;
	my($sec) = shift;
	$sec = time unless ( defined $sec );
	return ( POSIX::strftime($self->get("yearformat"),localtime($sec)) );
}

sub timestamp {
	my($self) = shift;
	my($secs) = shift;
	$secs = time unless ( $secs );
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($secs);
	my($date) = sprintf("%04.4d%02.2d%02.2d",$year+1900,$mon+1,$mday);
	my($time) = sprintf("%02.2d:%02.2d",$hour,$min);
	return($date,$time);
}


sub createcurrdir {
	my($self) = shift;
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
	

sub projfiles {
	my($self) = shift;
	my(@projfiles);
	my($projdir);
	foreach $projdir ( split(/:/,$self->trproj() ) ) {
		$self->debug(5,"projdir=$projdir");
		my($projfile);
		foreach $projfile ( <$projdir/*.proj> ) {
			$self->debug(5,"projfile=$projfile");
			push(@projfiles,$projfile);
		}
	}
	return(@projfiles);
}

sub editprojfiles() {
	my($self) = shift;
	foreach ( $self->projfiles() ) {
		$self->edit($_);
	}
}

sub readprojfiles {
	my($self) = shift;
	my($projdir);
	my($projects) = 0;
	my(%proj);
	my(@projfiles) = $self->projfiles();
	#foreach $projdir ( split(/:/,$self->trproj() ) ) {
		#$self->debug(5,"projdir=$projdir");
	my($projfile);
		#foreach $projfile ( <$projdir/*.proj> ) {
	foreach $projfile ( $self->projfiles() ) {
		$self->debug(5,"projfile=$projfile");
		my(%projfile) = $self->readprojfile($projfile);
		foreach ( keys %projfile ) {
			$proj{$_}=$projfile{$_};
			$projects++;
		}
	}
	#}
	unless ( $projects ) {
		die "No projects, exiting...\n";
	}
	return(%proj);
}

sub readtimefile {
	my($self) = shift;
	my($file) = shift;
	my(@content) = $self->readfile($file);
	my(%allinfo) = ();
	my($rec) = 0;
	foreach ( @content ) {
		my($str) = $self->trim($_);
		my($key,$value) = split(/=/,$str);
		next unless ( $key );
		next unless ( $value );
		if ( $key =~ /date/ ) {
			$rec++;
		}
		elsif ( $key =~ /proj/ ) {
			($value) = split(/\s+/,$value);
		}
		next unless ( $rec );
		$allinfo{$rec}{$key}=$value;
	}
	return(%allinfo);
}
		
sub readcurrtimefile {
	my($self) = shift;
	return( $self->readtimefile($self->currtimefile()) );
}

sub convtime2sec {
	my($self) = shift;
	my($time) = shift;
	my($hour,$min) = split(/:/,$time);
	my($sec) = $hour * 3600 + $min * 60;
	$self->debug(9,"Converted $time to hour=$hour, min=$min to sec=$sec");
	return($sec);
}

sub convtime2dursec {
	my($self) = shift;
	my($start) = shift;
	my($end) = shift;

	my($startsec) = $self->convtime2sec($start);
	my($endsec) = $self->convtime2sec($end);

	my($dursec) = $endsec - $startsec;
	$self->debug(9,"Duration $dursec sec");
	return($dursec);
}

	
sub startend2hour {
	my($self) = shift;
	my($start) = shift;
	my($end) = shift;

	my($dursec) = $self->convtime2dursec($start,$end);
	my($durhour) = int($dursec / 3600);
	my($durmin) = ($dursec - ( $durhour * 3600 )) / 60;
	my($durhourpart) = int(100 * $durmin / 60) / 100;
	my($res) = $durhour + $durhourpart;
	#print "start=$start end=$end dursec=$dursec durhour=$durhour durmin=$durmin ($durhourpart) res=[$res]\n";
	return($res);
}

sub convdursec2hour {
	my($self) = shift;
	my($dursec) = shift;

	my($durhour) = int($dursec / 3600);
	my($durmin) = ($dursec - ( $durhour * 3600 )) / 60;
	my($durhourpart) = int(100 * $durmin / 60) / 100;
	my($res) = $durhour + $durhourpart;
	#print "dursec=$dursec durhour=$durhour durmin=$durmin ($durhourpart) res=[$res]\n";
	return($res);
}

sub dates {
	my($self) = shift;
	my($hashp) = shift;
	
	my($first) = undef;
	my($last) = undef;

	my(%date);
	foreach ( sort keys %$hashp ) {
		my($date) = $hashp->{$_}{"date"};
		$date{$date}++;
	}
	return(sort keys %date);
}

sub rawtimereport {
	my($self) = shift;
	my($hashp) = shift;
	my(%times) = %$hashp;
	
	#
	# Return 3 arrays
	# 1: @header
	# 2: @body
	# 3: @tailer
	#

	my(@dates) = $self->dates($hashp);

	#print $self->timereport(\%times);

	my(%proj);
	while ( my($key,$value) = each(%times) ) {
		my($date) = $value->{"date"};
		my($start) = $value->{"start"};
		my($end) = $value->{"end"};
		my($proj) = $value->{"proj"};
		$self->debug(9,"proj=$proj, start=$start, end=$end");
		
		my($dursec) = $self->convtime2dursec($start,$end);
		$proj{$proj}{$date} += $dursec;
	}

	my($proj);
	my($html);
	my(%res);
	my($header) = "";
	my(@header) = ();
	my(@tailer) = ();
	my(@body);
	my(%projsum);
	my(%datesum);
	my($allsum) = 0;
	push(@header,"Project/Date");
	my($date);
	foreach $date ( @dates ) {
		push(@header,$date);
	}
	foreach $proj ( sort keys %proj ) {
		my($projname) = $self->projid($proj);
		my(@line) = ();
		push(@line,$proj . " " . $projname);

		my($date);
		foreach $date ( @dates ) {
			my($dursec) = $proj{$proj}{$date};
			$dursec = 0 unless ( $dursec );
			$allsum += $dursec;
			$datesum{$date}+=$dursec;
			$projsum{$proj}+=$dursec;
			$dursec = 0 unless ( $dursec );
			my($hour) = $self->convdursec2hour($dursec);
			push(@line,$hour);
		}
		push(@line,$self->convdursec2hour($projsum{$proj}));
		push(@body,\@line);
	}
	push(@header,"Total");
	push(@tailer,"Totals");
	foreach ( @dates ) {
		push(@tailer,$self->convdursec2hour($datesum{$_}));
	}
	push(@tailer,$self->convdursec2hour($allsum));
		
	return(\@header,\@body,\@tailer);
}

sub zerofilltime {
	my($self) = shift;
	my($time) = shift;
	my($hour,$min) = split(/:/,$time);
	return( sprintf("%02.2d.%02.2d",$hour,$min) );
}

#
# Print a list of projects and make the user select one
#
sub filterproj {
	my($self) = shift;
	
	my(%projnames) = $self->projid();
	my($projid) = undef;
	my(@filter) = ();
	my($filterstr) = "";
	while( 1 ) {
		print "\n" . $line . "\n";
		my($found) = 0;
		foreach ( sort keys %projnames ) {
			my($include) = 0;
			if ( length($filterstr) ) {
				$include++ if ( $_ =~ /$filterstr/i );
				$include++ if ( $projnames{$_} =~ /$filterstr/i );
			}
			else {
				$include = 1;
			}

			next unless ( $include );
			$found++;
			$projid = $_;
			print "$_ $projnames{$_}\n";
		}
		print $line . "\n";
		my($prompt) = "filter[$filterstr], ! for quit or backspace to clear filter";
		if ( $found eq 1 ) {
			$prompt .= "\n*** or enter to start timer on proj \"$projid " . $self->projid($projid) . "\" ***";
		}

		print $prompt . "\n";	
		my $answer = $self->readkey;

		if ( $answer =~ /\n|\r/ ) {
			if ( $found eq 1 ) {
				print "Selected...[$projid]...yes\n";
				return($projid);
			}
			next;
		}

		if ( $answer =~ /[[:alnum:]]/ ) {
			push(@filter,$answer);
		}
		elsif ( $answer =~ /[[:cntrl:]]/ ) {
			@filter = ();
		}
		elsif ( $answer eq "!" ) {
			return(undef);
		}
		else {
			print "answer=[$answer]\n";
			print "filterstr=[$filterstr]\n";
		}
		$filterstr = join("",@filter);
	}
}

sub runningtimer { 
	my($self) = shift;
	my($tftmp) = $self->currtimefiletmp();
	if ( -r $tftmp ) {
		return 1;
	}
	else {
		return 0;
	}
}

sub stoptimer {
	my($self) = shift;

	return unless ( $self->runningtimer() );

	my($date,$time) = $self->timestamp();
	my($tf) = $self->currtimefile();
	my($tftmp) = $self->currtimefiletmp();
	my($res) = "end=$time\n";
	if ( -r $tftmp ) {
		if ( open(TF,">> $tftmp") ) {
			print TF $res;
			close(TF);
		}	
		if ( open(TF,"<$tftmp") ) {
			my(@res) = <TF>;
			close(TF);
			if ( open(TF,">>$tf") ) {
				print TF "\n--- " . localtime(time) . " ---\n";
				foreach ( @res ) {
					print TF $_;
				}
				close(TF);
			}
		}
		unlink($tftmp);
	}
	
}
sub starttimer {
	my($self) = shift;
	my($projid) = shift;
	my($comment) = shift;

	if ( $self->runningtimer() ) {
		$self->stoptimer();
	}

	$self->resettime();

	my($text) = $self->projid($projid);
	my($date,$time) = $self->timestamp();
	my($tftmp) = $self->currtimefiletmp();
	my($res) = "";
	$res .= "date=$date\n";
	$res .= "start=$time\n";
	$res .= "proj=$projid ($text)\n";
	$res .= "comment=$comment\n";
	
	if ( open(TF,">> $tftmp") ) {
		print TF $res;
		close(TF);
	}	
}

sub prompt() {
	my($self) = shift;
	my($prompt) = shift;
	print "$prompt : ";
	my $str = <STDIN>;
	chomp($str);
	return($str);
}

sub edit() {
	my($self) = shift;
	my($file) = shift;

	return undef unless ( defined($file) );
	
	unless ( -w $file ) {
		print "No existing file: $file\n";
		return undef;
	}

	my($editor) = $ENV{EDITOR};
	unless ( $editor ) {
		if ( -x "/bin/vim" ) {
			$editor = "/bin/vim";
		}
		elsif ( -x "/usr/bin/vim" ) {
			$editor = "/usr/bin/vim";
		}
		elsif ( -x "/bin/vi" ) {
			$editor = "/bin/vi";
		}
		elsif ( -x "/usr/bin/vi" ) {
			$editor = "/usr/bin/vi";
		}
	}

	if ( $editor ) {
		$self->debug(5,"$editor $file");
		return system("$editor " . $file);
	}
	else {
		print "No editor found, please set \$EDITOR env variable\n";
	}
	return(undef);
}

sub menu {
	my($self) = shift;
	my(%times) = $self->readcurrtimefile();
	
	my(@dates) = $self->dates(\%times);
	my($latestday) = $dates[-1];

	print "\n\n";

	$self->setcolor(BLUE);
	print $line . "\n";
	$self->setcolor();
	my(%date);
	while ( my($key,$value) = each(%times) ) {
		my($date) = $value->{"date"};
		my($start) = $self->zerofilltime($value->{"start"});
		my($end) = $self->zerofilltime($value->{"end"});
		my($proj) = $value->{"proj"};
		my($comment) = $value->{"comment"};
		$date{$date}{$start}{$end}{proj}=$proj;
		$date{$date}{$start}{$end}{comment}=$comment;
	}

	my($date);
	my($prevdate) = 0;
	my(%continue);
	my($continue) = 0;
	my($colorshift) = 0;
	$self->setcolor(GREEN);
	foreach $date ( sort keys %date ) {
		if ( $prevdate ne $date ) {
			$colorshift++;
			$colorshift = 0 if ( $colorshift > 1 );
			$prevdate = $date;
			if ( $colorshift ) {
				$self->setcolor(LIGHTGREEN);
			}
			else {
				$self->setcolor(GREEN);
			}
			print "Date: $date\n";
		}
		my($startp) = $date{$date};
		my($start);
		foreach $start ( sort keys %$startp ) {
			my($endp) = $startp->{$start};
			my($end);
			foreach $end ( sort keys %$endp ) {
				my($hp) = $endp->{$end};
				my($proj) = $hp->{"proj"};
				my($comment) = $hp->{"comment"} || "";
				$continue++;
				$continue{$continue}{proj}=$proj;
				$continue{$continue}{comment}=$comment;
				my($projname) = $self->projid($proj);
				printf("%2d: %s - %s %-40.40s %s\n",$continue, $start,$end, $proj . " " . $projname,  $comment);
			}
		}	
	}
	$self->setcolor();
	$self->setcolor(BLUE);
	print $line . "\n";
	$self->setcolor(RED);
	print $self->formatcurrweekreport("text");
	$self->setcolor();
	#
	# Imort tmp file i.e the running timer
	#
	my(%running) = $self->readtimefile($self->currtimefiletmp());
	my($runningdate) = $running{1}{date};
	my($year,$now) = $self->timestamp();
	#$self->setcolor(RED);
	#print $line . "\n";
	$self->setcolor(RED);
	my($prompt) = "$now ";


	if ( $continue > 0 ) {
		$prompt .= "(c)ontinue ";
	}
	$prompt .= "(e)dit (n)ew (p)rojects (q)uit (r)eport";
	if ( $runningdate ) {
		my($projid) = $running{1}{proj};
		my($project) = $self->projid($projid);
		my($comment) = $running{1}{comment} || "";
		my($start) = $running{1}{start};
		my($secs) = $self->convtime2dursec($start,$now);
		my($min) = int($secs / 60);
		$self->setcolor(BLUE);
		print $line . "\n";
		$self->setcolor(RED);
		print "Timer is running since $start($min min) for projid $projid\n";
		print "Doing \"$comment\" in \"$project\"\n";
		$prompt .= " (s)top (t)empfile:";
	}
	
	$self->setcolor(BLUE);
	print $line . "\n";
	$self->setcolor();
	print $prompt . "\n";
	my $answer = $self->readkey;
	#my $answer = readline(STDIN);
	chomp($answer);
	if ( $answer =~ /^q/i ) {
		print "Quit...\n";	
		if ( $self->runningtimer() ) {
			print "Warning you have a running timer...\n";
		}
		exit(0);
	}
	elsif ( $answer =~ /^c/i ) {
		my $row = $self->prompt("Continue on row: ");
		
		return unless ( defined($row) );
		return unless ( defined($continue{$row}) );
		my($projid) = $continue{$row}{"proj"};
		my($comment) = $continue{$row}{"comment"};
		my($newcomment) = $self->prompt("Comment ($comment): ");
		if ( defined($newcomment) ) {
			if ( length($newcomment) ) {
				$comment=$newcomment;
			}
		}
		print "Continuing on $row (proj:$projid, comment:$comment)\n";
		$self->starttimer($projid,$comment);
	}
	elsif ( $answer =~ /^n/i ) {
		my($projid) = $self->filterproj();
		unless ( $projid ) {
			return(undef);
		}
		my($comment) = $self->prompt("Comment: ");
		$self->starttimer($projid,$comment);
	}
	elsif ( $answer =~ /^t/i ) {
		$self->edit($self->currtimefiletmp());
	}
	elsif ( $answer =~ /^e/i ) {
		$self->edit($self->currtimefile());
	}
	elsif ( $answer =~ /^p/i ) {
		$self->editprojfiles();
		my(%projects) = $self->readprojfiles();
		$self->projects(\%projects);
	}
	elsif ( $answer =~ /^s/i ) {
		$self->stoptimer();
	}
	elsif ( $answer =~ /^r/i ) {
		$self->reportmenu();
	}
	elsif ( $answer =~ /^d/i ) {
		print Dumper(\$self);
	}
}

sub formatoneline_text() {
	# format one line as standard text output
	# input is an array
	my($self) = shift;
	my($ap) = shift;
	my($delimiter) = shift;
	
	# first field is formated as %-30.30s all other 
	# fields ar formated as %9.9s

	my($res) = undef;
	foreach ( @$ap ) {
		unless ( $_ =~ /\D/ ) {
			$_ = sprintf("%.2f",$_);
		}
		my($indent) = 9;
		$indent = -30 unless ( $res );
		if ( defined($delimiter) ) {
			$res .= $_ . $delimiter;
		}
		else {
			$res .= sprintf("%*.*s",$indent,abs($indent),$_);
		}
	}
	return($res);
}

sub formatcurrweekreport_text() {
	my($self) = shift;
	my($header) = shift;
	my($body) = shift;
	my($tailer) = shift;
	my($delimiter) = shift;

	my($res) = $self->formatoneline_text($header,$delimiter) . "\n";
	foreach ( @$body ) {
		$res .= $self->formatoneline_text($_,$delimiter) . "\n";
	}
	$res .= $self->formatoneline_text($tailer,$delimiter) . "\n";
	return($res);
}

sub formatoneline_htmltablerow() {
	# format one line as standard html row output
	# input is an array
	my($self) = shift;
	my($ap) = shift;
	my($delimiter) = shift;
	$delimiter = "td" unless ( $delimiter );
	
	# first field is formated as left justifief all other 
	# fields ar right justifeid

	my($res) = undef;
	foreach ( @$ap ) {
		my($align) = "left";
		$align = "right" if ( $res );
		
		$res .= "<$delimiter align=\"$align\"> $_ </$delimiter>\n";
	}
	$res = "<tr>" . $res . "</tr>\n";
	return($res);
}

sub formatcurrweekreport_html() {
	my($self) = shift;
	my($header) = shift;
	my($body) = shift;
	my($tailer) = shift;

	my($tmp) = "";
	my($html) = "";
	$html .= "<!DOCTYPE html>\n";
	$html .= "<html>\n";
	$html .= "<body>\n";


	$html .= "<table border=\"1\" cellpadding=\"10px\">\n";
	$html .= "<caption>" . $VERSION . "</caption>\n";
	
	$tmp = $self->formatoneline_htmltablerow($header,"th");
	$html .= "<thead> $tmp </thead>\n";
	$html .= "<tbody>\n";
	foreach ( @$body ) {
		$html .= $self->formatoneline_htmltablerow($_,"td");
	}
	$html .= "</tbody>\n";
	$tmp = $self->formatoneline_htmltablerow($tailer,"th");
	$html .= "<tfoot>" . $tmp . "</tfoot>\n";
	$html .= "</table>\n";
	$html .= "</body>\n";
	$html .= "</html>\n";
	return($html);
}

sub formatcurrweekreport() {
	my($self) = shift;
	my($format) = shift;
	$format = "text" unless ( $format );
	my($delimiter) = shift;
	$delimiter = "," unless ( $delimiter );

	my(%times) = $self->readcurrtimefile();

	my($header,$body,$tailer) = $self->rawtimereport(\%times);
	if ( $format =~ /text/ ) {
		return $self->formatcurrweekreport_text($header,$body,$tailer);
	}
	elsif ( $format =~ /csv/ ) {
		return $self->formatcurrweekreport_text($header,$body,$tailer,$delimiter);
	}
	elsif ( $format =~ /html/ ) {
		return $self->formatcurrweekreport_html($header,$body,$tailer);
	}
	else {
		return("");
	}
}


sub reportmenu {
	my($self) = shift;


	my($secs) = time;
	my($weeksec) = 60 * 60 * 24 * 7;

	while(1) {
		#my(%times) = $self->readcurrtimefile();
	
		print "\n\n";
		my($year) = $self->year($secs);
		my($week) = $self->week($secs);

		$self->setcolor();
		$self->setcolor(BLUE);
		print $line . "\n";
		$self->setcolor(RED);
		print $self->formatcurrweekreport("text");
		$self->setcolor();

		my($prompt) = "$year, w$week c(urrent) n(next) p(previous) q(uit) s(et date): ";
		
		$self->setcolor(BLUE);
		print $line . "\n";
		$self->setcolor();
		print $prompt . "\n";
		my $answer = $self->readkey;
		
		chomp($answer);
		if ( $answer =~ /^c/i ) {
			print "Current...\n";
			$secs = time;
		}
		if ( $answer =~ /^n|^j/i ) {
			print "Next...\n";
			$secs += $weeksec;
		}
		elsif ( $answer =~ /^p|^k/i ) {
			print "Previous...\n";
			$secs -= $weeksec;
		}
		elsif ( $answer =~ /^q/i ) {
			print "Quit...\n";	
			$self->setcurrtimefile(time);
			return();
		}
		elsif ( $answer =~ /^s/i ) {
			print "Select...\n";	
			my($date) = $self->prompt("Day (yyyymmdd): ");
			next unless ( $date );
			if ( $date =~ /^(\d\d\d\d)(\d\d)(\d\d)/ ) {
				$secs = POSIX::mktime(0,0,0,$3,$2-1,$1-1900);
				print scalar "Date is: " . localtime($secs) . "\n";
			}
		}
		$self->setcurrtimefile($secs);
	}
}
1;
