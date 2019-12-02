#!/usr/bin/perl -T
# by Matija Nalis <mnalis-perl@voyager.hr>, Apache 2.0 license, started 2019-12-02
#
# converts android WiFi passwords from old wpa_supplicant.conf to newer WifiConfigStore.xml
#

use warnings;
use strict;
use autodie;
use Data::Dumper;

my $DEBUG = $ENV{DEBUG} || 0;
my $IGN_ERR = $ENV{IGN_ERR} || 0;

sub dbg($$) {
	my ($lvl, $msg) = @_;
	print "dbg:$lvl" . (' ' x ($lvl*1)) . "$msg\n" if $DEBUG >= $lvl;
}

my %CUR=();
while (<STDIN>)
{
	chomp;
	dbg 9, "line: $_";
	next if /^\s*$/;
	
	if (/^\s*network\s*=\s*{/) {		# "network={" begins a new block
		%CUR=();
		next;
	}
	
	if (/^\s*}/) {				# sole "}" ends the block
		dbg 5, "block end: " . Dumper(\%CUR);
		if (!defined $CUR{'ssid'}) {
			warn "can't parse network without SSID, ignoring block:" . Dumper(\%CUR);
		}
		die;
		%CUR=();
		next;
	}
	
	if (/^\s*(\w+)\s*=\s*(.*)$/) {		# key=value pairs
		$CUR{lc($1)}=$2;
	} else {
		warn "ignoring unparseable line: $_";
	}
}
