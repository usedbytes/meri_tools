#!/bin/bash
#
# Script to root the Xiaomi Mi 5c, by manually installing SuperSU
#
# Copyright 2017 Brian Starkey <stark3y@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
# -- Disclaimer
#
# Obviously modifying your phone can be dangerous, void the warranty etc. etc.
# Use this script and the instructions within it at your own risk.
#
# -- Description
#
# The SuperSU installer seems to assume you already have root, and is intended
# to be run from a custom recovery (like TWRP). We don't have that, so we'll do
# some funny dances to do a systemless root without having root to begin with.
#
# The crux of the matter is using SuperSU's tools to patch the ramdisk and
# sepolciy (in /data/local/tmp, without root), then building a ramdisk with
# those components
#
# -- Usage
#
# Plug in the phone, make sure you have (persistent) adb debugging permissions
# and run this script like so:
#   meri_root.sh SUPERSU_DIR ROM_DIR
# Where SUPERSU_DIR is a directory where you have downloaded and extracted the
# SuperSU "Recovery Flashable" zip file: http://www.supersu.com/download
# and ROM_DIR is a directory where you have downloaded and extracted the ROM
# from Xiaomi's download page: http://en.miui.com/download-322.html
#
# The script will make and boot a boot.img which enacts a systemless root.
# To make it persisent, you must flash it instead:
#    fastboot flash boot.supersu.img
#
# By default, SuperSU removes dm-verity from /system and encryption from /data
# To prevent this, set PRESERVE_VERITY=1 before running the script:
#   PRESERVE_VERITY=1 ./meri_root.sh ...

