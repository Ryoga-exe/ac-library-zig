const std = @import("std");
const internal = @import("internal_scc.zig");
const Groups = @import("internal_groups.zig");
const Allocator = std.mem.Allocator;

const SccGraph = @This();

internal: internal.SccGraph,

pub fn init(allocator: Allocator, n: usize) !SccGraph {
    return SccGraph{
        .internal = internal.SccGraph.init(allocator, n),
    };
}
pub fn deinit(self: *SccGraph) void {
    self.internal.deinit();
}
pub fn addEdge(self: *SccGraph, from: usize, to: usize) !void {
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
    try std.testing.expect(scc_graph.len == 1);
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
    try std.testing.expect(scc_graph.len == 2);
}

test "SccGraph: ALPC-G sample" {
    // https://atcoder.jp/contests/practice2/tasks/practice2_g
    const n: usize = 6;
    const edges = &[_]std.meta.Tuple(&.{ usize, usize }){
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
        try graph.addEdge(edge.@"0", edge.@"1");
    }
    var scc_graph = try graph.scc();
    defer scc_graph.deinit();
    try std.testing.expect(scc_graph.len == 4);
    try std.testing.expectEqualSlices(usize, &[_]usize{5}, scc_graph.get(0));
    try std.testing.expectEqualSlices(usize, &[_]usize{ 1, 4 }, scc_graph.get(1));
    try std.testing.expectEqualSlices(usize, &[_]usize{2}, scc_graph.get(2));
    try std.testing.expectEqualSlices(usize, &[_]usize{ 0, 3 }, scc_graph.get(3));
}
