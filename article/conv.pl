#!/usr/bin/perl

use strict;
use warnings;

my $PKG = "conv.pl";

my $OPT_DEBUG = 0;

my $infoh = \*STDERR;

my $INP = $ARGV[0];
my $OUTP = $ARGV[1];

&usage() if $#ARGV != 1;

sub usage {
	print(STDERR <<EOF
Usage:
  $PKG INPUTFILE OUTPUTFILE
convert an asciidoctor text file into markdown file
EOF
	);
}

open my $inh, '<', $INP or die "Unable to open '$INP' (ro): $!";
open my $outh, '>', $OUTP or die "Unable to open '$OUTP' (rw): $!";

my %Vars;

my $liner = 0;
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
		$status_prev = 'BLOC3';
		next;

	} elsif ($status_prev eq 'BLOC3' and $l =~ m/^====+$/) {

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

	} elsif ($status_prev =~ m/^BLOC/ and !$is_empty) {

			# Inside a bloc...
			#   [IMPORTANT]
			#   .About the stars
			#   ====
			#   bla
		$status = $status_prev;

	} elsif ($status_prev =~ m/^BLOC3/) {

			# Inside a delimited bloc: empty lines do not terminate the bloc
			#   [IMPORTANT]
			#   .About the stars
			#   ====
			#   bla
			#
		$status = $status_prev;
		$status = $status_prev;
	}

	if ($status =~ m/^BLOC/) {

			# Blocs are translated into tables - markdown does not provide
			# the equivalent.
		$l = &target('TABLE', $l);
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
			$l = &target('TITLE', $l);

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
			$l = &target('TABLEHEADLINE', $x);
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
	} elsif ($type eq 'TABLEHEADLINE') {
		return "| $_[0] |\n| --- |";
	} elsif ($type eq 'TABLE') {
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
