# Makefile for android-wifi-upgrade project to automate
# its typical tasks and selftest
#
# Copyright (C) 2020 by Jim Klimov <jimklimov@gmail.com>
# released under Apache 2.0 license (see LICENSE file).

### Default target is first
all: WifiConfigStore.xml

check: check-syntax check-sample-data

convert_wifi_SCRIPT = convert_wifi.pl

# TODO: Guess via path to this Makefile
src_dir = .

### The practical use-case
wpa_supplicant.conf:
	@if [ ! -s "$@" ]; then echo "Please download $@ from your old Android system and place here" >&2 ; exit 1; fi

WifiConfigStore.xml: wpa_supplicant.conf $(src_dir)/$(convert_wifi_SCRIPT)
	$(src_dir)/$(convert_wifi_SCRIPT) < $< > $@
	@echo "Converted without major errors. Please see README.md about uploading $@ to your new phone." >&2

### Self-tests of the script
check-syntax: $(src_dir)/$(convert_wifi_SCRIPT)
	perl -c $<

selftest-rw/WifiConfigStore.xml: selftest-ro/wpa_supplicant.conf $(src_dir)/$(convert_wifi_SCRIPT)
	$(src_dir)/$(convert_wifi_SCRIPT) < $< > $@

# Note: the check below filters away lines that depend on generation time
# or come from Android/MIUI extensions in the sample data file (redacted
# .XML extract from a real Android 10 phone) and are not really founded
# in any lines from the older .CONF equivalent.
check-sample-data: selftest-ro/WifiConfigStore.xml selftest-rw/WifiConfigStore.xml
	@diff -bu $^ \
	| grep -E -v 'name="(CreationTime|LastConnectUid|ValidatedInternetAccess|HasEverConnected|HiddenSSID|ConnectChoiceTimeStamp|ConnectChoice)"' \
	| grep -E -v 'name="(staId|ShareThisAp)"' \
	| grep -E -v '(MacAddressMap|name="MacMapEntry")' \
	| grep -E -v 'name="(RandomizedMacAddress|MacRandomizationSetting)"' \
	| grep -E -v 'name="(DppConnector|DppNetAccessKey|DppNetAccessKeyExpiry|DppCsign)"' \
	| grep -E -v '^(\-\-\-|\+\+\+)' | grep -E '^[+-]' \
	&& { echo "FAILED: Got unexpected line differences in output, see above" >&2 ; exit 1; } \
	|| { echo "SUCCESS: No unexpected line differences in output" >&2 ; exit 0; }

clean:
	rm -f selftest-rw/WifiConfigStore.xml
