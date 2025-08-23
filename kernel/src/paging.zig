const buddy_allocator = @import("buddy_allocator.zig");

pub const PagingLevel = enum {
    // pml4, //page map level 4
    pdpt, //page directory pointer table
    pd, //page directory
    pt, //page table
};

pub fn set_page_entry(pml4_ptr: [*]u64, phys_allocator: *buddy_allocator.BuddyAllocator, hddm_offset: u64, level: PagingLevel, virt_addr_start: u64, phys_addr_start: u64) !void {
    if (phys_addr_start & 0xfff != 0) {
        return error.Misaligned;
    }
    if (virt_addr_start & 0xfff != 0) {
        return error.Misaligned;
    }
    // const page_size = switch (level) {
    //     .pml4 => 1 << 39,
    //     .pdpt => 1 << 30,
    //     .pd => 1 << 21,
    //     .pt => 1 << 12,
    // };

    const pml4_idx = (virt_addr_start >> 39) & 0x1ff;
    var pdpt_ptr: [*]u64 = undefined;
    if (pml4_ptr[pml4_idx] & 0x1 == 0) {
        pdpt_ptr = @ptrCast(try phys_allocator.alloc(8 * 512));
        @memset(pdpt_ptr[0..512], 0);
        // TODO: allow controlling permissions
        pml4_ptr[pml4_idx] = @intFromPtr(pdpt_ptr) | 0x7; // U/S, R/W and P are set
    }

    const pdpt_idx = (virt_addr_start >> 30) & 0x1ff;
    var pd_ptr: [*]u64 = undefined;
    if (pdpt_ptr[pdpt_idx] & 0x1 == 0) {
        if (level == .pdpt) {
            return error.PageAlreadyMapped;
        }
        pd_ptr = @ptrCast(try phys_allocator.alloc(8 * 512));
        @memset(pdpt_ptr[0..512], 0);
        // TODO: allow controlling permissions
        pdpt_ptr[pdpt_idx] = @intFromPtr(pd_ptr) | 0x7; // U/S, R/W and P are set
    }
}
