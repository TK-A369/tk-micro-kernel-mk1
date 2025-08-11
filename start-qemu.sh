#!/usr/bin/sh

# qemu-system-i386 \
# 	-drive file=image.img,format=raw,id=hd0 \
# 	-bios /usr/share/ovmf/ia32/OVMF.4m.fd \
# 	-nographic
qemu-system-i386 \
 	-drive file=image.img,format=raw,id=hd0 \
	-bios /usr/share/ovmf/ia32/OVMF.4m.fd
