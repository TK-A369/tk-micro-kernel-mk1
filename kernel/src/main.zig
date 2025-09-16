const std = @import("std");
const limine = @cImport({
    @cDefine("LIMINE_API_REVISION", "3");
    @cInclude("limine.h");
});

const misc = @import("misc.zig");
const log = @import("log.zig");
const linear_allocator = @import("linear_allocator.zig");
const buddy_allocator = @import("buddy_allocator.zig");
const granu_allocator = @import("granu_allocator.zig");
const paging = @import("paging.zig");
const gdt = @import("gdt.zig");
const interrupts = @import("interrupts.zig");

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

pub const panic = std.debug.FullPanic(myPanicHandler);

fn myPanicHandler(msg: []const u8, first_trace_addr: ?usize) noreturn {
    _ = msg;
    _ = first_trace_addr;
    misc.hcf();
}

// export var page_table align(4096) linksection(".page_table") = std.mem.zeroes([8 << 9]u64);
// var page_table_next_ptr: [*]u64 = @ptrCast(&page_table);
//
// inline fn next_page_table_entry(comptime count: u64) *[count]u64 {
//     const result: *[count]u64 = @ptrCast(page_table_next_ptr);
//     page_table_next_ptr += count;
//     if (page_table_next_ptr - @as([*]u64, @ptrCast(&page_table)) >= page_table.len) {
//         misc.hcf();
//     }
//     return result;
// }

// fn set_page_entry_pml4(pml4_ptr: [*]u64, virt_addr_start: *anyopaque, phys_addr_start: usize, size: usize) void {
//     if (size < (1 << 30)) {
//         // It will fit in PDPT page
//         const pml4_idx = (virt_addr_start >> 39) & 0x1ff;
//         if (pml4_ptr[pml4_idx] & 0x1 == 0) {
//             // This PML4 entry hasn't been initialized yet - the present bit is cleared
//             pml4_ptr[pml4_idx] = 0;
//         }
//     } else {
//         // We can't make PML4 entry a terminal entry
//         // Instead, setup multiple PDPT entries
//         var size_rem = size;
//         var virt_addr_now = virt_addr_start;
//         var phys_addr_now = phys_addr_start;
//         while (true) {
//             if (size_rem < (1 << 30)) {
//                 set_page_entry_pml4(pml4_ptr, virt_addr_now, phys_addr_now, size_rem);
//                 break;
//             } else {
//                 set_page_entry_pml4(pml4_ptr, virt_addr_now, phys_addr_now, 1 << 30);
//                 size_rem -= (1 << 30);
//                 virt_addr_now += (1 << 30);
//                 phys_addr_now += (1 << 30);
//             }
//         }
//     }
// }

export var cpuid: [4]u32 = undefined;

