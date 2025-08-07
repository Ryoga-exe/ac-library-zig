//! A `SccGraph` is a directed graph that calculates strongly connected components (SCC) in $O(|V| + |E|)$.
//!
//! Initialize with `init`.
//! Is owned by the caller and should be freed with `deinit`.
const std = @import("std");
const Internal = @import("internal_scc.zig");
const Groups = @import("internal_groups.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const SccGraph = @This();

internal: Internal,

/// Create a `SccGraph` with `n` vertices and `0` edges which will use a specified allocator.
/// Deinitialize with `deinit`.
///
/// # Complexity
///
/// - $O(n)$
pub fn init(allocator: Allocator, n: usize) !SccGraph {
    return SccGraph{
        .internal = .init(allocator, n),
    };
}

/// Release all allocated memory.
pub fn deinit(self: *SccGraph) void {
    self.internal.deinit();
}

/// Adds directed edge from the vertex `from` to the vertex `to`.
///
/// # Constraints
///
/// - $0 \leq$ `from` $< n$
/// - $0 \leq$ `to` $< n$
///
/// # Panics
///
/// Panics if the above constraints are not satisfied.
///
/// # Complexity
///
/// - $O(1)$ amortized
pub fn addEdge(self: *SccGraph, from: usize, to: usize) !void {
    assert(from < self.internal.numVertices());
    assert(to < self.internal.numVertices());
    try self.internal.addEdge(from, to);
}

/// Calculates the strongly connected components (SCC) of directed graphs in $O(|V| + |E|)$.
///
/// Returns `Groups` (represents the list of the "list of the vertices") that satisfies the following.
///
/// - Each vertex is in exactly one "group of the vertices".
/// - Each "group of the vertices" corresponds to the vertex set of a strongly connected component. The order of the vertices in the list is undefined.
/// - The list of "group of the vertices" are sorted in topological order, i.e., for two vertices $u$, $v$ in different strongly connected components, if there is a directed path from $u$ to $v$, the list containing $u$ appears earlier than the list containing $v$.
///
/// # Complexity
///
/// - $O(n + m)$ where $m$ is the number of added edges
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
