#!/bin/bash
#
# vim:noet ts=2 sw=2

USRPWD="admin:12345678"
SWITCH_IP="192.168.128.210"
SWITCH2_IP="192.168.128.220"
LOG_REPORT_URL="/api/setData?path=BeoPortal%3AlogReport%2Fsend&roles=activate&value=%7B%22type%22%3A%22bool_%22%2C%22bool_%22%3Atrue%7D"
EXTENDED_LOG_FILE="/media/settings/logs/mwifiex_logs.txt"

# M3
DEV1_IP="192.168.128.157"
DEV1_SERIAL="94100"
DEV1_POWER_URL="http://${USRPWD}@${SWITCH2_IP}/set.cmd?cmd=setpower+p61="
DEV1_INIT_SCRIPT="
echo -n 'module mwifiex_usb +p' > /sys/kernel/debug/dynamic_debug/control
echo -n 'module mwifiex +p' > /sys/kernel/debug/dynamic_debug/control
rm -f $EXTENDED_LOG_FILE
nohup /bin/sh -c 'while true; do date >> $EXTENDED_LOG_FILE; dmesg -c >> $EXTENDED_LOG_FILE; sleep 1; done &'

echo performance > /sys/module/pcie_aspm/parameters/policy
"

# M3
DEV2_IP="192.168.128.149"
DEV2_SERIAL="94118"
DEV2_POWER_URL="http://${USRPWD}@${SWITCH2_IP}/set.cmd?cmd=setpower+p62="
DEV2_INIT_SCRIPT="
echo -n 'module mwifiex_usb +p' > /sys/kernel/debug/dynamic_debug/control
echo -n 'module mwifiex +p' > /sys/kernel/debug/dynamic_debug/control
rm -f $EXTENDED_LOG_FILE
nohup /bin/sh -c 'while true; do date >> $EXTENDED_LOG_FILE; dmesg -c >> $EXTENDED_LOG_FILE; sleep 1; done &'
"

# M3
DEV3_IP="192.168.128.120"
DEV3_SERIAL="28155578"
DEV3_POWER_URL="http://${USRPWD}@${SWITCH2_IP}/set.cmd?cmd=setpower+p63="
DEV3_INIT_SCRIPT=""

# BS Core
DEV4_IP="192.168.128.160"
DEV4_SERIAL="93717"
DEV4_POWER_URL="http://${USRPWD}@${SWITCH2_IP}/set.cmd?cmd=setpower+p64="
DEV4_INIT_SCRIPT="
echo -n 'module mwifiex_usb +p' > /sys/kernel/debug/dynamic_debug/control
echo -n 'module mwifiex +p' > /sys/kernel/debug/dynamic_debug/control
rm -f $EXTENDED_LOG_FILE
nohup /bin/sh -c 'while true; do date >> $EXTENDED_LOG_FILE; dmesg -c >> $EXTENDED_LOG_FILE; sleep 1; done &'
"

# M5
DEV5_IP="192.168.128.161"
DEV5_SERIAL="94349"
DEV5_POWER_URL="http://${USRPWD}@${SWITCH_IP}/set.cmd?cmd=setpower+p63="
DEV5_INIT_SCRIPT="
echo -n 'module mwifiex_usb +p' > /sys/kernel/debug/dynamic_debug/control
echo -n 'module mwifiex +p' > /sys/kernel/debug/dynamic_debug/control
rm -f $EXTENDED_LOG_FILE
nohup /bin/sh -c 'while true; do date >> $EXTENDED_LOG_FILE; dmesg -c >> $EXTENDED_LOG_FILE; sleep 1; done &'
"

# BS 2
DEV6_IP="192.168.128.86"
DEV6_SERIAL="93297"
DEV6_POWER_URL="http://${USRPWD}@${SWITCH_IP}/set.cmd?cmd=setpower+p62="
DEV6_INIT_SCRIPT="
echo -n 'module mwifiex_usb +p' > /sys/kernel/debug/dynamic_debug/control
echo -n 'module mwifiex +p' > /sys/kernel/debug/dynamic_debug/control
rm -f $EXTENDED_LOG_FILE
nohup /bin/sh -c 'while true; do date >> $EXTENDED_LOG_FILE; dmesg -c >> $EXTENDED_LOG_FILE; sleep 1; done &'
"

# Beolab 50
DEV7_IP="192.168.128.193"
DEV7_SERIAL="BEOLAB 50"
DEV7_POWER_URL=""
DEV7_INIT_SCRIPT=""
DEV7_DISABLE_BNR=yes
DEV7_DISABLE_BONJOUR=yes


DEVS=7
let ATTEMPT=1

function enable_router() {
	echo "Enable router ..."
	curl "http://"${USRPWD}"@"${SWITCH_IP}"/set.cmd?cmd=setpower+p64=1"
	if [ $? -ne 0 ]; then
		echo "Error communicating with power switch @ $SWITCH_IP"
		exit 1
	fi
}

function disable_router() {
	echo "Disable router ..."
	curl "http://"${USRPWD}"@"${SWITCH_IP}"/set.cmd?cmd=setpower+p64=0"
	if [ $? -ne 0 ]; then
		echo "Error communicating with power switch @ $SWITCH_IP"
		exit 1
	fi
}

function setup_product_env() {
	POWER_URL_CMD="DEV${1}_POWER_URL"
	ENABLED_CMD="DEV${1}_ENABLED"
	DEV_IP_CMD="DEV${1}_IP"
	DEV_SERIAL_CMD="DEV${1}_SERIAL"
	DEV_INIT_CMD="DEV${1}_INIT_SCRIPT"
	DEV_DISABLE_BNR_CMD="DEV${1}_DISABLE_BNR"
	DEV_DISABLE_BONJOUR_CMD="DEV${1}_DISABLE_BONJOUR"
	POWER_URL="${!POWER_URL_CMD}"
	ENABLED="${!ENABLED_CMD}"
	DEV_IP="${!DEV_IP_CMD}"
	DEV_SERIAL="${!DEV_SERIAL_CMD}"
	DEV_INIT_SCRIPT="${!DEV_INIT_CMD}"
	DEV_DISBALE_BNR="${!DEV_DISABLE_BNR_CMD}"
	DEV_DISABLE_BONJOUR="${!DEV_DISABLE_BONJOUR_CMD}"
}

function enable_product() {
	setup_product_env $1
	eval ${ENABLED_CMD}=true
	if [ -n "$POWER_URL" ]; then
		echo "Enabling product: $1"
		curl "${POWER_URL}1"
		if [ $? -ne 0 ]; then
			echo "Error enabling product $1"
			exit 1
		fi
	fi
}

function disable_product() {
	setup_product_env $1
	eval ${ENABLED_CMD}=false
	if [ -n "$POWER_URL" ]; then
		echo "Disabling product: $1"
		curl "${POWER_URL}0"
		if [ $? -ne 0 ]; then
			echo "Error disabling product $1"
			exit 1
		fi
	fi
}

i=2
for ip in $DEV2_IP $DEV3_IP $DEV4_IP; do
#	curl "http://${DEV_IP}${LOG_REPORT_URL}"
	scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@${ip}:$EXTENDED_LOG_FILE ${i}_$(basename $EXTENDED_LOG_FILE)
	scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@${ip}:/media/settings/logs/messages ${i}_messages
	scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@${ip}:/media/settings/logs/log-nSDK ${i}_log-nSDK
	i=$(( i + 1 ))
done
