#!/bin/sh
# /mn/ 20241008 generate demo for https://github.com/mnalis/android-wifi-upgrade/issues/9#issuecomment-2381087696
#NAME=demo1 
#NAME=demo2
#NAME=demo3
#NAME=demo4
NAME=demo5
(cat head.xml; for id in `seq -w 01 50`; do sed -e "s/%SSID%/${NAME}_${id}/g" < template_${NAME}.xml ; done ; cat tail.xml) > WifiConfigStore_${NAME}_xml.txt
