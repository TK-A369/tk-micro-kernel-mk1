const std = @import("std");

export var tss = std.mem.zeroes([25]u32);

const Gdtr = packed struct {
    limit: u16,
    base: u64,
};

export var gdt = [7]u64{
    0x0000000000000000, //Null descriptor
    (0xf << 48) | (0xffff << 0) | (0x9a << 40) | (0xc << 52), //Kernel mode code seg
    (0xf << 48) | (0xffff << 0) | (0x92 << 40) | (0xc << 52), //Kernel mode data seg
    (0xf << 48) | (0xffff << 0) | (0xfa << 40) | (0xc << 52), //User mode code seg
    (0xf << 48) | (0xffff << 0) | (0xf2 << 40) | (0xc << 52), //User mode data seg
    0, //Task State Segment (lower half) - will be set at runtime
    0, //Task State Segment (higher half) - will be set at runtime
};

pub fn setup_gdt() void {
    gdt[5] = ((@intFromPtr(&tss) & 0xffffff) >> 0 << 16) | ((@intFromPtr(&tss) & 0xff000000) >> 24 << 56) | (((@sizeOf(@TypeOf(tss)) - 1) & 0xf0000) >> 16 << 48) | (((@as(u64, @sizeOf(@TypeOf(tss))) - 1) & 0xffff) >> 0 << 0) | (0x89 << 40) | (0x0 << 52);
    gdt[6] = ((@intFromPtr(&tss) & 0xffffffff00000000) << 0);
    asm volatile ("cli" ::: .{});
    const gdtr = Gdtr{
        .limit = @sizeOf(@TypeOf(gdt)),
        .base = @intFromPtr(&gdt),
    };
    asm volatile ("lgdt (%[gdtr_ptr])"
        :
        : [gdtr_ptr] "{rax}" (&gdtr),
        : .{});

    // Reload the segment selectors
    asm volatile (
        \\push 0x08
        \\leaq .reload_CS(%rip), %rax
        \\push %rax
        \\lretq
        \\.reload_CS:
        \\mov 0x10, %ax
        \\mov %ax, %ds
        \\mov %ax, %es
        \\mov %ax, %fs
        \\mov %ax, %gs
        \\mov %ax, %ss
        \\ret
        ::: .{
            .rax = true,
        });
}
