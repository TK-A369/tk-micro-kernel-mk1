const buddy_allocator = @import("buddy_allocator.zig");

/// Somehow inspired by SLAB allocator, but it's not really it
pub const GranuAllocator = struct {
    /// This struct should be page aligned
    const MemChunk = extern struct {
        elem_size: u64,
        pages_count: u64,
        bitmap_size: u64,
        elem_count: u64,
        next_chunk: ?*MemChunk,

        /// Returns amount of u64 bitgroups needed to specify whether given slot is used or free
        fn calcBitmapSize(elem_size: u64, pages_count: u64) u64 {
            // TODO: Store the page size in some constant
            const elem_count = pages_count * 0x1000 / elem_size;
            return (elem_count + 64 - 1) / 64;
        }

        /// In bitmap, 1 is free, 0 is used or padding
        fn getBitmapSlice(self: *MemChunk) []u64 {
            const bitmap_start_ptr = @as([*]u8, @ptrCast(self)) + @sizeOf(MemChunk);
            return @as([*]u64, @ptrCast(@alignCast(bitmap_start_ptr)))[0..self.bitmap_size];
        }

        fn calcExactElemCount(self: *MemChunk) u64 {
            const space_total = self.pages_count * 0x1000;
            const bitmap_space = self.bitmap_size * 8;
            const space_remaining = space_total - @sizeOf(MemChunk) - bitmap_space;
            return space_remaining / self.elem_size;
        }

        fn init(target: [*]u8, elem_size: u64, pages_count: u64) void {
            const self: *MemChunk = @ptrCast(@alignCast(target));
            self.elem_size = elem_size;
            self.pages_count = pages_count;

            self.bitmap_size = calcBitmapSize(elem_size, pages_count);
            self.elem_count = self.calcExactElemCount();

            const bitmap = self.getBitmapSlice();
            for (bitmap) |*bitgroup| {
                bitgroup.* = 0xffffffff;
            }
            var last_bitgroup_used = self.elem_count % 64;
            if (last_bitgroup_used == 0) {
                last_bitgroup_used = 64;
            }
            const last_bitgroup_padding = 64 - last_bitgroup_used;
            bitmap[bitmap.len - 1] >>= @truncate(last_bitgroup_padding);
        }

        fn alloc(self: *MemChunk) error{OutOfMemory}![*]u8 {
            for (0.., self.getBitmapSlice()) |i, *bitgroup| {
                if (@popCount(bitgroup.*) > 0) {
                    var free_pos: u64 = @ctz(bitgroup.*);
                    bitgroup.* &= ~(@as(u64, 1) << @truncate(free_pos));

                    free_pos += 64 * i;
                    const result_ptr: [*]u8 = @as([*]u8, @ptrCast(self)) + @sizeOf(MemChunk) + self.bitmap_size * 8 + free_pos * self.elem_size;
                    return result_ptr;
                }
            }
            return error.OutOfMemory;
        }
    };

    const AllocHints = struct {
        /// If true, always create a chunk of this specific size, unless it already exists and has free space
        /// If false, never create a chunk of this specific size, unless creating a new chunk is necessary
        /// If null, create a chunk of this specific size only if the smallest chunk for objects greater than this is more than 2 times the size of requested object
        create_sized_chunk: ?bool = null,
        /// How many objects (at least) should fit into a chunk, if it would be created
        /// If null, default to 1
        objects_count: ?u64 = null,
    };

    // This is virtual address, so it's normally accessible; because we've added hddm_offset to it
    first_chunk: ?*MemChunk,
    hhdm_offset: u64,
    // TODO: Allow passing chain of buddy allocators - for different memory ranges
    // This is expected to return physical address - and we'll add hddm_offset to access it
    buddy_alloc: *buddy_allocator.BuddyAllocator,

    fn searchForChunkGe(self: *const GranuAllocator, size: u64) ?*MemChunk {
        var next_chunk = self.first_chunk;
        // while(true) {
        while (next_chunk) |curr_chunk| {
            // const curr_chunk = next_chunk orelse break;
            if (curr_chunk.elem_size >= size) {
                return curr_chunk;
            }
            next_chunk = curr_chunk.next_chunk;
        }
        return null;
    }

    fn insertChunk(self: *GranuAllocator, chunk: *MemChunk) void {
        var prev_chunk: ?*MemChunk = null;
        var next_chunk: ?*MemChunk = self.first_chunk;
        // Pointers with _nn suffix are nonnull
        while (next_chunk) |next_chunk_nn| {
            if (next_chunk_nn.elem_size >= chunk.elem_size) {
                if (prev_chunk) |prev_chunk_nn| {
                    prev_chunk_nn.next_chunk = chunk;
                } else {
                    self.first_chunk = chunk;
                }
                chunk.next_chunk = next_chunk_nn;
                return;
            }
            prev_chunk = next_chunk;
            next_chunk = next_chunk_nn.next_chunk;
        }
        // If we've gotten there, it means that this chunk is the biggest one yet
        // We therefore place it as a last one
        if (prev_chunk) |prev_chunk_nn| {
            prev_chunk_nn.next_chunk = chunk;
        } else {
            self.first_chunk = chunk;
        }
        chunk.next_chunk = null;
    }

    /// This DOES NOT insert the new chunk into the linked list
    /// User is expected to call insertChunk afterwards
    fn createChunk(self: *const GranuAllocator, elem_size: u64, pages_count: u64) error{OutOfMemory}!*MemChunk {
        const chunk_mem = (try self.buddy_alloc.alloc(pages_count * 0x1000)) + self.hhdm_offset;
        MemChunk.init(chunk_mem, elem_size, pages_count);
        return @ptrCast(@alignCast(chunk_mem));
    }

    pub fn alloc(self: *GranuAllocator, size: u64, hints: AllocHints) error{OutOfMemory}![*]u8 {
        const found_chunk = self.searchForChunkGe(size);
        if (found_chunk) |found_chunk_nn| {
            const accept_chunk = accept_chunk_blk: {
                if (hints.create_sized_chunk) |csc| {
                    if (csc) {
                        break :accept_chunk_blk found_chunk_nn.elem_size == size;
                    } else {
                        break :accept_chunk_blk true;
                    }
                } else {
                    break :accept_chunk_blk found_chunk_nn.elem_size <= 2 * size;
                }
            };
            if (accept_chunk) {
                if (found_chunk_nn.alloc()) |result| {
                    return result;
                } else |err| {
                    // Kind of ugly workaround, because we can't discard error
                    @as(error{OutOfMemory}!void, err) catch {};
                }
            }
        }
        var pages_count: u64 = undefined;
        pages_count = (size * (hints.objects_count orelse 1) + 0x1000 - 1) / 0x1000;
        const new_chunk = try self.createChunk(size, pages_count);
        self.insertChunk(new_chunk);

        const result = new_chunk.alloc() catch unreachable;
        return result;
    }
};
