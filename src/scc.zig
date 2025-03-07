const std = @import("std");
const InternalSccGraph = @import("internal_scc.zig");
const Groups = @import("internal_groups.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const SccGraph = @This();

internal: InternalSccGraph,

pub fn init(allocator: Allocator, n: usize) !SccGraph {
    return SccGraph{
        .internal = InternalSccGraph.init(allocator, n),
    };
}

pub fn deinit(self: *SccGraph) void {
    self.internal.deinit();
}

pub fn addEdge(self: *SccGraph, from: usize, to: usize) !void {
    assert(from < self.internal.numVertices());
    assert(to < self.internal.numVertices());
    try self.internal.addEdge(from, to);
}

pub fn scc(self: SccGraph) !Groups {
    return self.internal.scc();
}

test "SccGraph: Simple graph" {
    const allocator = std.testing.allocator;
    var graph = try SccGraph.init(allocator, 2);
    defer graph.deinit();
    try graph.addEdge(0, 1);
    try graph.addEdge(1, 0);
    var scc_graph = try graph.scc();
    defer scc_graph.deinit();
    try std.testing.expectEqual(@as(usize, 1), scc_graph.len);
}

test "SccGraph: Self loop" {
    const allocator = std.testing.allocator;
    var graph = try SccGraph.init(allocator, 2);
    defer graph.deinit();
    try graph.addEdge(0, 0);
    try graph.addEdge(0, 0);
    try graph.addEdge(1, 1);
    var scc_graph = try graph.scc();
    defer scc_graph.deinit();
    try std.testing.expectEqual(@as(usize, 2), scc_graph.len);
}

test "SccGraph: ALPC-G sample" {
    // https://atcoder.jp/contests/practice2/tasks/practice2_g
    const n: usize = 6;
    const edges = &[_]struct { usize, usize }{
        .{ 1, 4 },
        .{ 5, 2 },
        .{ 3, 0 },
        .{ 5, 5 },
        .{ 4, 1 },
        .{ 0, 3 },
        .{ 4, 2 },
    };

    const allocator = std.testing.allocator;
    var graph = try SccGraph.init(allocator, n);
    defer graph.deinit();
    for (edges) |edge| {
        const from, const to = edge;
        try graph.addEdge(from, to);
    }
    var scc_graph = try graph.scc();
    defer scc_graph.deinit();
    try std.testing.expectEqual(@as(usize, 4), scc_graph.len);
    try std.testing.expectEqualSlices(usize, &[_]usize{5}, scc_graph.get(0));
    try std.testing.expectEqualSlices(usize, &[_]usize{ 1, 4 }, scc_graph.get(1));
    try std.testing.expectEqualSlices(usize, &[_]usize{2}, scc_graph.get(2));
    try std.testing.expectEqualSlices(usize, &[_]usize{ 0, 3 }, scc_graph.get(3));
}
