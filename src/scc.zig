const std = @import("std");
const Allocator = std.mem.Allocator;

pub const SccGraph = struct {
    const Self = @This();

    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }
    pub fn deinit() void {}
};
