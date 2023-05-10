#!/bin/bash 

# Thanks to Gil Kloepfer (KI5BPK) for the hard work mapping the
# FT-991/A address space - and troubleshooting my code!
# For more information, visit https://www.kloepfer.org/ft991a/memory-map.txt

# Change these to meet your transceiver's config
SERIAL=/dev/ttyUSB0
SPEED=38400

if [ -z $1 ] ; then
  echo Inform address range
  exit 1
fi

if ! stty -ixon -F $SERIAL $SPEED; then
   echo "Failed to configure port"
   exit 1
fi

# Function to encode hex to binary
encode() {
echo -n "$1" | xxd -r -p
}

# Function to create the CAT SPR command to the radio
catstring() {
printf "SPR"
encode $ADL
encode $ADH
printf "$CHECK;"
}

# High and low address parts
ADL=0x${1:0:2}
ADH=0x${1:2:2}

# Encode the checksum - And strip out the exceeding character in checksum sum
# Avoided the bitwise AND operation because Shell endinanness is not compatible.
# Sum High, Low and Magic
CHECK=$(( $ADH + $ADL + 0xf5 ))

# Convert the Decimal value to Hexadecimal
CHECK=$(printf "%X" $CHECK)

# Encode the Checksum to binary, use only two least significant bytes
CHECK=$(encode ${CHECK:1})

catstring | hexdump -C
catstring > $SERIAL;
