const std = @import("std");
pub const Dsu = @import("dsu.zig");
pub const FenwickTree = @import("fenwicktree.zig").FenwickTree;
pub const FenwickTreeI64 = @import("fenwicktree.zig").FenwickTreeI64;
pub const FenwickTreeI32 = @import("fenwicktree.zig").FenwickTreeI32;
pub const SccGraph = @import("scc.zig");
pub const Segtree = @import("segtree.zig").Segtree;
pub const LazySegtree = @import("lazysegtree.zig").LazySegtree;
pub const LazySegtreeNS = @import("lazysegtree.zig").LazySegtreeNS;
pub const MfGraph = @import("maxflow.zig").MfGraph;

pub usingnamespace @import("math.zig");
pub usingnamespace @import("string.zig");

comptime {
    std.testing.refAllDecls(@This());
}
