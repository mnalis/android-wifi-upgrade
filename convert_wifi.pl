#!/usr/bin/perl
# by Matija Nalis <mnalis-perl@voyager.hr>, Apache 2.0 license, started 2019-12-02
#
# converts android WiFi passwords from old wpa_supplicant.conf to newer WifiConfigStore.xml
#

use warnings;
use strict;
use autodie;
use Data::Dumper;

use POSIX qw(strftime);

my $DEBUG = $ENV{DEBUG} || 0;
my $IGNORE_OPEN = $ENV{IGNORE_OPEN} || 0;	# ignore open networks (without password) and do not convert them
my $CreationUID = $ENV{FORCEUID} || '1000';	# FIXME user configurable? or read from id_str (but it can be "-1" there!) or fix to "0" ?

$| = 1;

sub dbg($$) {
	my ($lvl, $msg) = @_;
	print STDERR "dbg:$lvl" . (' ' x ($lvl*1)) . "$msg\n" if $DEBUG >= $lvl;
}

my %CUR=();

# header of WifiConfigStore.xml
sub start_xml() {
	print <<EOF
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<WifiConfigStoreData>
<int name="Version" value="1" />
<NetworkList>
EOF
}

# FIXME: we should never do XML by hand like this. oh well.
sub quote_xml($) {
	my ($str) = @_;
	$str =~ s{&}{&amp;}g;
	$str =~ s{<}{&lt;}g;
	$str =~ s{>}{&gt;}g;
	$str =~ s{\'}{&apos;}g;
	$str =~ s{\"}{&quot;}g;
	return $str;
}

#my $cnt = 0;
# constructs one network entry in WifiConfigStore.xml
sub add_xml() {
	my $SSID = $CUR{ssid}; 
	if (!defined $SSID) { return warn "Skipping - no SSID?! in " . Dumper(\%CUR) };
	#if ($SSID !~ /^[a-zA-Z0-9_ \-\"\'\.<>&()@]+$/) { warn "Possibly problematic SSID name $SSID (FIXME needs escaping?)" };

	my $key_mgmt = $CUR{key_mgmt} || ''; warn "no key_mgmt for SSID $SSID" if not defined $CUR{key_mgmt};
	if ($CUR{key_mgmt} !~ /^NONE|WPA-PSK$/) { return warn "Skipping network with unknown key_mgmt=$key_mgmt for SSID $SSID" };
	$key_mgmt =~ tr/-/_/;

	if ($IGNORE_OPEN and $key_mgmt eq 'NONE') { return };
	#return if $DEBUG > 0 and $cnt++ < 49;	# FIXME DELME debug why it doesn't work will all 74 networks?

	if (defined $CUR{auth_alg}) { warn "probably don't know how to correctly handle auth_alg=$CUR{auth_alg} in SSID $SSID" };

	my $CreationTime = strftime "time=%m-%d %H:%M:%S.000", localtime;	# FIXME example: time=12-02 01:47:38.625 -- year is lost??

	my $PSK_LINE = '<null name="PreSharedKey" />';
	my $AllowedKeyMgmt = '01';	# seems to be 01 for null PSK, 02 otherwise?
	if ($key_mgmt ne 'NONE') {
		if (!defined $CUR{psk}) { return warn "Skipping - no PSK for SSID $SSID" };
		my $PreSharedKey = quote_xml $CUR{psk}; 
		$AllowedKeyMgmt = '02';
		$PSK_LINE = '<string name="PreSharedKey">' . $PreSharedKey . '</string>';
	}
	
	$SSID = quote_xml $SSID;
	my $ConfigKey = "${SSID}$key_mgmt"; 
	my $priority = $CUR{priority};
	
	# output main config block with all variables filled-in
	print qq{<Network>
<WifiConfiguration>
<string name="ConfigKey">$ConfigKey</string>
<string name="SSID">$SSID</string>
<null name="BSSID" />
$PSK_LINE
<null name="WEPKeys" />
<int name="WEPTxKeyIndex" value="0" />
<boolean name="HiddenSSID" value="false" />
<boolean name="RequirePMF" value="false" />
<byte-array name="AllowedKeyMgmt" num="1">$AllowedKeyMgmt</byte-array>
<byte-array name="AllowedProtocols" num="1">03</byte-array>
<byte-array name="AllowedAuthAlgos" num="1">01</byte-array>
<byte-array name="AllowedGroupCiphers" num="1">0f</byte-array>
<byte-array name="AllowedPairwiseCiphers" num="1">06</byte-array>
<boolean name="Shared" value="true" />
<int name="Status" value="2" />
<null name="FQDN" />
<null name="ProviderFriendlyName" />
<null name="LinkedNetworksList" />
<null name="DefaultGwMacAddress" />
<boolean name="ValidatedInternetAccess" value="false" />
<boolean name="NoInternetAccessExpected" value="false" />
<int name="UserApproved" value="0" />
<boolean name="MeteredHint" value="false" />
<int name="MeteredOverride" value="0" />
<boolean name="UseExternalScores" value="false" />
<int name="NumAssociation" value="$priority" />
<int name="CreatorUid" value="$CreationUID" />
<string name="CreatorName">android.uid.system:$CreationUID</string>
<string name="CreationTime">$CreationTime</string>
<int name="LastUpdateUid" value="$CreationUID" />
<string name="LastUpdateName">android.uid.system:$CreationUID</string>
<int name="LastConnectUid" value="0" />
<boolean name="IsLegacyPasspointConfig" value="false" />
<long-array name="RoamingConsortiumOIs" num="0" />
<string name="RandomizedMacAddress">02:00:00:00:00:00</string>
</WifiConfiguration>
<NetworkStatus>
<string name="SelectionStatus">NETWORK_SELECTION_ENABLED</string>
<string name="DisableReason">NETWORK_SELECTION_ENABLE</string>
<null name="ConnectChoice" />
<long name="ConnectChoiceTimeStamp" value="-1" />
<boolean name="HasEverConnected" value="false" />
</NetworkStatus>
<IpConfiguration>
<string name="IpAssignment">DHCP</string>
<string name="ProxySettings">NONE</string>
</IpConfiguration>
</Network>
};
	
	#die "FIXME TEST KRAJ";

# FIXME original looks like this:
#network={
#        ssid="SomeNet name"
#        bssid=a4:1d:6b:4b:3e:2f
#        psk="SomePassword"
#        key_mgmt=WPA-PSK
#        priority=201
#        disabled=1
#        id_str="%7B%22creatorUid%22%3A%22-1%22%2C%22configKey%22%3A%22%5C%22SomeNet+name%5C%22WPA_PSK%22%7D"
#}
	
}

# footer of WifiConfigStore.xml
sub end_xml() {
	print <<EOF
</NetworkList>
<PasspointConfigData>
<long name="ProviderIndex" value="0" />
</PasspointConfigData>
</WifiConfigStoreData>
EOF
}

#
# here goes the main loop
#

start_xml();
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
		add_xml();
		%CUR=();
		next;
	}
	
	if (/^\s*(\w+)\s*=\s*(.*)$/) {		# key=value pairs
		$CUR{lc($1)}=$2;
	} else {
		warn "ignoring unparseable line: $_";
	}
}

end_xml();