if [ $# -ne 2 ];
then
	cat >&2 <<EOM
Usage: $(basename $0) SUPERSU_DIR ROM_DIR
   Extract SuperSU zip file into SUPERSU_DIR, and the Xiaomi ROM into ROM_DIR,
   then run this script.
EOM
	exit 1
fi

SUPERSU_DIR=$1
echo ${SUPERSU_DIR}/arm64/su
if [ ! -f ${SUPERSU_DIR}/arm64/su ]
then
	echo "Invalid SUPERSU_DIR" >&2
	exit 1
fi

ROM_DIR=$2
if [ ! -f ${ROM_DIR}/boot.img ]
then
	echo "Invalid ROM_DIR" >&2
	exit 1
fi

# 1. Get mkbootimg and build it
git clone --depth 1 https://github.com/osm0sis/mkbootimg.git || exit 1
cd mkbootimg
make || ( cd .. && exit 1 )
cd ..

# 2. Copy the SuperSU binaries to the device
echo "Waiting for device..."
adb wait-for-usb-device
adb push ${SUPERSU_DIR}/arm64/*su* /data/local/tmp/ || exit 1
adb shell chmod +x /data/local/tmp/su*

# 3. Create the SuperSU systemless root image
#    Ideally we'd set up security contexts too, but then you need to be running
#    on an SELinux-enabled kernel in permissive mode.
#    Instead, we will fix it on first boot.
dd if=/dev/zero bs=1M count=96 of=su.img
mkfs.ext4 su.img
mkdir mnt
sudo mount su.img mnt

sudo mkdir mnt/{bin,xbin,lib,etc,su.d}
sudo chmod 0751 mnt/bin
sudo chmod 0755 mnt/{xbin,lib,etc}
sudo chmod 0700 mnt/su.d

sudo cp ${SUPERSU_DIR}/arm64/{su,sukernel} mnt/bin/
sudo cp ${SUPERSU_DIR}/arm64/su mnt/bin/daemonsu
sudo cp ${SUPERSU_DIR}/arm64/supolicy mnt/bin/supolicy_wrapped
sudo ln -s /su/bin/su mnt/bin/supolicy
sudo chown root:root mnt/bin/{su,daemonsu,sukernel,supolicy_wrapped}
sudo chmod 0755 mnt/bin/{su,daemonsu,sukernel,supolicy_wrapped}

sudo cp ${SUPERSU_DIR}/arm64/libsupol.so mnt/lib/libsupol.so
sudo chown root:root mnt/lib/libsupol.so
sudo chmod 0644 mnt/lib/libsupol.so

sync
sudo umount mnt

# 4. Copy the systemless root image to the device
adb push su.img /data/local/tmp/su.img

# 5. Extract boot.img
mkdir bootimg
mkbootimg/unpackbootimg -o bootimg -i ${ROM_DIR}/boot.img

# 6. Unzip the ramdisk
cat bootimg/boot.img-ramdisk.gz | gunzip > ramdisk

# 7. Copy the ramdisk to the device, for patching
adb push ramdisk /data/local/tmp

# 8. Patch sepolicy and the ramdisk, using the SuperSU tools we copied over
#    earlier
adb shell "
cd /data/local/tmp
LD_LIBRARY_PATH=. ./supolicy --file /sepolicy ./sepolicy.patched
LD_LIBRARY_PATH=. ./sukernel --patch ./ramdisk ramdisk.patched
"

# 9. Pull back the patched files
adb pull /data/local/tmp/sepolicy.patched /data/local/tmp/ramdisk.patched .

# 10. Extract the patched ramdisk, and install the patched sepolicy into it
mkdir ramdir
cat ramdisk.patched | sudo cpio --no-absolute-filenames -D ramdir -i
sudo cp sepolicy.patched ramdir/sepolicy
sudo chown root:root ramdir/sepolicy
sudo chmod 0644 ramdir/sepolicy

# 11. Install the SuperSU init scripts
sudo mkdir ramdir/su
sudo chmod 755 ramdir/su
sudo cp ${SUPERSU_DIR}/common/launch_daemonsu.sh ramdir/sbin
sudo chmod 744 ramdir/sbin/launch_daemonsu.sh
sudo chown root:root ramdir/sbin/launch_daemonsu.sh
sudo cp ${SUPERSU_DIR}/common/init.supersu.rc ramdir
sudo chmod 750 ramdir/init.supersu.rc
sudo chown root:root ramdir/init.supersu.rc

# 12. Patch the initscript for our img location and set the su.img context
sudo sed -i 's;/data/su.img;/data/local/tmp/su.img;' ramdir/init.supersu.rc
sudo bash -c "echo /data/local/tmp/su.img u:object_r:system_data_file:s0 >> ramdir/file_contexts"

# Optional: Preserve dm-verity on /system, encryption on /data
if [ ! -z "$PRESERVE_VERITY" ] && [ $PRESERVE_VERITY -ne 0 ]
then
	echo "Preserving dm-verity"
	mkdir ramdir-stock
	cat ramdisk | sudo cpio --no-absolute-filenames -D ramdir-stock -i
	sudo cp ramdir-stock/{fstab.song,verity_key} ramdir/
	sudo rm -rf ramdir-stock
fi

# 13. Repack the ramdisk
cd ramdir
sudo find . ! -path . | sudo cpio -H newc -o | gzip > ../ramdisk.gz
cd ..

# 14. Repack the boot image
mkbootimg/mkbootimg \
    --kernel bootimg/boot.img-zImage \
    --ramdisk ramdisk.gz \
    --cmdline "console=ttyS0,115200 earlyprintk=uart8250-32bit,0xF900B000 androidboot.hardware=song no_console_suspend debug user_debug=31 loglevel=8" \
    --base 0x0 \
    --pagesize 4096 \
    --kernel_offset 0x0a080000 \
    --ramdisk_offset 0x0c400000 \
    --dt bootimg/boot.img-dtb \
    --tags_offset 0xc200000 \
    --os_version 0.0.0 \
    --os_patch_level 0 \
    --second_offset 0x00f00000 \
    --hash sha256 \
    --id \
    -o boot.supersu.img

# 15. Boot it! (flash it if you want to make it persistent)
adb reboot-bootloader
fastboot boot boot.supersu.img

# 16. We need to chcon the su.img files on the first boot. Luckily we can use
#     the 'su' we installed into /data/local/tmp earlier
echo "Waiting for device..."
adb wait-for-usb-device
sleep 5
adb shell "
/data/local/tmp/su -c 'chcon -R u:object_r:system_data_file:s0 /su /data/local/tmp/su.img && sync'
"

