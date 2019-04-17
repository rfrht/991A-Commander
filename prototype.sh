#!/bin/bash
DEVICE=/dev/ttyUSB0

config_device(){
	DEVICE=$(for sysdevpath in $(find /sys/bus/usb/devices/usb*/ -name dev); do \
		(syspath="${sysdevpath%/dev}" ; devname="$(udevadm info -q name -p $syspath)" ; \
		[[ "$devname" == "bus/"* ]] && continue ; eval "$(udevadm info -q property --export -p $syspath)" ; \
		[[ -z "$ID_SERIAL" ]] && continue ; echo "/dev/$devname - $ID_SERIAL" ; ) ; \
		done | grep -m 1 CP2105 | awk '{print $1}')

	if [ -z $DEVICE ] ; then
	   echo "FT-991A not connected"
   	   exit 1
	fi

stty -F $DEVICE 38400
}


send_command() {
	echo -n "$1;" > $DEVICE &
	read -d ';' OUTPUT <$DEVICE
}

get_ptt() {
	send_command TX
	XMIT_STATE=${OUTPUT:2}
}

get_qrg() {
	send_command IF
	ST_MCHAN=${OUTPUT:2:3}
	ST_VFOA=${OUTPUT:5:9}
	ST_CLAR=${OUTPUT:14:5}
	ST_RX_CLAR=${OUTPUT:19:1}
	ST_TX_CLAR=${OUTPUT:20:1}
	ST_MODE_ID=${OUTPUT:21:1}
	ST_RX_SRC_ID=${OUTPUT:22:1}
	ST_TONE_ID=${OUTPUT:23:1}
	ST_SHIFT_ID=${OUTPUT:26:1}
	case $ST_SHIFT_ID in
		0)
			ST_SHIFT_TYPE=Simplex
		;;
		1)
			ST_SHIFT_TYPE="+"
		;;
		2)
			ST_SHIFT_TYPE="-"
		;;
	esac
	case $ST_TONE_ID in
		0)
			ST_TONE_TYPE=Off
		;;
		1)
			ST_TONE_TYPE="Tone Enc/Dec"
		;;
		2)
			ST_TONE_TYPE="Tone Enc"
		;;
		3)
			ST_TONE_TYPE="DCS Enc/Dec"
		;;
		4)
			ST_TONE_TYPE="DCS Enc"
		;;
	esac

	case $ST_RX_SRC_ID in
		0)
			ST_VFO_SOURCE=VFO
		;;
		1)
			ST_VFO_SOURCE=Memory
		;;
		2)
			ST_VFO_SOURCE=M-Tune
		;;
		3)
			ST_VFO_SOURCE=QMB
		;;
		4)
			ST_VFO_SOURCE=QMB-M-Tune
		;;
		5)
			ST_VFO_SOURCE=PMS
		;;
		6)
			ST_VFO_SOURCE=Home
		;;
	esac

	case $ST_MODE_ID in
		1)
			ST_MODE=LSB
		;;
		2)
			ST_MODE=USB
		;;
		3)
			ST_MODE=CW
		;;
		4)
			ST_MODE=FM
		;;
		5)
			ST_MODE=AM
		;;
		6)
			ST_MODE=RTTY-LSB
		;;
		7)
			ST_MODE=CW-R
		;;
		8)
			ST_MODE=DATA-LSB
		;;
		9)
			ST_MODE=RTTY-USB
		;;
		A)
			ST_MODE=DATA-FM
		;;
		B)
			ST_MODE=FM-N
		;;
		C)
			ST_MODE=DATA-USB
		;;
		D)
			ST_MODE=AM-M
		;;
		E)
			ST_MODE=C4FM
		;;
		esac
	echo "Source VFO: $ST_VFO_SOURCE | QRG: $(echo $ST_VFOA | numfmt  --suffix=Hz --grouping) | $(if [ $ST_RX_SRC_ID == 1 ] ; then echo Memory: $ST_MCHAN \|; fi) Mode: $ST_MODE "
	echo "Clarifier: $ST_CLAR | RX Clar: $ST_RX_CLAR | TX Clar: $ST_TX_CLAR | Tone/DCS: $ST_TONE_TYPE | Shift: $ST_SHIFT_TYPE"
}

get_smeter() {
	send_command SM0
	ST_SMETER=${OUTPUT:3}
	echo "S-meter: $ST_SMETER"
}

get_txdata() {
	send_command RM3
	ST_COMP=${OUTPUT:3}
	send_command RM4
	ST_ALC=${OUTPUT:3}
	send_command RM5
	ST_PO=${OUTPUT:3}
	send_command RM6
	ST_SWR=${OUTPUT:3}
	send_command RM7
	ST_IDD=${OUTPUT:3}
	send_command RM8
	ST_VDD=${OUTPUT:3}
	echo "Compressor: $ST_COMP | ALC: $ST_ALC | Power Output: $ST_PO | VSWR: $ST_SWR | IDD: $ST_IDD | VDD: $ST_VDD"
}

while true ; do
	clear
	get_ptt

	if [ $XMIT_STATE == 0 ] ; then
		get_qrg
		get_smeter
	else
		get_qrg
		get_txdata
	fi
	sleep .4
done

