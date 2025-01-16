const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn McfGraph(comptime Cap: type, comptime Cost: type) type {
    return struct {
        const Self = @This();

        pub const Edge = struct {};

        allocator: Allocator,
        n: usize,

        pub fn init(allocator: Allocator, n: usize) Self {
            return Self{
                .allocator = allocator,
                .n = n,
            };
        }

        pub fn deinit(self: *Self) Self {
            _ = self; // autofix
        }

        pub fn addEdge(self: *Self, from: usize, to: usize, cap: Cap, cost: Cost) Allocator.Error!usize {
            _ = self; // autofix
            _ = from; // autofix
            _ = to; // autofix
            _ = cap; // autofix
            _ = cost; // autofix
        }

        pub fn getEdge(self: Self, i: usize) Edge {
            _ = self; // autofix
            _ = i; // autofix
        }

        pub fn edges(self: Self) Allocator.Error![]Edge {
            _ = self; // autofix
        }

        pub fn flow(self: *Self, s: usize, t: usize) struct { Cap, Cost } {
            return self.flowWithCapacity(s, t, std.math.maxInt(Cap));
        }

        pub fn flowWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) struct { Cap, Cost } {
            _ = flow_limit; // autofix
            _ = self; // autofix
            _ = s; // autofix
            _ = t; // autofix
        }

        pub fn slope(self: *Self, s: usize, t: usize) Allocator.Error![]struct { Cap, Cost } {
            return self.slopeWithCapacity(s, t, std.math.maxInt(Cap));
        }

        pub fn slopeWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) Allocator.Error![]struct { Cap, Cost } {
            _ = self; // autofix
            _ = s; // autofix
            _ = t; // autofix
            _ = flow_limit; // autofix
        }
    };
}
