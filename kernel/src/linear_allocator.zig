pub const LinearAllocator = struct {
    start: [*]u8,
    size: u64,
    next: [*]u8,

    pub fn alloc(self: *LinearAllocator, size: u64) error{OutOfMemory}![*]u8 {
        const result = self.next;
        self.next += size;
        if (@intFromPtr(self.next) > @intFromPtr(self.start) + self.size) {
            return error.OutOfMemory;
        }
        return result;
    }
};
