#!/bin/sh

if [ $# -ne 2 ]
then
	echo "Usage: $0 dir outfile.gz" | cat >&2
	exit 1
fi

cd $1 || exit 1
sudo find . ! -path . | sed 's;^./;;g' | sudo cpio -o -H newc | gzip -9 > $2
cd -
