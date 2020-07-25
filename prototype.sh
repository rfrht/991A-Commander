#!/bin/bash
DEVICE=/dev/ttyUSB0

serial_config(){
	# Bail out if there was a failed attempt after turning on the radio
	if [ $RETRY == 1 ] 2>/dev/null ; then
		echo "After waking up the radio, it is still not responding. Ending."
		exit 1
	fi

	# Identify the serial port
	echo "Configuring Serial Port & waking up the radio"
	DEVICE=$(for sysdevpath in $(find /sys/bus/usb/devices/usb*/ -name dev); do \
		(syspath="${sysdevpath%/dev}" ; devname="$(udevadm info -q name -p $syspath)" ; \
		[[ "$devname" == "bus/"* ]] && continue ; eval "$(udevadm info -q property --export -p $syspath)" ; \
		[[ -z "$ID_SERIAL" ]] && continue ; echo "/dev/$devname - $ID_SERIAL" ; ) ; \
		done | grep -m 1 CP2105 | awk '{print $1}')

	# Case no device is found...
	if [ -z $DEVICE ] ; then
	   echo "FT-991A not connected"
   	   exit 1
	fi

	echo "Identified device $DEVICE"

	# Set port speed
	if ! stty -F $DEVICE 38400 ; then
		echo "Failed to configure port, retrying in 20s" 
		sleep 20
		if ! stty -F $DEVICE 38400 ; then
			echo "Failed to config serial port"
			exit 1
		fi
	else
	# Check for power state
		send_silent PS
		sleep 1
		send_command PS
		if [ ${OUTPUT:2} != 1 ] ; then 
			echo "Waking up the radio..."
			send_silent PS1
			RETRY=1
			sleep 7
		fi
	# Sync radio clock
	echo "Configuring radio Clock"
	DATE=$(TZ=UTC date +"%Y%m%d")
	TIME=$(TZ=UTC date +"%H%M%S")
	send_silent DT0$DATE
	send_silent DT1$TIME
	sleep 2
	fi
}

print_error() {
	echo -n "$(tput setab 7)$(tput setaf 1) $@ $(tput sgr0)"
}

send_silent() {
	echo -n "$1;" > $DEVICE
}

send_command() {
	echo -n "$1;" > $DEVICE &
	read -t 1 -d ';' OUTPUT < $DEVICE || serial_config
}

dump_chan_memory() {
	send_silent MC001

	if [ -e /dev/shm/ft991a-channel-dump.txt ] ; then
		rm -f /dev/shm/ft991a-channel-dump.txt || exit 1
	fi

	echo "Dumping memories; takes a while."

	for i in {001..117} ; do 
		echo -n "MT$i;" > $DEVICE & read -t 0.1 -N 41  OUTPUT < $DEVICE
		echo -n "$OUTPUT" | sed -e "s/MT001/MT$i/g" >> /dev/shm/ft991a-channel-dump.txt
	done

	echo "Dumped memories in /dev/shm/ft991a-channel-dump.txt"
}

dump_config() {
	if [ -e /dev/shm/ft991a-config.txt ] ; then
		rm -f /dev/shm/ft991a-config.txt || exit 1
	fi

	echo "Dumping config in /dev/shm/ft991a-config.txt"

	for i in {001..153} ; do 
		echo -n "EX$i;" > $DEVICE & read -t 0.1 -d ';'  OUTPUT < $DEVICE
		echo "$OUTPUT;" >> /dev/shm/ft991a-config.txt
	done

	echo "Dumped config in /dev/shm/ft991a-config.txt"
}

restore_memories() {
	if [ ! -r /dev/shm/ft991a-channel-dump.txt ] ; then
		echo "Could not find/read the /dev/shm/ft991a-channel-dump.txt file"
		exit 1
	fi

	cat /dev/shm/ft991a-channel-dump.txt > $DEVICE

	echo "Memories loaded."
}

restore_config() {
        if [ ! -r /dev/shm/ft991a-config.txt ] ; then
                echo "Could not find/read the /dev/shm/ft991a-config.txt file"
                exit 1
        fi

	for i in $(cat /dev/shm/ft991a-config.txt) ; do
		echo -n $i > $DEVICE
		sleep 0.1
	done

	echo "Configuration loaded."
}

get_ptt() {
	send_command RIA ; XMIT_STATE=${OUTPUT:3}
	case $XMIT_STATE in
	0) send_command BY
		case ${OUTPUT:2:1} in
		0) ST_RADIO=Squelched ; LAST_RADIO=Squelched ;;
		1) ST_RADIO=RX
		   if [ ! $LAST_RADIO == "RX" ] 2>/dev/null; then
		      TIMER_ON=0
		   fi
	      LAST_RADIO=RX ;;
		esac ;;
	1) ST_RADIO=TX 
	   if [ ! $LAST_RADIO == "TX" ] 2>/dev/null; then
	      TIMER_ON=0
	   fi
	   LAST_RADIO=TX ;;
	esac
}

