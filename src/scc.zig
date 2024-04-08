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

test "SccGraph: Simple graph" {
    const allocator = std.testing.allocator;
    var graph = try SccGraph.init(allocator, 2);
    defer graph.deinit();
    try graph.addEdge(0, 1);
    try graph.addEdge(1, 0);
    // const scc = graph.scc();
    // try std.testing.expect();
}

test "SccGraph: Self loop" {
    const allocator = std.testing.allocator;
    var graph = try SccGraph.init(allocator, 2);
    defer graph.deinit();
    try graph.addEdge(0, 0);
    try graph.addEdge(0, 0);
    try graph.addEdge(1, 1);
    // const scc = graph.scc();
    // try std.testing.expect();
}

test "SccGraph: ALPC-G sample" {
    // https://atcoder.jp/contests/practice2/tasks/practice2_g
    const n: usize = 6;
    const edges = &[_]std.meta.Tuple(.{ usize, usize }){
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
    // const scc = graph.scc();
    // try std.testing.expect();
}
