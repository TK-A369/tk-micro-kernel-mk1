const BuddyAllocator = struct {
    start: [*]u8,
    //bits 0-15 tell whether a block is used: 0 - used; 1 - free
    //bits 16-31 tell whether a block is split
    //combinations of split (MSb) and used (LSb) bit:
    // - 00 - used or part of a larger block
    // - 10 - split
    // - 01 - free
    bitmaps: [][]u32,
    page_size: u64,
    pages_count: u64,

    // Currently it is intended to be used with LinearAllocator
    pub fn init_with_other(other_allocator: anytype, start: [*]u8, page_size: u64, pages_count: u64, bitmaps_count: u64) error{OutOfMemory}!BuddyAllocator {
        var total_bitmaps_size = 0;
        var curr_bits_count = pages_count;
        for (0..bitmaps_count) |_| {
            total_bitmaps_size += (curr_bits_count + 16 - 1) / 16;
            curr_bits_count /= 2;
        }
        const bitmaps_array: [*]u8 = try other_allocator.alloc(total_bitmaps_size * 4 + bitmaps_count * @sizeOf([]u32));
        const bitmaps = @as([*][]u32, @ptrCast(
            bitmaps_array + total_bitmaps_size * 4,
        ))[0..bitmaps_count];

        var curr_offset = 0;
        curr_bits_count = pages_count;
        for (0..bitmaps_count) |i| {
            bitmaps[i] = @as([*]u32, @ptrCast(
                bitmaps_array + curr_offset * 4,
            ))[0..((curr_bits_count + 16 - 1) / 16)];
            curr_offset += (curr_bits_count + 16 - 1) / 16;
            curr_bits_count /= 2;
        }

        return .{
            .start = start,
            .bitmaps = bitmaps,
            .page_size = page_size,
            .pages_count = pages_count,
        };
    }

    pub fn clear(self: *BuddyAllocator) void {
        for (0.., self.bitmaps) |i, bitmap| {
            if (i == self.bitmaps.len - 1) {
                for (bitmap) |*bitgroup| {
                    bitgroup.* = 0x0000ffff;
                }
                var last_bitgroup_used_bits = self.pages_count >> self.bitmaps.size % 16;
                if (last_bitgroup_used_bits == 0) {
                    last_bitgroup_used_bits = 16;
                }
                const last_bitgroup_padding_bits = 16 - last_bitgroup_used_bits;
                bitmap[bitmap.len - 1] >>= last_bitgroup_padding_bits;
            } else {
                for (bitmap) |bitgroup| {
                    bitgroup = 0x00000000;
                }
            }
        }
    }

    pub fn alloc(self: *BuddyAllocator, size: u64) error{OutOfMemory}![*]u8 {
        const size_pages = (size + self.page_size - 1) / self.page_size;
        // Select the smallest block size that will fit the requested memory fragment
        var block_size_pages: u64 = 1;
        var bitmap_num: u64 = 0;
        while (block_size_pages < size_pages) {
            block_size_pages <<= 1;
            bitmap_num += 1;
        }

        var curr_bitmap_num = bitmap_num;
        var bit_num: u64 = 0xffffffffffffffff;
        for_each_bitmap: while (curr_bitmap_num < self.bitmaps.len) : (curr_bitmap_num += 1) {
            for (0.., self.bitmaps[curr_bitmap_num]) |i, *bitgroup| {
                if (@popCount(bitgroup.* & 0xffff) > 0) {
                    bit_num = @ctz(bitgroup.*);
                    bit_num += i * 16;
                    break :for_each_bitmap;
                }
            }
        }
        if (bit_num == 0xffffffffffffffff) {
            // We haven't found one in the bitmap
            return error.OutOfMemory;
        }
        while (curr_bitmap_num > bitmap_num) : (curr_bitmap_num -= 1) {
            // Mark the larger block as split (10)
            self.bitmaps[curr_bitmap_num][bit_num / 16] |= (0x10000 << (bit_num % 16));
            self.bitmaps[curr_bitmap_num][bit_num / 16] &= ~(0x1 << (bit_num % 16));
            bit_num *= 2;
            // Mark two child blocks as free (01)
            self.bitmaps[curr_bitmap_num - 1][bit_num / 16] |= (0x1 << (bit_num % 16));
            self.bitmaps[curr_bitmap_num - 1][bit_num / 16] &= ~(0x10000 << (bit_num % 16));
            self.bitmaps[curr_bitmap_num - 1][(bit_num + 1) / 16] |= (0x1 << ((bit_num + 1) % 16));
            self.bitmaps[curr_bitmap_num - 1][(bit_num + 1) / 16] &= ~(0x10000 << ((bit_num + 1) % 16));
        }

        return self.start + (bit_num * self.page_size);
    }

    pub fn free(self: *BuddyAllocator, data: [*]u8) void {
        const page_num = (data - self.start) / self.page_size;

        var bit_num = page_num;
        var bitmap_num = 0;
        while (bitmap_num < self.bitmaps.len) {
            if ((self.bitmaps[bitmap_num][bit_num / 16] >> (bit_num % 16)) & 0x10001 == 0x00000) {
                if ((self.bitmaps[bitmap_num + 1][(bit_num / 2) / 16] >> ((bit_num / 2) % 16)) & 0x10001 == 0x10000) {
                    // This block is used, and its parent is split
                    self.bitmaps[bitmap_num][bit_num / 16] |= (0x00001 << (bit_num % 16));
                    self.bitmaps[bitmap_num][bit_num / 16] &= ~(0x10000 << (bit_num % 16)); // Actually redundant, but we clear that bit explicitly for clarity
                    break;
                }
            }
            bit_num /= 2;
            bitmap_num += 1;
        }
        while (bitmap_num < self.bitmaps.len - 1) {
            if ((self.bitmaps[bitmap_num][bit_num / 16] >> (bit_num % 16)) & 0x10001 == 0x00001 and (self.bitmaps[bitmap_num][(bit_num ^ 0x1) / 16] >> ((bit_num ^ 0x1) % 16)) & 0x10001 == 0x00001) {
                // Both the current block and its buddy are free
                // This should guarantee that their parent is split
                // Set the current block and its buddy to used or part of a larger block
                self.bitmaps[bitmap_num][bit_num / 16] &= ~(0x10001 << (bit_num % 16));
                self.bitmaps[bitmap_num][(bit_num ^ 0x1) / 16] &= ~(0x10001 << ((bit_num ^ 0x1) % 16));
                // Set their parent block to free
                self.bitmaps[bitmap_num + 1][(bit_num / 2) / 16] |= (0x00001 << ((bit_num / 2) % 16));
                self.bitmaps[bitmap_num + 1][(bit_num / 2) / 16] &= ~(0x10000 << ((bit_num / 2) % 16));
            }
        }
    }
};