get_qrg() {
	send_command IF
	ST_MCHAN=${OUTPUT:2:3}
	ST_VFOA=${OUTPUT:5:9}
	ST_CLAR=${OUTPUT:14:5}
	ST_RX_CLAR=${OUTPUT:19:1}
	ST_RADIO_CLAR=${OUTPUT:20:1}
	ST_MODE_ID=${OUTPUT:21:1}
	ST_RX_SRC_ID=${OUTPUT:22:1}
	ST_TONE_ID=${OUTPUT:23:1}
	ST_RX_SHIFT_ID=${OUTPUT:26:1}

	case $ST_RX_SHIFT_ID in
	0) ST_RX_SHIFT_TYPE=Simplex ;;	1) ST_RX_SHIFT_TYPE="+" ;;
	2) ST_RX_SHIFT_TYPE="-" ;;
	esac

	case $ST_TONE_ID in
	0) ST_TONE_TYPE=Off ;;		1) ST_TONE_TYPE="Tone Enc/Dec" ;;
	2) ST_TONE_TYPE="Tone Enc" ;;	3) ST_TONE_TYPE="DCS Enc/Dec" ;;
	4) ST_TONE_TYPE="DCS Enc" ;;
	esac

	case $ST_RX_SRC_ID in
	0) ST_VFO_SOURCE=VFO ;;	1) ST_VFO_SOURCE=Memory ;;
	2) ST_VFO_SOURCE=M-Tune ;;	3) ST_VFO_SOURCE=QMB ;;
	4) ST_VFO_SOURCE=QMB-M-Tune ;;	5) ST_VFO_SOURCE=PMS ;;
	6) ST_VFO_SOURCE=Home ;;
	esac

	case $ST_MODE_ID in
	1) ST_MODE=LSB ;;	2) ST_MODE=USB ;;	3) ST_MODE=CW ;;
	4) ST_MODE=FM ;;	5) ST_MODE=AM ;;	6) ST_MODE=RTTY-LSB ;;
	7) ST_MODE=CW-R ;;	8) ST_MODE=DATA-LSB ;;	9) ST_MODE=RTTY-USB ;;
	A) ST_MODE=DATA-FM ;;	B) ST_MODE=FM-N ;;	C) ST_MODE=DATA-USB ;;
	D) ST_MODE=AM-N ;;	E) ST_MODE=C4FM ;;
	esac

	send_command LK
	case ${OUTPUT:2} in
	0) ST_LOCK=Unlocked ;;	1) ST_LOCK=Locked
	esac

	case $ST_RX_SRC_ID in 1) 
	send_command MT$ST_MCHAN ; ST_MTAG=${OUTPUT:28} ;;
	esac
}

get_txpower() {
	send_command PC ; TX_POWER=${OUTPUT:3}
}

get_smeter() {
	send_command SM0 ; ST_SMETER=${OUTPUT:3}
}


check_swr() {
	send_command RI0
	if [ $OUTPUT == "RI01" ] ; then
		# Drop maximum power to 5W
		send_silent PC005
		SWR_STATE=HIGH
	else
		SWR_STATE=NOMINAL
	fi
}

get_txdata() {
	send_command RM3 ; ST_COMP=${OUTPUT:3}
	send_command RM4 ; ST_ALC=${OUTPUT:3}
	send_command RM5 ; ST_PO=${OUTPUT:3}
	send_command RM6 ; ST_SWR=${OUTPUT:3}
	send_command RM7 ; ST_IDD=${OUTPUT:3}
	send_command RM8 ; ST_VDD=${OUTPUT:3}
}

get_timer() {
	if [[ $TIMER_ON == 0 || -z $TIMER_ON ]] ; then
		TIMER_ON=$(/usr/bin/date +%s)
	fi
	NOW=$(date +%s)
	TIMER=$(date -u -d @$(($NOW-$TIMER_ON)) +%T)
}

print_header(){
	echo "Source VFO: $ST_VFO_SOURCE | QRG: $(echo $ST_VFOA | numfmt  --suffix=Hz --grouping) | Mode: $ST_MODE | State: $ST_RADIO"
	if [[ $ST_TONE_ID != 0 && $ST_MODE_ID == 4 ]] ; then
		 echo -n "Tone/DCS: $ST_TONE_TYPE | RPT Shift: $ST_RX_SHIFT_TYPE "
	fi
	if [ $ST_RX_SRC_ID == 1 ] 2>/dev/null ; then 
		echo "| Memory: $ST_MCHAN | Name: $ST_MTAG"
	fi
	echo "VFO Lock: $ST_LOCK | Clarifier: $ST_CLAR | RX Clar: $ST_RX_CLAR | TX Clar: $ST_RADIO_CLAR"
}

print_rx(){
	clear
	print_header
	echo -n "S-meter: $ST_SMETER"
}

print_tx(){
	clear
	print_header
	echo "Compressor: $ST_COMP | ALC: $ST_ALC | Power Output: $ST_PO | VSWR: $ST_SWR | IDD: $ST_IDD | VDD: $ST_VDD"
	if [ $SWR_STATE == "HIGH" ] ; then 
		print_error HIGH SWR
	fi
	echo -n "TX Power: $TX_POWER W"
}

print_timer(){
	echo " | $ST_RADIO time: $TIMER"
}

case $1 in
	--backup)
	dump_chan_memory
	dump_config
	exit 0
	;;

	--restore)
	restore_memories
	restore_config
	exit 0
	;;
esac

while true ; do
	case $1 in
		--smeter)
		get_ptt
		if [ $XMIT_STATE == 0 ] 2>/dev/null ; then
			get_smeter
			echo $((10#$ST_SMETER*100/190))
			echo "# S-Meter"
		else
			get_txdata
			echo $ST_SWR
			echo "# SWR"
		fi
		sleep .4
	;;

	*)
	get_ptt

	if [ $ST_RADIO != "TX" ] 2>/dev/null ; then
		get_qrg
		get_smeter
		if [ $ST_RADIO == "RX" ] ; then
			get_timer
			print_rx
			print_timer
		else
			print_rx
		fi
	else
		get_qrg
		get_txpower
		get_txdata
		get_timer
		check_swr
		print_tx
		print_timer
	fi
	sleep 0.4
	;;
	esac
done
