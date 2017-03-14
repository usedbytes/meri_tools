#!/bin/sh

if [ $# -lt 3 ]
then
	echo "Usage: $0 kernel ramdisk dtb [outfile]" | cat >&2
	exit 1
fi

if [ $# -eq 4 ]
then
	OUT="$4"
else
	OUT="boot.img"
fi

echo "Creating ${OUT}"

mkbootimg \
    --kernel $1 \
    --ramdisk $2 \
    --cmdline "console=ttyS0,115200 earlyprintk=uart8250-32bit,0xF900B000 androidboot.hardware=song no_console_suspend debug user_debug=31 loglevel=8" \
    --base 0x0 \
    --pagesize 4096 \
    --kernel_offset 0x0a080000 \
    --ramdisk_offset 0x0c400000 \
    --dt $3 \
    --tags_offset 0xc200000 \
    --os_version 0.0.0 \
    --os_patch_level 0 \
    --second_offset 0x00f00000 \
    --id \
    -o ${OUT}
