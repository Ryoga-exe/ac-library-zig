const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn LazySegtree() type {
    return struct {
        const Self = @This();

        allocator: Allocator,

        pub fn init(allocator: Allocator) !Self {
            const self = Self{
                .allocator = allocator,
            };
            return self;
        }
    };
}
