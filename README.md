# android-wifi-upgrade
convert WiFi passwords from old Android wpa_supplicant.conf to newer (post-Oreo) WifiConfigStore.xml

## Description
For me, upgrading LG G3 from LineageOS 14.1 (Android 7.1.2 "Nougat") to LineageOS 16.0 (Android 9 "Pie") resulted 
in all my wifi password being lost. The reason is the information is no longer kept in 
"/data/misc/wifi/wpa_supplicant.conf" but instead in "/data/misc/wifi/WifiConfigStore.xml" 

This script is a quick hack to convert (most of the) passwords to new format
so I don't have to remember and type them all again.

## Usage
This perl script reads old wpa_supplicant.conf on STDIN, and outputs new WifiConfigStore.xml to STDOUT

## TODO
* Never write XML by hand as I do here!  It will seem to work in most cases, and then break badly on some non-escaped value or similar.
* only config I implemented currently are open networks (no PSK) and WPA2 networks (with ASCII PSK). Maybe support other (WEP, WPA1, EAP-xxx thingies) ?
* FIXMEs in code
