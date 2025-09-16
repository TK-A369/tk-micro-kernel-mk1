const std = @import("std");

pub fn hcf() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn RefCount(comptime T: type) type {
    return struct {
        count: std.atomic.Value(u64),
        dropFn: *const fn (*T) void,
        value: T,

        const This = @This();

        fn ref(self: *This) void {
            _ = self.count.fetchAdd(1, .monotonic);
        }

        fn unref(self: *This) void {
            if (self.count.fetchSub(1, .release) == 1) {
                _ = self.count.load(.acquire);
                self.dropFn(&self.value);
            }
        }

        fn noop(self: *T) void {
            _ = self;
        }
    };
}
