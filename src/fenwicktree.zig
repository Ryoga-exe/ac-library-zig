const std = @import("std");
const Allocator = std.mem.Allocator;

pub const FenwickTree = struct {
    const Self = @This();

    n: usize,
    data: i64,
    allocator: Allocator,

    pub fn init(allocator: Allocator, n: usize) !Self {
        var self = Self{
            .n = n,
            .data = try allocator.alloc(i64, n),
            .allocator = allocator,
        };
        @memset(self.data, 0);
        return self;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.parent_or_size);
    }
};
