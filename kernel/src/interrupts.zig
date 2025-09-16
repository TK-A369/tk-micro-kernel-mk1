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
    isr: *const anyopaque,
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
    entry |= @as(u128, 1) << 47; //Present bit
    entry |= @as(u128, ((isr_addr >> 16) & 0xffffffffffff)) << 48;
    idt[int_num] = entry;
}

const Idtr = packed struct {
    size: u16,
    addr: u64,
};

pub fn setup_interrupts() void {
    attach_isr(0x0d, isr_general_protection, 0x8, .Trap64, 0);
    attach_isr(0x0e, isr_page_fault, 0x8, .Trap64, 0);
    attach_isr(0x80, isr_80h, 0x8, .Interrupt64, 3);

    const idtr = Idtr{
        .size = @sizeOf(@TypeOf(idt)) - 1,
        .addr = @intFromPtr(&idt),
    };
    // Load the IDT and enable interrupts
    asm volatile (
        \\lidt (%[idtr_ptr])
        \\sti
        :
        : [idtr_ptr] "{rax}" (&idtr),
        : .{});
}

fn isr_general_protection() callconv(.{ .x86_64_interrupt = .{ .incoming_stack_alignment = null } }) void {
    log.log_writer.print("General protection fault!\n", .{}) catch {};
    misc.hcf();
}

fn isr_page_fault() callconv(.{ .x86_64_interrupt = .{ .incoming_stack_alignment = null } }) void {
    log.log_writer.print("Page fault!\n", .{}) catch {};
    misc.hcf();
}

// Here, we need to directly read the register, so I don't think we can set Zig's callconv to x86_64_interrupt
export fn isr_80h_inner(int_desc: u64) callconv(.{ .x86_64_sysv = .{ .incoming_stack_alignment = null } }) void {
    log.log_writer.print("Interrupt 0x80 is being handled! Descriptor: *0x{x:0>16}\n", .{int_desc}) catch {
        misc.hcf();
    };
}

fn isr_80h() callconv(.naked) void {
    // Read rax register content
    asm volatile (
        \\pushq %rax
        \\pushq %rbx
        \\pushq %rcx
        \\pushq %rdx
        \\pushq %rsi
        \\pushq %rdi
        \\pushq %rbp
        \\movq %%rax, %%rdi
        \\call isr_80h_inner
        \\popq %rbp
        \\popq %rdi
        \\popq %rsi
        \\popq %rdx
        \\popq %rcx
        \\popq %rbx
        \\popq %rax
        \\iretq
        ::: .{ .rax = true, .rdi = true });
}
