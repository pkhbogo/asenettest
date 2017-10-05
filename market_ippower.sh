#!/bin/bash
#
# vim:noet

USRPWD="admin:12345678"
SWITCH_IP="192.168.128.230"
LOG_REPORT_URL="/api/setData?path=BeoPortal%3AlogReport%2Fsend&roles=activate&value=%7B%22type%22%3A%22bool_%22%2C%22bool_%22%3Atrue%7D"
EXTENDED_LOG_FILE="/media/settings/logs/mwifiex_logs.txt"

# 
DEV1_IP="192.168.128.33"
DEV1_SERIAL="26560219"
DEV1_POWER_URL=""
DEV1_INIT_SCRIPT=""

# 
DEV2_IP="192.168.128.39"
DEV2_SERIAL="24859015"
DEV2_POWER_URL=""
DEV2_INIT_SCRIPT=""

# 
DEV3_IP="192.168.128.166"
DEV3_SERIAL="27482949"
DEV3_POWER_URL=""
DEV3_INIT_SCRIPT=""

DEVS=3
let ATTEMPT=1

function enable_router() {
	echo "Enable router ..."
	curl "http://"${USRPWD}"@"${SWITCH_IP}"/set.cmd?cmd=setpower+p61=1"
	if [ $? -ne 0 ]; then
		echo "Error communicating with power switch @ $SWITCH_IP"
		exit 1
	fi
}

function disable_router() {
	echo "Disable router ..."
	curl "http://"${USRPWD}"@"${SWITCH_IP}"/set.cmd?cmd=setpower+p61=0"
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
	POWER_URL="${!POWER_URL_CMD}"
	ENABLED="${!ENABLED_CMD}"
	DEV_IP="${!DEV_IP_CMD}"
	DEV_SERIAL="${!DEV_SERIAL_CMD}"
	DEV_INIT_SCRIPT="${!DEV_INIT_CMD}"
}

function enable_product() {
	setup_product_env $1
	echo "Enabling product: $1"
	eval ${ENABLED_CMD}=true
	if [ -n "$POWER_URL" ]; then
		curl "${POWER_URL}1"
		if [ $? -ne 0 ]; then
			echo "Error enabling product $1"
			exit 1
		fi
	fi
}

function disable_product() {
	setup_product_env $1
	echo "Disabling product: $1"
	eval ${ENABLED_CMD}=false
	if [ -n "$POWER_URL" ]; then
		curl "${POWER_URL}0"
		if [ $? -ne 0 ]; then
			echo "Error disabling product $1"
			exit 1
		fi
	fi
}

function runTest()
{
	setup_product_env $1
	if [ "$ENABLED" == "false" ]; then
		echo "Product $1 is disabled"
		return
	fi

	# Test ping
	echo "Ping dev1: ${DEV_IP}"
	ping -c5 -i5 "${DEV_IP}"
	if [ "$?" -ne 0 ]; then
		echo "Cannot ping"
		date
		disable_product $1
		return
	fi

	# Test Bonjour
	echo "Testing Bonjour..."
	beoremotes=$(avahi-browse -t _beoremote._tcp | grep "${DEV_SERIAL}" | wc -l)
	if [ $? -ne 0 ]; then
		echo "Failed when checking Bonjour"
		date
		disable_product $1
		return
	fi
	echo "Bonjour _beoremote._tcp nodes: $beoremotes"
	if [ $beoremotes -ne 1 ]; then
		echo "Not enough beoremotes"
		date
		disable_product $1
		return
	fi

	# Test BNR
	echo "Testing BNR..."
	nmap -p 8080 -PS "${DEV_IP}"
	if [ $? -ne 0 ]; then
		echo "BNR not responding"
		date
		disable_product $1
		return
	fi
}

function running() {
	for (( u = 1; u <= $DEVS; ++u )); do
		setup_product_env $u
		if [ "$ENABLED" == "true" ]; then
			echo 1
			return
		fi
	done
	echo 0
}

# Initialize products
enable_router
for (( i = 1; i <= $DEVS; ++i )); do
	disable_product $i
done
sleep 10
for (( i = 1; i <= $DEVS; ++i )); do
	enable_product $i
done
echo "Waiting until products are ready..."
sleep 120
for (( i = 1; i <= $DEVS; ++i )); do
	setup_product_env $i
	if [ -n "$DEV_INIT_SCRIPT" ]; then
		echo "Initializing product $i"
		ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@$DEV_IP "$DEV_INIT_SCRIPT"
		if [ $? -ne 0 ]; then
			echo "Failed initialization"
			exit 1
		fi
	fi
done

# Run tests
while [ $(running) -eq 1 ]; do
	echo "Attempts: ${ATTEMPT}"
	
	enable_router
	echo "Waiting until router is ready...."
	sleep 240
	date

	for (( i = 1; i <= $DEVS; ++i )); do
		echo "Testing device $i"
		runTest $i
	done

	disable_router
	sleep 10
	let ATTEMPT=ATTEMPT+1
done

# Submit logs and get the extended log
#for (( i = 1; i <= $DEVS; ++i )); do
#	enable_product $i
#done
#echo "Waiting until products are ready..."
#sleep 120
#for (( i = 1; i <= $DEVS; ++i )); do
#	setup_product_env $i
#	curl "http://${DEV_IP}${LOG_REPORT_URL}"
#	scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@${DEV_IP}:$EXTENDED_LOG_FILE ${i}_$(basename $EXTENDED_LOG_FILE)
#	scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@${DEV_IP}:/media/settings/logs/messages ${i}_messages
#	scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@${DEV_IP}:/media/settings/logs/log-nSDK ${i}_log-nSDK
#done


