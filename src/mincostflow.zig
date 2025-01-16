const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn McfGraph(comptime Cap: type, comptime Cost: type) type {
    return struct {
        const Self = @This();

        pub const Edge = struct {
            from: usize,
            to: usize,
            cap: Cap,
            flow: Cap,
            cost: Cost,
        };

        allocator: Allocator,
        n: usize,

        pub fn init(allocator: Allocator, n: usize) Self {
            return Self{
                .allocator = allocator,
                .n = n,
            };
        }

        pub fn deinit(self: *Self) void {
            _ = self; // autofix
        }

        pub fn addEdge(self: *Self, from: usize, to: usize, cap: Cap, cost: Cost) Allocator.Error!usize {
            assert(from < self.n);
            assert(to < self.n);
            assert(from != to);
            assert(0 <= cap);
            assert(0 <= cost);
            return 0;
        }

        pub fn getEdge(self: Self, i: usize) Edge {
            _ = self; // autofix
            _ = i; // autofix
            return Edge{};
        }

        pub fn edges(self: Self) Allocator.Error![]Edge {
            _ = self; // autofix
            return Edge{};
        }

        pub fn flow(self: *Self, s: usize, t: usize) Allocator.Error!struct { Cap, Cost } {
            return self.flowWithCapacity(s, t, std.math.maxInt(Cap));
        }

        pub fn flowWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) Allocator.Error!struct { Cap, Cost } {
            _ = flow_limit; // autofix
            _ = self; // autofix
            _ = s; // autofix
            _ = t; // autofix
            return .{ 0, 0 };
        }

        pub fn slope(self: *Self, s: usize, t: usize) Allocator.Error![]struct { Cap, Cost } {
            return self.slopeWithCapacity(s, t, std.math.maxInt(Cap));
        }

        pub fn slopeWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) Allocator.Error![]struct { Cap, Cost } {
            _ = s; // autofix
            _ = t; // autofix
            _ = flow_limit; // autofix
            const result = try self.allocator.alloc(struct { Cap, Cost }, 1);
            return result;
        }
    };
}

const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

test McfGraph {
    const allocator = testing.allocator;
    const McfGraphI32 = McfGraph(i32, i32);

    var graph = McfGraphI32.init(allocator, 4);
    defer graph.deinit();

    _ = try graph.addEdge(0, 1, 2, 1);
    _ = try graph.addEdge(0, 2, 1, 2);
    _ = try graph.addEdge(1, 2, 1, 1);
    _ = try graph.addEdge(1, 3, 1, 3);
    _ = try graph.addEdge(2, 3, 2, 1);

    const flow, const cost = try graph.flowWithCapacity(0, 3, 2);
    try expectEqual(2, flow);
    try expectEqual(6, cost);
}

test "same_cost_paths" {
    // https://github.com/atcoder/ac-library/blob/300e66a7d73efe27d02f38133239711148092030/test/unittest/mincostflow_test.cpp#L83-L90
    const allocator = testing.allocator;
    const McfGraphI32 = McfGraph(i32, i32);

    var graph = McfGraphI32.init(allocator, 3);
    defer graph.deinit();

    try expectEqual(0, try graph.addEdge(0, 1, 1, 1));
    try expectEqual(1, try graph.addEdge(1, 2, 1, 0));
    try expectEqual(2, try graph.addEdge(0, 2, 2, 1));

    const slope = try graph.slope(0, 2);
    defer allocator.free(slope);
    try expectEqualSlices(struct { i32, i32 }, &.{ .{ 0, 0 }, .{ 3, 3 } }, slope);
}

test "only_one_nonzero_cost_edge" {
    const allocator = testing.allocator;
    const McfGraphI32 = McfGraph(i32, i32);

    var graph = McfGraphI32.init(allocator, 3);
    defer graph.deinit();

    try expectEqual(0, try graph.addEdge(0, 1, 1, 1));
    try expectEqual(1, try graph.addEdge(1, 2, 1, 0));

    const slope = try graph.slope(0, 2);
    defer allocator.free(slope);
    try expectEqualSlices(struct { i32, i32 }, &.{ .{ 0, 0 }, .{ 1, 1 } }, slope);
}
