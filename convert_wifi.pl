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

	my $CreationTime = strftime "time=%m-%d %H:%M:%S.000", localtime;	# FIXME example: time=12-02 01:47:38.625 -- year is lost??

	my $PSK_LINE = '<null name="PreSharedKey" />';
	# https://developer.android.com/reference/android/net/wifi/WifiConfiguration#SECURITY_TYPE_WAPI_PSK
	# Values below are BitSet's = arrays of booleans at numbered bit positions:

	my $AllowedKeyMgmt = '01'; # NONE
	# https://developer.android.com/reference/android/net/wifi/WifiConfiguration.KeyMgmt
	#   0 NONE - WPA is not used; plaintext or static WEP could be used.
	#   1 WPA_PSK - WPA pre-shared key (requires preSharedKey to be specified).
	#   2 WPA_EAP - WPA using EAP authentication. Generally used with an external authentication server.
	#   3 IEEE8021X - IEEE 802.1X using EAP authentication and (optionally) dynamically generated WEP keys.
	#   8 SAE - Simultaneous Authentication of Equals
	#   9 OWE - Opportunististic Wireless Encryption
	#   10 SUITE_B_192

	#my $AllowedProtocols = '03'; # WPA1+WPA2
	my $AllowedProtocols = '0b'; # WPA1+WPA2+WAPI
	# https://developer.android.com/reference/android/net/wifi/WifiConfiguration.Protocol
	#   0 WPA1 (deprecated)
	#   1 RSN WPA2/WPA3/IEEE 802.11i
	#   3 WAPI

	my $AllowedAuthAlgos = '01'; # open
	# https://developer.android.com/reference/android/net/wifi/WifiConfiguration.AuthAlgorithm
	#   0 OPEN - Open System authentication (required for WPA/WPA2)
	#   1 SHARED - Shared Key authentication (requires static WEP keys)
	#   2 LEAP/Network EAP (only used with LEAP)
	#   3 SAE (Used only for WPA3-Personal)
	if (defined $CUR{auth_alg}) {
		$AllowedAuthAlgos = 0;
		if ($CUR{auth_alg} =~ m/OPEN/)   { $AllowedAuthAlgos |= 1 ; }
		if ($CUR{auth_alg} =~ m/SHARED/) { $AllowedAuthAlgos |= 1 << 1 ; }
		if ($CUR{auth_alg} =~ m/LEAP/)   { $AllowedAuthAlgos |= 1 << 2 ; }
		if ($AllowedAuthAlgos eq 0) { warn "probably don't know how to correctly handle auth_alg=$CUR{auth_alg} in SSID $SSID"; }
		else { $AllowedAuthAlgos = sprintf "%02x", $AllowedAuthAlgos; }
	};

	#my $AllowedGroupCiphers = '0f'; # 001111 = wep+tkip+aes
	my $AllowedGroupCiphers = '2f'; # 101111 = wep+tkip+aes+aes
	# https://developer.android.com/reference/android/net/wifi/WifiConfiguration.GroupCipher
	#   0 WEP40 = WEP (Wired Equivalent Privacy) with 40-bit key (original 802.11)
	#   1 WEP104 = WEP (Wired Equivalent Privacy) with 104-bit key
	#   2 TKIP = Temporal Key Integrity Protocol [IEEE 802.11i/D7.0]
	#   3 CCMP = AES in Counter mode with CBC-MAC [RFC 3610, IEEE 802.11i/D7.0]
	#   5 GCMP_256 = AES in Galois/Counter Mode
	#   6 SMS4 = SMS4 cipher for WAPI

	#my $AllowedPairwiseCiphers = '06'; # TKIP(2)/AES(4)
	my $AllowedPairwiseCiphers = '0e'; # TKIP(2)/AES(4)/AES(8)
	# https://developer.android.com/reference/android/net/wifi/WifiConfiguration.PairwiseCipher
	#   0 NONE - Use only Group keys (deprecated)
	#   1 TKIP (WPA1) - deprecated
	#   2 CCMP - AES in Counter mode with CBC-MAC [RFC 3610, IEEE 802.11i/D7.0]
	#   3 GCMP_256 - AES in Galois/Counter Mode
	#   4 SMS4 cipher for WAPI

	my $AllowedGroupMgmtCiphers = ''; # The samples I've seen have it empty
	# https://developer.android.com/reference/android/net/wifi/WifiConfiguration.GroupMgmtCipher
	#   0 BIP_CMAC_256 = Cipher-based Message Authentication Code 256 bits
	#   1 BIP_GMAC_128 = Galois Message Authentication Code 128 bits
	#   2 BIP_GMAC_256 = Galois Message Authentication Code 256 bits

	my $AllowedSuiteBCiphers = '01';
	# SuiteB Ciphers are for WPA3-Enterprise, documentation not detailed at that page above

	if ($key_mgmt ne 'NONE') {
		if (!defined $CUR{psk}) { return warn "Skipping - no PSK for SSID $SSID" };
		my $PreSharedKey = quote_xml $CUR{psk}; 
		$AllowedKeyMgmt = '02';
		$PSK_LINE = '<string name="PreSharedKey">' . $PreSharedKey . '</string>';
	}

	my $WEP_LINE = '<null name="WEPKeys" />';
	if (defined $CUR{wep_key0} || defined $CUR{wep_key1} || defined $CUR{wep_key2} || defined $CUR{wep_key3}) {
		$WEP_LINE = '<string-array name="WEPKeys" num="4">' . "\n";
		if (defined $CUR{wep_key0}) { $WEP_LINE .= '<item value="' . quote_xml ($CUR{wep_key0}) . '" />' . "\n"; } else { $WEP_LINE .= '<item value="" />' . "\n"; }
		if (defined $CUR{wep_key1}) { $WEP_LINE .= '<item value="' . quote_xml ($CUR{wep_key1}) . '" />' . "\n"; } else { $WEP_LINE .= '<item value="" />' . "\n"; }
		if (defined $CUR{wep_key2}) { $WEP_LINE .= '<item value="' . quote_xml ($CUR{wep_key2}) . '" />' . "\n"; } else { $WEP_LINE .= '<item value="" />' . "\n"; }
		if (defined $CUR{wep_key3}) { $WEP_LINE .= '<item value="' . quote_xml ($CUR{wep_key3}) . '" />' . "\n"; } else { $WEP_LINE .= '<item value="" />' . "\n"; }
		$WEP_LINE .= '</string-array>';

		if ($key_mgmt eq 'NONE') { $key_mgmt = 'WEP'; } # For the ConfigKey below to be meaningful
	}

	$SSID = quote_xml $SSID;
	my $ConfigKey = "${SSID}$key_mgmt"; 
	my $priority = $CUR{priority} || 0;
	
	# output main config block with all variables filled-in
	print qq{<Network>
<WifiConfiguration>
<string name="ConfigKey">$ConfigKey</string>
<string name="SSID">$SSID</string>
<null name="BSSID" />
$PSK_LINE
$WEP_LINE
<int name="WEPTxKeyIndex" value="0" />
<boolean name="HiddenSSID" value="false" />
<boolean name="RequirePMF" value="false" />
<byte-array name="AllowedKeyMgmt" num="1">$AllowedKeyMgmt</byte-array>
<byte-array name="AllowedProtocols" num="1">$AllowedProtocols</byte-array>
<byte-array name="AllowedAuthAlgos" num="1">$AllowedAuthAlgos</byte-array>
<byte-array name="AllowedGroupCiphers" num="1">$AllowedGroupCiphers</byte-array>
<byte-array name="AllowedPairwiseCiphers" num="1">$AllowedPairwiseCiphers</byte-array>
<byte-array name="AllowedGroupMgmtCiphers" num="0">$AllowedGroupMgmtCiphers</byte-array>
<byte-array name="AllowedSuiteBCiphers" num="1">$AllowedSuiteBCiphers</byte-array>
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