pub export fn kmain() linksection(".text") callconv(.c) void {
    // Read CPUID
    asm volatile (
        \\movq $0x01, %rax
        \\cpuid
        \\movl %eax, (%[result_ptr])
        \\movl %ebx, 0x4(%[result_ptr])
        \\movl %ecx, 0x8(%[result_ptr])
        \\movl %edx, 0xc(%[result_ptr])
        :
        : [result_ptr] "{r8}" (&cpuid),
        : .{ .rax = true, .rbx = true, .rcx = true, .rdx = true });

    // Allow executing SSE/AVX instructions
    // For some reason Zig will emit those here and there, and I haven't found a way to disable it
    // Subtracting those from the feature set prevents successful compilation
    // See: https://osdev.wiki/wiki/SSE
    asm volatile (
        \\movq %cr0, %rax
        \\movl $0xfffffffb, %ecx #and instruction takes up to 32 bits of immediate, so we use this workaround
        \\andl %ecx, %eax #clear CR0.EM
        \\orq $0x00000002, %rax #set CR0.MP
        \\movq %rax, %cr0
        \\movq %cr4, %rax
        \\orq $0x00040600, %rax #set CR4.{OSFXS, OSXMMEXCPT, OSXSAVE}
        \\movq %rax, %cr4
        \\mov $0, %rcx
        \\xgetbv #load XCR0 register
        \\orl $0x00000007, %eax #set XCR0.{X87, SSE, AVX}
        \\xsetbv #store to XCR0
        ::: .{
            .rax = true,
            .rcx = true,
            .rdx = true,
        });

    // Load GDT
    gdt.setup_gdt();

    // Load IDT
    interrupts.setup_interrupts();

    if (framebuffer_request.response == null) {
        misc.hcf();
    }

    const fb = framebuffer_request.response.*.framebuffers[0];
    const fb_address = @as([*]u32, @ptrCast(@alignCast(fb.*.address.?)));
    for (0..100) |i| {
        fb_address[i * (fb.*.pitch / 4) + i] = 0xffffff;
    }

    // Setup paging.
    // Limine already sets it up, so virtual address a+offset maps to physical address a.
    // const pml4_ptr = next_page_table_entry(512);
    // for (0..512) |i| {
    //     pml4_ptr[i] = 0;
    // }

    log.log_writer.print("Hello world!\n1 + 2 = {d}\n", .{1 + 2}) catch {};
    log.log_writer.print("Hello {s}!\n", .{"world"}) catch {};
    log.log_writer.print("Some text...\n", .{}) catch {};
    log.log_writer.print("Letter: {c}\n", .{'a'}) catch {};
    // log.log_writer.writeAll("Hello wrold!\nLorem ipsum dolor sir amet\n") catch {};
    log.log_writer.flush() catch {};

    // Note that this is the physical address, and Limine has already set us up paging and MMU
    var largest_ram_section_addr: u64 = 0;
    var largest_ram_section_size: u64 = 0;
    log.log_writer.writeAll("Memory map:\n") catch {};
    for (0..limine_memmap_request.response.*.entry_count) |i| {
        const entry = limine_memmap_request.response.*.entries[i];
        log.log_writer.print("base: {x}, length: {x}, type: {s}\n", .{
            entry.*.base,
            entry.*.length,
            switch (entry.*.type) {
                limine.LIMINE_MEMMAP_USABLE => "usable",
                limine.LIMINE_MEMMAP_RESERVED => "reserved",
                limine.LIMINE_MEMMAP_ACPI_RECLAIMABLE => "acpi_reclaimable",
                limine.LIMINE_MEMMAP_ACPI_NVS => "acpi_nvs",
                limine.LIMINE_MEMMAP_BAD_MEMORY => "bad_memory",
                limine.LIMINE_MEMMAP_BOOTLOADER_RECLAIMABLE => "bootloader_reclaimable",
                limine.LIMINE_MEMMAP_EXECUTABLE_AND_MODULES => "executable_and_modules",
                limine.LIMINE_MEMMAP_FRAMEBUFFER => "framebuffer",
                else => "unknown",
            },
        }) catch {};

        switch (entry.*.type) {
            limine.LIMINE_MEMMAP_USABLE => {
                if (entry.*.length > largest_ram_section_size) {
                    largest_ram_section_addr = entry.*.base;
                    largest_ram_section_size = entry.*.length;
                }
            },
            else => {},
        }
    }

    var lin_alloc = linear_allocator.LinearAllocator{
        .start = @ptrFromInt(largest_ram_section_addr),
        .size = largest_ram_section_size,
        .next = @ptrFromInt(largest_ram_section_addr),
    };
    const buddy_mem = lin_alloc.alloc(0x1000 * (256 + 1)) catch {
        misc.hcf();
    };
    const buddy_mem_aligned: [*]u8 = @ptrFromInt((@intFromPtr(buddy_mem) & 0xfffffffffffff000) + 0x1000);
    var buddy_alloc = buddy_allocator.BuddyAllocator.initWithOther(
        &lin_alloc,
        limine_hhdm_request.response.*.offset,
        buddy_mem_aligned,
        0x1000,
        256,
        4,
    ) catch {
        misc.hcf();
    };
    const some_mem_1 = buddy_alloc.alloc(64) catch {
        misc.hcf();
    };
    const some_mem_2 = buddy_alloc.alloc(4097) catch {
        misc.hcf();
    };
    _ = some_mem_2;
    buddy_alloc.free(some_mem_1);
    const some_mem_3 = buddy_alloc.alloc(8192) catch {
        misc.hcf();
    };
    _ = some_mem_3;

    var granu_alloc = granu_allocator.GranuAllocator{
        .first_chunk = null,
        .hhdm_offset = limine_hhdm_request.response.*.offset,
        .buddy_alloc = &buddy_alloc,
    };
    const another_mem_1 = granu_alloc.alloc(16, .{}) catch {
        misc.hcf();
    };
    const another_mem_2 = granu_alloc.alloc(12, .{}) catch {
        misc.hcf();
    };
    _ = another_mem_2;
    granu_alloc.free(another_mem_1);

    asm volatile (
        \\mov $0x0123456789abcdef, %%rax
        \\int $0x80
        ::: .{ .rax = true });

    while (true) {}
}
