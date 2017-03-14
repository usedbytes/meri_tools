#!/bin/sh

if [ $# -ne 1 ]
then
	echo "Usage: $0 image" | cat >&2
	exit 1
fi

HASH=$(dd if=$1 bs=1 count=32 skip=576 2>/dev/null | xxd -g32 -c32 -p)
echo "0x${HASH}"
