const std = @import("std");
const limine = @cImport(@cInclude("limine.h"));

const log = @import("log.zig");

// See LIMINE_BASE_REVISION macro in limine.h
export var limine_base_revision linksection(".limine_requests") = [3]u64{
    0xf9562b2d5c95a6c8,
    0x6a7b384944536bdc,
    3,
};
export var limine_memmap_request linksection(".limine_requests") = limine.limine_memmap_request{
    .id = [4]u64{
        0xc7b1dd30df4c8b88,
        0x0a82e883a194f07b,
        0x67cf3d9d378a806f,
        0xe304acdfc50c3c62,
    },
    .revision = 0,
};
export var limine_hhdm_request linksection(".limine_requests") = limine.limine_hhdm_request{
    .id = [4]u64{
        0xc7b1dd30df4c8b88,
        0x0a82e883a194f07b,
        0x48dcf1cb8ad2b852,
        0x63984e959a98244b,
    },
    .revision = 0,
};
export var framebuffer_request linksection(".limine_requests") = limine.limine_framebuffer_request{
    .id = [4]u64{
        0xc7b1dd30df4c8b88,
        0x0a82e883a194f07b,
        0x9d5827dcd881dd75,
        0xa3148604f6fab11b,
    },
    .revision = 0,
};

export var limine_requests_start_marker linksection(".limine_requests_start") = [4]u64{
    0xf6b8f4b39de7d1ae,
    0xfab91a6940fcb9cf,
    0x785c6ed015d3e316,
    0x181e920a7852b9d9,
};
export var limine_requests_end_marker linksection(".limine_requests_end") = [2]u64{
    0xadc0e0531bb10d03,
    0x9572709f31764c62,
};

fn hcf() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub const panic = std.debug.FullPanic(myPanicHandler);

fn myPanicHandler(msg: []const u8, first_trace_addr: ?usize) noreturn {
    _ = msg;
    _ = first_trace_addr;
    hcf();
}

export var page_table align(4096) linksection(".page_table") = std.mem.zeroes([8 << 9]u64);
var page_table_next_ptr: [*]u64 = @ptrCast(&page_table);

inline fn next_page_table_entry(comptime count: u64) *[count]u64 {
    const result: *[count]u64 = @ptrCast(page_table_next_ptr);
    page_table_next_ptr += count;
    if (page_table_next_ptr - @as([*]u64, @ptrCast(&page_table)) >= page_table.len) {
        hcf();
    }
    return result;
}

fn set_page_entry_pml4(pml4_ptr: [*]u64, virt_addr_start: *anyopaque, phys_addr_start: usize, size: usize) void {
    if (size < (1 << 30)) {
        // It will fit in PDPT page
        const pml4_idx = (virt_addr_start >> 39) & 0x1ff;
        if (pml4_ptr[pml4_idx] & 0x1 == 0) {
            // This PML4 entry hasn't been initialized yet - the present bit is cleared
            pml4_ptr[pml4_idx] = 0;
        }
    } else {
        // We can't make PML4 entry a terminal entry
        // Instead, setup multiple PDPT entries
        var size_rem = size;
        var virt_addr_now = virt_addr_start;
        var phys_addr_now = phys_addr_start;
        while (true) {
            if (size_rem < (1 << 30)) {
                set_page_entry_pml4(pml4_ptr, virt_addr_now, phys_addr_now, size_rem);
                break;
            } else {
                set_page_entry_pml4(pml4_ptr, virt_addr_now, phys_addr_now, 1 << 30);
                size_rem -= (1 << 30);
                virt_addr_now += (1 << 30);
                phys_addr_now += (1 << 30);
            }
        }
    }
}

export var tss = std.mem.zeroes([25]u32);

const Gdtr = extern struct {
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

export var cpuid: [4]u32 = undefined;

pub export fn kmain() linksection(".text") callconv(.c) void {
    // Read CPUID
    // asm volatile (
    //     \\movq $0x01, %rax
    //     \\cpuid
    //     \\movl %eax, (%[result_ptr])
    //     \\movl %ebx, 0x4(%[result_ptr])
    //     \\movl %ecx, 0x8(%[result_ptr])
    //     \\movl %edx, 0xc(%[result_ptr])
    //     :
    //     : [result_ptr] "{r8}" (&cpuid),
    //     : .{ .rax = true, .rbx = true, .rcx = true, .rdx = true });

    // Allow executing SSE/AVX instructions
    // Set OSFXSR and OSXSAVE bits in CR4
    // asm volatile (
    //     \\movq %cr4, %rax
    //     \\orq $0x40200, %rax
    //     \\movq %rax, %cr4
    //     ::: .{ .rax = true });

    // Load GDT
    gdt[5] = ((@intFromPtr(&tss) & 0xffffff) >> 0 << 16) | ((@intFromPtr(&tss) & 0xff000000) >> 24 << 56) | (((@sizeOf(@TypeOf(tss)) - 1) & 0xf0000) >> 16 << 48) | (((@as(u64, @sizeOf(@TypeOf(tss))) - 1) & 0xffff) >> 0 << 0) | (0x89 << 40) | (0x0 << 52);
    gdt[6] = ((@intFromPtr(&tss) & 0xffffffff00000000) << 0);
    const gdtr = Gdtr{
        .limit = @sizeOf(@TypeOf(gdt)),
        .base = @intFromPtr(&gdt),
    };
    asm volatile ("lgdt (%[gdtr_ptr])"
        :
        : [gdtr_ptr] "{rax}" (&gdtr),
        : .{});

    if (framebuffer_request.response == null) {
        hcf();
    }

    const fb = framebuffer_request.response.*.framebuffers[0];
    const fb_address = @as([*]u32, @ptrCast(@alignCast(fb.*.address.?)));
    for (0..100) |i| {
        fb_address[i * (fb.*.pitch / 4) + i] = 0xffffff;
    }

    // Setup paging.
    // Limine already sets it up, so virtaul address a+offset maps to physical address a.
    const pml4_ptr = next_page_table_entry(512);
    for (0..512) |i| {
        pml4_ptr[i] = 0;
    }

    // log.log_writer.print("Hello world!\n1 + 2 = {d}\n", .{@as(u32, 17)}) catch {};
    // log.log_writer.print("Hello {s}!\n", .{"world"}) catch {};
    // log.log_writer.print("Some text...\n", .{}) catch {};
    // log.log_writer.print("Letter: {c}\n", .{'a'}) catch {};
    // log.log_writer.writeAll("Hello wrold!\nLorem ipsum dolor sir amet\n") catch {};
    log.log_writer.flush() catch {};

    for (0..limine_memmap_request.response.*.entry_count) |i| {
        // log_writer
        _ = i;
    }

    while (true) {}
}
