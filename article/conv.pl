#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case bundling);

my $PROG = "conv.pl";
my $PKG = "conv";

my $OPT_VERBOSE = 0;
my $OPT_DEBUG = 0;

my $OPT_DBG_BITS = 0;
my $OPT_DBG_BITS_ATTR = 1;
my $OPT_DBG_BITS_DOCB = 2;
sub dbg { return (($OPT_DBG_BITS & $_[0]) != 0); }

sub usage {
	print(STDERR <<EOF
Usage:
  $PROG [OPTIONS]... INPUTFILE OUTPUTFILE
Convert an asciidoctor text file into markdown file
  -h, --help        Print this message
  -v, --verbose     Verbose display
  -d, --debug       Debug
  -D, --Debug n     Debug options, n integer
EOF
	);
}

if (!GetOptions(
	'verbose|v' => \$OPT_VERBOSE,
	'debug|d' => \$OPT_DEBUG,
	'Debug|D=i' => \$OPT_DBG_BITS)) {
	&usage();
};
&usage() if $#ARGV != 1;

my $INP = $ARGV[0];
my $OUTP = $ARGV[1];

my $infoh = \*STDERR;

my $debugh;
if ($OPT_DEBUG or $OPT_DBG_BITS) {
	my $f = "$PKG-dbg.txt";
	open $debugh, ">", $f or die "Unable to opeb '$f': ";
}

open my $inh, '<', $INP or die "Unable to open '$INP' (ro): $!";
open my $outh, '>', $OUTP or die "Unable to open '$OUTP' (rw): $!";

my ($ST_OUTER, $ST_SIDEBAR, $ST_SAMPLE, $ST_QUOTE, $ST_PASSTHROUGH, $ST_ANONYM, $ST_SOURCE, $ST_TABLE, $ST_ADMONITION) = (0..8);
my $ST_BLOCKLEVEL_STATUS_LIMIT = 50;
my ($ST_ATTRIBUTES, $ST_TITLE) = ($ST_BLOCKLEVEL_STATUS_LIMIT..$ST_BLOCKLEVEL_STATUS_LIMIT+1);
our %StatusNames = (
	$ST_OUTER => 'OUTER',
	$ST_SIDEBAR => 'SIDEBAR',
	$ST_SAMPLE => 'SAMPLE',
	$ST_QUOTE => 'QUOTE',
	$ST_PASSTHROUGH => 'PASSTHROUGH',
	$ST_ANONYM => 'ANONYM',
	$ST_SOURCE => 'SOURCE',
	$ST_TABLE => 'TABLE',
	$ST_ADMONITION => 'ADMONITION',
	$ST_ATTRIBUTES => 'ATTRIBUTES',
	$ST_TITLE => 'TITLE'
);
my $UNIQUEWORDATTR = "~~~~";

my %Structs = (

# Bloc-level delimiters

	0 => ['^\*\*\*\*+$', $ST_SIDEBAR],
	1 => ['^====+$', $ST_SAMPLE],
	2 => ['^____+$', $ST_QUOTE],
	3 => ['^\+\+\+\++$', $ST_PASSTHROUGH],
	4 => ['^--$', $ST_ANONYM],
	5 => ['^----+$', $ST_SOURCE],
	6 => ['^\|===+$', $ST_TABLE],

# Special: attributes modify lines that follow

	7 => ['^\[.*\]$', $ST_ATTRIBUTES],
	8 => ['^\.[^. 	]', $ST_TITLE],
);

my @ststack = ($ST_OUTER);

my $docb = DOCB::md->new(outh => \*STDOUT, infoh => $infoh, debug => $OPT_DEBUG, debugh => $debugh);

my $liner = 0;
my %Attributes;

	# Block end = explicit bloc markers (ex. "====" or "***" etc.)
	# or an empty line.
my $pop_status_at_next_block_marker = 0;

