const std = @import("std");

const log = @import("log.zig");
const misc = @import("misc.zig");

export var idt = std.mem.zeroes([256]u128);

const IdtGateType = enum(u4) {
    Interrupt64 = 0b1110,
    Trap64 = 0b1111,
};

fn attach_isr(
    int_num: u8,
    isr: *const fn () callconv(.{ .x86_64_interrupt = .{ .incoming_stack_alignment = null } }) void,
    seg_sel: u16,
    gate_type: IdtGateType,
    dpl: u2,
) void {
    const isr_addr = @intFromPtr(isr);
    var entry: u128 = 0;
    entry |= @as(u128, isr_addr & 0xffff);
    entry |= @as(u128, seg_sel) << 16;
    // For now, IST (interrupt stack) is always zero - stack won't be switched
    entry |= @as(u128, @intFromEnum(gate_type)) << 40;
    entry |= @as(u128, dpl) << 45;
    entry |= @as(u128, ((isr_addr >> 16) & 0xffffffffffff)) << 48;
    idt[int_num] = entry;
}

const Idtr = extern struct {
    size: u16,
    addr: u64,
};

pub fn setup_interrupts() void {
    attach_isr(0x80, isr_80h, 1, .Interrupt64, 3);

    const idtr = Idtr{
        .size = 256 - 1,
        .addr = @intFromPtr(&idt),
    };
    asm volatile ("lidt (%[idtr_ptr])"
        :
        : [idtr_ptr] "{rax}" (&idtr),
        : .{});
}

fn isr_80h() callconv(.{ .x86_64_interrupt = .{ .incoming_stack_alignment = null } }) void {
    log.log_writer.print("Interrupt 0x80 is being handled!\n", .{}) catch {
        misc.hcf();
    };
}
