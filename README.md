# meri_tools

A set of simple tools for working with the Xiaomi Mi 5c

## meri_root.sh

Script to root the phone using SuperSU. It basically does the install process
that SuperSU would normally do from TWRP (or similar) without needing root
to start with.

To use it, download the SuperSU "Recovery Flashable" zip, and extract it
somewhere (SUPERSU_DIR): http://www.supersu.com/download
Also download a stock ROM from Xiaomi, and extract it somewhere (ROM_DIR):
http://en.miui.com/download-322.html

Then, plug in the phone, make sure you have adb debugging permissions, and run
the script:
```
meri_root.sh SUPERSU_DIR ROM_DIR
```

It will build mkbootimg, do a bunch of stuff over adb, then eventually reboot
the phone with a boot.img that gives you root.
If you want the root to ber persistent, you need to flash the generated
boot.supersu.img - by default it just boots it without flashing it.

## meri_mkboot.sh

Just the appropriate command to create a boot.img for the Mi 5c with mkbootimg

## meri_mkramdisk.sh

Just the appropriate commands for creating a ramdisk for the Mi 5c

## meri_split-dtb.c

Compile with:
```
gcc -o meri_split-dtb meri_split-dtb.c
```

The Mi 5c device-tree in the boot image (boot.img-dtb) actually contains 12
different device-trees for different variants of the phone.

This tools just splits the monolithic blob into the separate trees.

The correct device-tree is selected by the bootloader before booting the kernel
based on the board-ids property.

You can find out what type of board you have like so:
```
adb shell cat /proc/device-tree/board-ids | xxd

```

My board is type "0xd 0xe":
```
$ adb shell cat /proc/device-tree/board-ids | xxd
00000000: 0000 000d 0000 000e                      ........
```

Each dtb can be decompiled as usual with dtc:
```
dtc -I dtb -O dts boot.img-dtb.2
```
