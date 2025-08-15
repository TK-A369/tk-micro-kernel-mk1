#!/usr/bin/sh

EXEC_NAME=$0

QEMU_ARGS="-drive file=image.img,format=raw,id=hd0"
QEMU_ARGS="${QEMU_ARGS} -bios /usr/share/ovmf/x64/OVMF.4m.fd"

# echo "\$\# = $#"
while [ "$#" -ge 1 ]; do
	if [ "$1" = "-h" ]; then
		echo " -h - help"
		echo " -ng - without graphics"
		echo " -gdb - start GDB server"
		exit 0
	elif [ "$1" = "-ng" ]; then
		QEMU_ARGS="${QEMU_ARGS} -nographic"
	elif [ "$1" = "-gdb" ]; then
		QEMU_ARGS="${QEMU_ARGS} -s -S"
	else
		echo "Unrecognized argument \"$1\""
		echo "Run \"$EXEC_NAME -h\" to get help"
		exit 1
	fi
	shift
done

echo "QEMU args: $QEMU_ARGS"

# qemu-system-i386 \
# 	-drive file=image.img,format=raw,id=hd0 \
# 	-bios /usr/share/ovmf/ia32/OVMF.4m.fd \
# 	-nographic
# qemu-system-x86_64 \
#  	-drive file=image.img,format=raw,id=hd0 \
# 	-bios /usr/share/ovmf/x64/OVMF.4m.fd

echo "$QEMU_ARGS" | xargs -o qemu-system-x86_64
