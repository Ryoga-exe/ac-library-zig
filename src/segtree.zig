const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Segtree(comptime S: type, op: fn (S, S) S, e: S) type {
    _ = e;
    _ = op;
    return struct {
        const Self = @This();

        pub fn init() Self {}
    };
}
