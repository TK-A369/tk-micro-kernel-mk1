const buddy_allocator = @import("buddy_allocator.zig");

pub const PagingLevel = enum {
    // pml4, //page map level 4
    pdpt, //page directory pointer table
    pd, //page directory
    pt, //page table
};

pub fn set_page_entry(pml4_ptr: [*]u64, phys_allocator: *buddy_allocator.BuddyAllocator, hddm_offset: u64, level: PagingLevel, virt_addr_start: u64, phys_addr_start: u64) !void {
    // TODO: add or subtract hddm_offset whereever appropriate

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
    } else {
        pdpt_ptr = pml4_ptr[pml4_idx] & 0x000ffffffffff000;
    }

    const pdpt_idx = (virt_addr_start >> 30) & 0x1ff;
    var pd_ptr: [*]u64 = undefined;
    if (pdpt_ptr[pdpt_idx] & 0x1 == 0) {
        if (level == .pdpt) {
            //TODO: check alignment
            pdpt_ptr[pdpt_idx] = phys_addr_start | 0x87; // PS, U/A, R/W and P are set
            return;
        }
        pd_ptr = @ptrCast(try phys_allocator.alloc(8 * 512));
        @memset(pd_ptr[0..512], 0);
        // TODO: allow controlling permissions
        pdpt_ptr[pdpt_idx] = @intFromPtr(pd_ptr) | 0x07; // U/S, R/W and P are set
    } else {
        pd_ptr = pdpt_ptr[pdpt_idx] & 0x000ffffffffff000;
    }
    if (level == .pdpt) {
        return error.PageAlreadyMapped;
    }

    const pd_idx = (virt_addr_start >> 21) & 0x1ff;
    var pt_ptr: [*]u64 = undefined;
    if (pd_ptr[pd_idx] & 0x1 == 0) {
        if (level == .pd) {
            //TODO: check alignment
            pd_ptr[pd_idx] = phys_addr_start | 0x87; // PS, U/A, R/W and P are set
            return;
        }
        pt_ptr = @ptrCast(try phys_allocator.alloc(8 * 512));
        @memset(pt_ptr[0..512], 0);
        pd_ptr[pd_idx] = @intFromPtr(pt_ptr) | 0x07; // U/S, R/W and P are set
    } else {
        pt_ptr = pdpt_ptr[pdpt_idx] & 0x000ffffffffff000;
    }
    if (level == .pd) {
        return error.PageAlreadyMapped;
    }

    const pt_idx = (virt_addr_start >> 12) & 0x1ff;
    // If we've gotten here, then it's certain that level == .pt
    if (pt_ptr[pt_idx] & 0x1 == 0) {
        pt_ptr[pt_idx] = phys_addr_start | 0x87; // PS, U/A, R/W and P are set
    }
}
