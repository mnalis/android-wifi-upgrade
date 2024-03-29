# android-wifi-upgrade
convert WiFi passwords from old Android wpa_supplicant.conf to newer (post-Oreo) WifiConfigStore.xml

This perl script reads old wpa_supplicant.conf on STDIN, and outputs new WifiConfigStore.xml to STDOUT

## Description
For me, upgrading LG G3 from LineageOS 14.1 (Android 7.1.2 "Nougat") to LineageOS 16.0 (Android 9 "Pie") resulted
in all my wifi password being lost. The reason is the information is no longer kept in
*/data/misc/wifi/wpa_supplicant.conf* but instead in */data/misc/wifi/WifiConfigStore.xml*

This script is a quick hack to convert (most of the) passwords to new format
so I don't have to remember and type them all again.

All of the project is released under Apache 2.0 license (see LICENSE file).

## Usage

* `adb root`

  (make sure you have first set permissions in developer settings root ADB)

* `adb pull  /data/misc/wifi/wpa_supplicant.conf`

   (or in whatever location it is in your device - maybe */data/wifi/bcm_supp.conf* or */data/misc/wifi/wpa.conf*)

* `./convert_wifi.pl < wpa_supplicant.conf  > WifiConfigStore.xml`

  (and check any warnings / error outputed on the screen)

* disable WiFi on your phone

* push new config on the phone (to correct location - check first where is current *WifiConfigStore.xml*):
```
adb push WifiConfigStore.xml /data/misc/wifi/WifiConfigStore.xml
adb shell chmod 600 /data/misc/wifi/WifiConfigStore.xml
adb shell chown system:system /data/misc/wifi/WifiConfigStore.xml
adb shell rm /data/misc/wifi/WifiConfigStore.xml.encrypted-checksum
adb reboot
```

Note that location of *WifiConfigStore.xml* on your device might be something other than */data/misc/wifi* (like */data/misc/apexdata/com.android.wifi*), so you need to verify that first (and update the commands above accordingly).

* enable WiFi on your phone

## Troubleshooting
* some phone require WAPI support, and others do not support it.
  If `master` git branch at https://github.com/mnalis/android-wifi-upgrade
  report errors when you try to upload `WifiConfigStore.xml`,
  try `wapi` git branch: https://github.com/mnalis/android-wifi-upgrade/tree/wapi

  This is because different phones have different config format requirements,
  see https://github.com/mnalis/android-wifi-upgrade/issues/6 for details

* if all else fails, please report new issue at https://github.com/mnalis/android-wifi-upgrade/issues

## TODO
* Never write XML by hand as I do here!  It will seem to work in most cases,
  and then break badly on some non-escaped value or similar.

* only config supports implemented currently are open networks (no PSK),
  WEP networks with up to 4 preshared keys, and WPA2 networks (with ASCII PSK);
  WPA1 may be or not be supported per chosen bit masks, but was not tested
  directly. Maybe support other (WPA1, EAP-xxx thingies)?

* set uid to 1000 or 0 ? or -1 ?

    * there are UIDs in "CreatorUid", "LastUpdateUid", "LastConnectUid",
      "CreatorName" => "android.uid.system:1000",
      "LastUpdateName" => "android.uid.system:1000"...
      are they all same or may be different?

* parse id_str (url_decode, JSON) for creatorUid & configKey ?

* where to put "priority" and "bssid" from wpa_supplicant.conf ?

    * possibly, bssid maps to DefaultGwMacAddress ?

* wpa_supplicant.conf: is "disabled" always "1" ?

* warn for all unhandled key/value pairs (or even better, handle them correctly)

* add options to select 'WAPI' (`$AllowedProtocols`) and `$ConfigKey`
  formats, instead of using different git branches (need to fix `make check`
  too then)

* FIXMEs in code
