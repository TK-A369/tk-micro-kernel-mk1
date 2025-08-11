#!/usr/bin/sh

dd if=/dev/zero bs=1M count=64 of=image.img

echo "Partitioning..."
sfdisk image.img <<SFDISK
label: gpt

start=1MiB, size=63MiB, bootable, type=U
SFDISK

echo "Formatting..."
mformat -F -i image.img@@1M

mmd -i image.img@@1M ::/EFI ::/EFI/BOOT ::/boot ::/boot/limine

if [ -z "$LIMINE_BIN_DIR" ]; then
	echo "Set LIMINE_BIN_DIR variable"
	exit 1
fi

echo "Copying to image..."
mcopy -i image.img@@1M ./kernel/zig-out/bin/tk_micro_kernel_mk1 ::/boot
mcopy -i image.img@@1M ./limine.conf ::/boot/limine
mcopy -i image.img@@1M "$LIMINE_BIN_DIR/BOOTIA32.EFI" ::/EFI/BOOT

echo "Done!"