while (my $l = <$inh>) {
	$liner++;
	chomp $l;

	my $status = $ststack[$#ststack];

	my $processed_line = 0;
	for my $i (sort { $a <=> $b} keys %Structs) {
		my $pat = $Structs{$i}->[0];
		my $sta = $Structs{$i}->[1];
		next unless $l =~ m/$pat/;

		my %newattr;
		if ($sta < $ST_BLOCKLEVEL_STATUS_LIMIT) {
			if ($pop_status_at_next_block_marker) {
				$docb->proc($l, 'BLOCK_LEAVE', $status);
				pop @ststack;
				$pop_status_at_next_block_marker = 0;
				$status = $ststack[$#ststack];
			}
			if ($sta != $status) {

				my $proc_sta = &get_admonition_attribute(\%Attributes, $sta);

				$docb->proc($l, 'BLOCK_ENTER', $proc_sta);
				push @ststack, $sta;
			} else {
				$docb->proc($l, 'BLOCK_LEAVE', $status);
				pop @ststack;
			}
		} elsif ($sta == $ST_ATTRIBUTES) {
			my ($inside_square_brackets) = $l =~ m/^\[(.*)\]$/;
			die "Inconsistent data, check \$Structs{\$ST_ATTRIBUTES} against line above" unless defined($inside_square_brackets);
			%newattr = &parse_attributes($liner, $inside_square_brackets);
		} elsif ($sta == $ST_TITLE) {
			my ($title) = $l =~ m/^\.(.*)$/;
			die "Inconsistent data, check \$Structs{\$ST_TITLE} against line above" unless defined($title);
			%newattr = ('.' => $title);
		} else {
			die "So what now? \$sta (value: $sta) contains an unknown value!";
		}

		&debug_print_attributes($l, \%newattr) if %newattr;
		%Attributes = (%Attributes, %newattr) if %newattr;

		$processed_line = 1;
		last;
	}

	if (!$processed_line and $l ne '') {
		if (&get_admonition_attribute(\%Attributes, $ST_OUTER) != $ST_OUTER) {
			$docb->proc('', 'BLOCK_ENTER', $ST_ADMONITION);
			push @ststack, $ST_ADMONITION;
			$pop_status_at_next_block_marker = 1;
		}
	}

	if ($l eq '') {
		if (%Attributes) {
			print($infoh "$PKG: warning: line $liner: useless attribute, ignored.\n");
		}
		%Attributes = ();

		if ($pop_status_at_next_block_marker) {
			$docb->proc($l, 'BLOCK_LEAVE', $status);
			pop @ststack;
			$pop_status_at_next_block_marker = 0;
		}
	}

	$status = $ststack[$#ststack];
	my $level = @ststack;

	if ($OPT_DEBUG) {
		printf($debugh "L%05i %i %-8s ", $liner, $level, $StatusNames{$status});
		printf($debugh "%-10s ", join(':', @ststack));
		my $nb_attributes = keys %Attributes;
		printf($debugh "#$nb_attributes ");
		print($debugh join(':', sort keys %Attributes));
		print($debugh "\n");
	}
}

sub get_admonition_attribute {
	my ($attr, $return_value_if_no_admonition_detected) = @_;

	my $detected;
	my @the_keys = keys %{$attr};
	for my $k (@the_keys) {
		if ($k =~ m/^[[:upper:]]+$/) {
			if ($attr->{$k} eq $UNIQUEWORDATTR) {
				print($infoh "$PKG: warning: line $liner: conflicting admonition attributes.\n") if defined($detected);
				$detected = $ST_ADMONITION;
				delete $attr->{$k};
			}
		}
	}

	return $detected if defined($detected);
	return $return_value_if_no_admonition_detected;
}

	#
	# Parse qquare-bracket delimited properties definitions like:
	#   [caption="A blue sky", title="Here and now"]
	# or also:
	#   [source, python]
	# or even:
	#   [start=2]
	#
	# Returns a hash of key-value pairs
	#
	# CONVENTION:
	#   A key without a value gets the value of $UNIQUEWORDATTR.
	# Thus an attribute like
	#   [NOTE]
	# will be returned as the following hash:
	#   ('NOTE' => $UNIQUEWORDATTR)
	#
sub parse_attributes {
	my ($l, $attr) = @_;

	my %Attributes;
	while ($attr ne '') {
		my $remaining;

		my ($y, $w1, $w2, $z);

			# FIXME
			#   Does not supported escaped " characters!
		if (($y, $w1, $w2, $z, $remaining) = $attr =~ m/^([^= \t,]+)\s*(=\s*("?)([^"]*)\3)?\s*(.*)?/) {
			$z = $UNIQUEWORDATTR unless defined($z);

			$Attributes{$y} = $z;
			last if defined($remaining) and $remaining ne '' and $remaining !~ m/^,/;
			if (defined($remaining)) {
				$attr = $remaining;
				$attr =~ s/^,\s*//;
			} else {
				$attr = '';
			}
		} else {
			last;
		}
	}
	print($infoh "$PKG: line $l: syntax error\n") if $attr ne '';

	return %Attributes;
}

sub debug_print_attributes {
	my ($attr, $hash) = @_;

	return unless &dbg($OPT_DBG_BITS_ATTR);

	my %h = %{$hash};

	print($debugh "    >>> attr = '$attr'\n");
	print($debugh "    $_ => '$h{$_}'\n") foreach keys %h;
}

close $debugh if $OPT_DEBUG or $OPT_DBG_BITS;

exit 0;

package DOCB::md;

sub ddbg { return &main::dbg($OPT_DBG_BITS_DOCB); }

sub new {
	my $class = shift;
	my $self = {@_};

	$self->{pkg} = "md";
	$self->{outh} = \*STDOUT unless exists $self->{outh};
	$self->{infoh} = \*STDERR unless exists $self->{infoh};
	$self->{debugh} = \*STDERR unless exists $self->{debugh};
	$self->{debug} = 0 unless exists $self->{debug};

	$self->{status} = $ST_OUTER;

	bless($self, $class);
	return $self;
}

sub proc {
	my $self = shift;
	my $line = shift;
	my $action = shift;

	my $pkg = $self->{pkg};

	my $debug = $self->{debug};
	my $debugh = $self->{debugh};
	print($debugh "$pkg: line '$line': action '$action'") if &ddbg();

	if ($action eq 'BLOCK_ENTER') {
		my $status = shift;
		print($debugh ": status '" . $StatusNames{$status} . "'") if &ddbg();
	} elsif ($action eq 'BLOCK_LEAVE') {
		my $status = shift;
		print($debugh ": status '" . $StatusNames{$status} . "'") if &ddbg();
	} elsif ($action eq 'TEXT') {
	}

	print($debugh "\n") if &ddbg();
}



























package main;

use strict;
use warnings;

my %Vars;

my $linew = 0;
my $status_prev = '';
my $status_data = -1; 
while (my $l = <$inh>) {
	$liner++;
	chomp $l;

	print($infoh "PREVIOUS: '$status_prev'\n") if $OPT_DEBUG;
	print($infoh "<<< '$l' >>>\n") if $OPT_DEBUG;

	next if $l =~ m/^\/\//;

	$l =~ s/{nbsp}/ /g;

	for my $i (1..7) {
		my $r = "=" x $i;
		my $x;
		if (($x) = $l =~ m/^$r([^=].*)$/) {
			$l = &target('HEADER', $i, $x);
			last;
		}
	}

	my $status = '';
	my $is_empty = ($l eq '');

# BLOCS

	if ($status_prev eq 'DEFINITIONS' and !$is_empty) {

			# Quotes:
			#   > bla bla

		$l = &target('QUOTE', $l);
		$status = $status_prev;

	} elsif ($status_prev eq 'BLOC1' and $l =~ m/^\.\S/) {

			# Legend that optionally follows a bloc start:
			#   [IMPORTANT]
			#   .About the stars
		$status = 'BLOC2';
		$l =~ s/^\.//;
		$l = &target('TITLE', $l);

	} elsif ($status_prev =~ m/^BLOC[12]$/ and $l =~ m/^====+$/) {

			# Bloc delimited by '=' lines: opening delimiter
			#   [IMPORTANT]
			#   .About the stars
			#   ====
		$status_prev = 'BLOCEQDELIM';
		next;

	} elsif ($l =~ m/^\*\*\*\*+$/) {

			# Bloc delimited by '*' lines: opening delimiter
			#   ****
		$status_prev = 'BLOCSTDELIM';
		next;

	} elsif ($status_prev eq 'BLOCEQDELIM' and $l =~ m/^====+$/) {

			# Bloc delimited by '=' lines: closing delimiter
			#   [IMPORTANT]
			#   .About the stars
			#   ====
			#   bla
			#
			#   bla bla
			#   ====
		$status_prev = '';
		next;

	} elsif ($status_prev eq 'BLOCSTDELIM' and $l =~ m/^\*\*\*\*+$/) {

			# Bloc delimited by '*' lines: closing delimiter
			#   ****
			#   bla
			#
			#   bla bla
			#   ****
		$status_prev = '';
		next;

	} elsif ($status_prev =~ m/^BLOC/ and !$is_empty) {

			# Inside a bloc...
			#   [IMPORTANT]
			#   .About the stars
			#   ====
			#   bla
		$status = $status_prev;

	} elsif ($status_prev =~ m/^(BLOCEQDELIM|BLOCSTDELIM)/) {

			# Inside a delimited bloc: empty lines do not terminate the bloc
			#   [bla]
			#   .About the stars
			#   ====
			#   bla
			#
			# ((or you can have *** instead of ===))
		$status = $status_prev;
	}

	if ($status =~ m/^BLOC/) {

			# Blocs are translated into tables - markdown does not provide
			# the equivalent.
		$l = &target('BLOCCONTENT', $l);
	}

# MISCELLANEOUS SUBSTITUTIONS

	if ($status_prev eq 'MONOSPACE') {
		$status = $status_prev;
	} else {
		my ($x, $y, $z);
		if ($l =~ m/^\. +\S/) {

				# Numbered lists:
				#   . First item
				#   . Second item
			$status = 'NUM_LIST';
			$status_data = ($status_prev eq 'NUM_LIST' ? $status_data + 1 : 1);
			$l =~ s/^\. //;
			$l = &target('NUMBEREDLIST', $status_data, $l);

		} elsif ($l =~ m/^\.\S/) {

				# Section titles:
				#   .About the stars
			$l =~ s/^\.//;
#            $l = &target('TITLE', $l);
			$l = &target('ADMONITIONHEADER', $l);
			$status = 'BLOC2';

		} elsif (($x, $y) = $l =~ m/^:(\S+):\s*(.*?)\s*$/) {

				# Header properties:
				#   :revnumber: 1.0
			$y = '' unless defined($y);
			$Vars{$x} = $y;
			next;

		} elsif (($x) = $l =~ /^\[(\w+)\]$/) {

				# Admonition header:
				#   [NOTE]
				#
				# or also (can be any string):
				#   [IMPORTANT]
				#
			$l = &target('ADMONITIONHEADER', $x);
			$status = 'BLOC1';

		} elsif (($x) = $l =~ m/^\[(.*)\]$/) {

				# Square-bracket delimited properties definitions:
				#   [caption="A blue sky", title="Here and now"]
				#
				# or also:
				#   [source, python]
				#
				# or even:
				#   [start=2]

			my %Properties;
			while ($x ne '') {
				my $remaining;

				print($infoh "    >>> x = '$x'\n") if $OPT_DEBUG;

				my ($w1, $w2);

					# FIXME
					#   Does not supported escaped " characters!
				if (($y, $w1, $w2, $z, $remaining) = $x =~ m/^([^= \t,]+)\s*(=\s*("?)([^"]*)\3)?\s*(.*)?/) {
					$z = '' unless defined($z);

					print($infoh "         >>> y         = '$y'\n") if $OPT_DEBUG;
					print($infoh "         >>> z         = '$z'\n") if $OPT_DEBUG;
					print($infoh "         >>> remaining = '$remaining'\n") if $OPT_DEBUG;

					$Properties{$y} = $z;
					last if defined($remaining) and $remaining ne '' and $remaining !~ m/^,/;
					if (defined($remaining)) {
						$x = $remaining;
						$x =~ s/^,\s*//;
					} else {
						$x = '';
					}
				} else {
					last;
				}
				print($infoh "         post >>> x    = '$x'\n") if $OPT_DEBUG;
			}
			print($infoh "Line $liner: syntax error\n") if $x ne '';
			$status_data = \%Properties;
			$status_prev = 'PROPERTIES';
			next;

		} elsif (($x) = $l =~ m/^(.*[^:])::+$/) {

				# Definitions:
				#   ECDSA::
			$status = 'DEFINITIONS';
			my $t = $l;
			$t =~ s/^.*[^:](::+)$/$1/;
			my $level = length($t);
			$l = &target('BOLD', $x) . "\n";

		} elsif ($l =~ m/^<<<$/) {

				# Page delimiters:
				#   <<<
			$l = &target('PAGEBREAK');

		} elsif (($x, $y) = $l =~ m/^image::(.+)\[(.+)\]/) {

				# Images (self-contained paragraph):
				#   image::img.png["Nice star"]
			my $prefix = $Vars{"imagesdir"};
			$prefix = ($prefix eq '' ? '' : "$prefix/");
			my $cap = $status_data->{'caption'} if $status_prev eq 'PROPERTIES';
			$cap = '' unless defined($cap);
			$y = $cap unless $cap eq '';
			$y =~ s/^"(.*)"$/$1/;
			$l = &target('LINK', "${prefix}${x}", $y);

		} elsif ($l eq '+') {
			$status = $status_prev;
		}
	}

	if ($l =~ m/^----+$/) {

			# Monospace blocs
		$l = &target('MONOSPACEDELIM');
		if ($status eq 'MONOSPACE') {
			$status = '';
		} else {
			$status = 'MONOSPACE';
		}
	}

	$status_prev = $status;

	print($outh "$l\n");
	$linew++;
}
print($infoh "$liner line(s) read\n");
print($infoh "$linew line(s) written\n");

sub target {
	my $r = &_target(@_);
	print($infoh "    RET<<< '$r' >>>\n") if $OPT_DEBUG;
	return $r;
}

sub _target {

sub myassert {
	die unless defined($_[0]) and $_[0];
}

	my $type = shift;

	print($infoh "    $type\n") if $OPT_DEBUG;

	if ($type eq 'HEADER') {
		&myassert(@_ == 2);
		return ("#" x $_[0]) . $_[1];
	} elsif ($type eq 'QUOTE') {
		&myassert(@_ == 1);
		return "> $_[0]";
	} elsif ($type eq 'TITLE') {
		&myassert(@_ == 1);
		return "_$_[0]_";
	} elsif ($type eq 'ADMONITIONHEADER') {
		return "| $_[0] |\n| --- |";
	} elsif ($type eq 'BLOCCONTENT') {
		&myassert(@_ == 1);
		return "| $_[0] |";
	} elsif ($type eq 'NUMBEREDLIST') {
		&myassert(@_ == 2);
		return "$_[0]. $_[1]";
	} elsif ($type eq 'BOLD') {
		&myassert(@_ == 1);
		return "**$_[0]**";
	} elsif ($type eq 'PAGEBREAK') {
		&myassert(@_ == 0);
		return "* * *";
	} elsif ($type eq 'LINK') {
		&myassert(@_ == 2);
		return "![$_[1]]($_[0])";
	} elsif ($type eq 'MONOSPACEDELIM') {
		&myassert(@_ == 0);
		return "```";
	}

	die "Unknown type: '$type'";
}
