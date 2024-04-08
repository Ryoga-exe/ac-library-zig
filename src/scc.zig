const std = @import("std");
const internal = @import("internal_scc.zig");
const Allocator = std.mem.Allocator;

pub const SccGraph = struct {
    const Self = @This();

    internal: internal.SccGraph,

    pub fn init(allocator: Allocator, n: usize) Self {
        return Self{
            .internal = try internal.SccGraph.init(allocator, n),
        };
    }
    pub fn deinit(self: *Self) void {
        self.internal.deinit();
    }
    pub fn addEdge(self: *Self, from: usize, to: usize) !void {
        try self.internal.addEdge(from, to);
    }
};
