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
    blocks_count: u64,

    pub fn clear(self: *BuddyAllocator) void {
        for (0.., self.bitmaps) |i, bitmap| {
            if (i == self.bitmaps.len - 1) {
                for (bitmap) |*bitgroup| {
                    bitgroup.* = 0x0000ffff;
                }
                var last_bitgroup_used_bits = self.blocks_count >> self.bitmaps.size % 16;
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
        while (bitmap_num < self.bitmaps.len) {}
    }
};
