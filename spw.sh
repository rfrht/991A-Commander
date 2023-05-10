#!/bin/bash

# Thanks to Gil Kloepfer (KI5BPK) for the hard work mapping the
# FT-991/A address space - and troubleshooting my code!
# For more information, visit https://www.kloepfer.org/ft991a/memory-map.txt

if [ -z $IKNOWRIGHT ] ; then
  echo
  echo "THIS CAN ==AND WILL==  BRICK YOUR RADIO BEYOND REPAIR"
  echo
  echo "If you *really really* know what you are doing, move ahead"
  echo
  exit 1
fi

if [ -z $1 ] ; then
  echo "Inform address range (4-byte, cleartext hex)"
  exit 1
elif [ -z $2 ] ; then
  echo "Inform the data to be written (4-byte, cleartext hex)"
  echo "For more information visit:"
  echo "https://www.kloepfer.org/ft991a/memory-map.txt"
  exit 1
fi

SERIAL=/dev/ttyUSB0
SPEED=38400

if ! stty -ixon -F $SERIAL $SPEED; then
   echo "Failed to configure port"
   exit 1
fi


# Function to encode hex to binary
encode() {
printf "$1" | xxd -r -p
}

# High and low address parts
ADL=0x${1:0:2}
ADH=0x${1:2:2}
VALL=0x${2:0:2}
VALH=0x${2:2:2}

# Encode the checksum - And strip out the exceeding character in checksum sum
# Avoided the bitwise AND operation because Shell endinanness is not compatible.
# Sum High, Low and Magic
CHECK=$(( 0xfb + $ADH + $ADL + $VALH + $VALL + 0xff ))

# Convert the Decimal value to Hexadecimal
CHECK=$(printf "%X" $CHECK)

# Encode the Checksum to binary, use only two least significant bytes
CHECK=$(encode ${CHECK:1})

# The final stream
catstring() {
printf "SPW"
encode $ADL
encode $ADH
encode $VALL
encode $VALH
printf "$CHECK;"
}

catstring | hexdump -C
catstring > $SERIAL;
