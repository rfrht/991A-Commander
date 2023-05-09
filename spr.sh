#!/bin/bash 

# Thanks to Gil Kloepfer (KI5BPK) for the hard work mapping the
# FT-991/A address space - and troubleshooting my code!

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

# High and low address parts
ADL=0x${1:0:2}
ADH=0x${1:2:2}

# Translate to binary ADL and ADH
BADL=$(encode $ADL)
BADH=$(encode $ADH)

# Encode the checksum - And strip out the exceeding character in checksum sum
# Avoided the bitwise AND operation because Shell endinanness is not compatible.
# Sum High, Low and Magic
CHECK=$(( $ADH + $ADL + 0xf5 ))

# Convert it to Hex
CHECK=$(echo "obase=16; $CHECK" | bc)

# Remove the trailing character
CHECK=$(encode ${CHECK:1})

# The final stream
STRING="SPR$BADL$BADH$CHECK;"

echo -n $STRING > /dev/ttyUSB0;

echo -n $STRING | hexdump -C
