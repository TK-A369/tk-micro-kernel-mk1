#!/usr/bin/sh

# qemu-system-i386 \
# 	-drive file=image.img,format=raw,id=hd0 \
# 	-bios /usr/share/ovmf/ia32/OVMF.4m.fd \
# 	-nographic
qemu-system-x86_64 \
 	-drive file=image.img,format=raw,id=hd0 \
	-bios /usr/share/ovmf/x64/OVMF.4m.fd
