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
$| = 1;

sub dbg($$) {
	my ($lvl, $msg) = @_;
	print STDERR "dbg:$lvl" . (' ' x ($lvl*1)) . "$msg\n" if $DEBUG >= $lvl;
}

my %CUR=();

# header of WifiConfigStore.xml
sub start_xml() {
	print <<EOF
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<WifiConfigStoreData>
    <int name="Version" value="1"/>
    <NetworkList>

EOF
}

# FIXME: we should never do XML by hand like this. oh well.
sub quote_xml($) {
	my ($str) = @_;
	$str =~ s{\"}{&quot;}g;
	return $str;
}

# constructs one network entry in WifiConfigStore.xml
sub add_xml() {

	if ($CUR{disabled} eq 1) {
		warn "ignoring disabled network $CUR{ssid}";
		return;
	}

	print q{
        <Network>
            <WifiConfiguration>};

	my $ConfigKey = quote_xml 'FIXME NETNAME_WPA_PSK';
	my $SSID = quote_xml '"FIXME_SSID_WITH_QUOTES"';
	my $CreationTime = 'time=12-01 00:00:00.000';	# FIXME example: time=12-02 01:47:38.625
	my $CreationUID = '1000';	# FIXME make it user configurable?


	my $PSK_LINE = '<null name="PreSharedKey"/>';
	my $AllowedKeyMgmt = '01';	# 01 for null PSK, 02 otherwise?
	if ($CUR{key_mgmt} ne 'NONE') {
		my $PreSharedKey = quote_xml '"FIXME_UNDEF_OR_QUOTED_PSK"';
	}
	
	print qq{
                <string name="ConfigKey">$ConfigKey</string>
                <string name="SSID">$SSID</string>
                <null name="BSSID"/>
                $PSK_LINE
                <null name="WEPKeys"/>
                <int name="WEPTxKeyIndex" value="0"/>
                <boolean name="HiddenSSID" value="false"/>
                <boolean name="RequirePMF" value="false"/>
                <byte-array name="AllowedKeyMgmt" num="1">$AllowedKeyMgmt</byte-array>
                <byte-array name="AllowedProtocols" num="1">03</byte-array>
                <byte-array name="AllowedAuthAlgos" num="1">01</byte-array>
                <byte-array name="AllowedGroupCiphers" num="1">0f</byte-array>
                <byte-array name="AllowedPairwiseCiphers" num="1">06</byte-array>
                <boolean name="Shared" value="true"/>
                <int name="Status" value="2"/>
                <null name="FQDN"/>
                <null name="ProviderFriendlyName"/>
                <null name="LinkedNetworksList"/>
                <null name="DefaultGwMacAddress"/>
                <boolean name="ValidatedInternetAccess" value="false"/>
                <boolean name="NoInternetAccessExpected" value="false"/>
                <int name="UserApproved" value="0"/>
                <boolean name="MeteredHint" value="false"/>
                <int name="MeteredOverride" value="0"/>
                <boolean name="UseExternalScores" value="false"/>
                <int name="NumAssociation" value="0"/>
                <int name="CreatorUid" value="$CreationUID"/>
                <string name="CreatorName">android.uid.system:$CreationUID</string>
                <string name="CreationTime">$CreationTime</string>
                <int name="LastUpdateUid" value="$CreationUID"/>
                <string name="LastUpdateName">android.uid.system:$CreationUID</string>
                <int name="LastConnectUid" value="0"/>
                <boolean name="IsLegacyPasspointConfig" value="false"/>
                <long-array name="RoamingConsortiumOIs" num="0"/>
                <string name="RandomizedMacAddress">02:00:00:00:00:00</string>
};
	
	die;
	
	print q{            </WifiConfiguration>
            <NetworkStatus>
                <string name="SelectionStatus">NETWORK_SELECTION_ENABLED</string>
                <string name="DisableReason">NETWORK_SELECTION_ENABLE</string>
                <null name="ConnectChoice"/>
                <long name="ConnectChoiceTimeStamp" value="-1"/>
                <boolean name="HasEverConnected" value="false"/>
            </NetworkStatus>
            <IpConfiguration>
                <string name="IpAssignment">DHCP</string>
                <string name="ProxySettings">NONE</string>
            </IpConfiguration>
        </Network>
};
}

# footer of WifiConfigStore.xml
sub end_xml() {
	print q{

    </NetworkList>
    <PasspointConfigData>
        <long name="ProviderIndex" value="0"/>
    </PasspointConfigData>
</WifiConfigStoreData>
}
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
