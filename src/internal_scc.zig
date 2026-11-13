const std = @import("std");
const Csr = @import("internal_csr.zig").Csr;
const Groups = @import("internal_groups.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const SccGraph = @This();

const Edge = struct {
    to: usize,
};
const Env = struct {
    g: Csr(Edge),
    now_ord: usize,
    group_num: usize,
    visited: ArrayList(usize),
    low: []usize,
    ord: []?usize,
    ids: []usize,
};

n: usize,
edges: ArrayList(struct { usize, Edge }),
allocator: Allocator,

pub fn init(allocator: Allocator, n: usize) SccGraph {
    const self = SccGraph{
        .n = n,
        .edges = .empty,
        .allocator = allocator,
    };
    return self;
}
pub fn deinit(self: *SccGraph) void {
    self.edges.deinit(self.allocator);
}
pub fn numVertices(self: SccGraph) usize {
    return self.n;
}
pub fn addEdge(self: *SccGraph, from: usize, to: usize) !void {
    try self.edges.append(self.allocator, .{ from, Edge{ .to = to } });
}
pub fn sccIds(self: SccGraph) !struct { usize, []usize } {
    const allocator = self.allocator;

    var env: Env = undefined;
    env.now_ord = 0;
    env.group_num = 0;
    env.g = try .init(allocator, self.n, self.edges.items, .{ .to = 0 });
    defer env.g.deinit();
    env.visited = try .initCapacity(allocator, self.n);
    defer env.visited.deinit(allocator);
    env.low = try allocator.alloc(usize, self.n);
    defer allocator.free(env.low);
    env.ord = try allocator.alloc(?usize, self.n);
    defer allocator.free(env.ord);
    env.ids = try allocator.alloc(usize, self.n);
    errdefer allocator.free(env.ids);

    @memset(env.low, 0);
    @memset(env.ord, null);
    @memset(env.ids, 0);

    for (0..self.n) |i| {
        if (env.ord[i] == null) {
            try dfs(allocator, i, self.n, &env);
        }
    }
    for (0..self.n) |i| {
        env.ids[i] = env.group_num - 1 - env.ids[i];
    }
    return .{ env.group_num, env.ids };
}
pub fn scc(self: SccGraph) !Groups {
    const group_num, const ids = try self.sccIds();
    defer self.allocator.free(ids);

    var group_index = try self.allocator.alloc(?usize, self.n);
    defer self.allocator.free(group_index);
    @memset(group_index, 0);
    for (0..self.n) |i| {
        group_index[i] = ids[i];
    }
    return try .init(self.allocator, group_num, group_index);
}
fn dfs(allocator: Allocator, v: usize, n: usize, env: *Env) !void {
    env.low[v] = env.now_ord;
    env.ord[v] = env.now_ord;
    env.now_ord += 1;
    try env.visited.append(allocator, v);

    for (env.g.start[v]..env.g.start[v + 1]) |i| {
        const to = env.g.elist[i].to;
        if (env.ord[to]) |ord| {
            env.low[v] = @min(env.low[v], ord);
        } else {
            try dfs(allocator, to, n, env);
            env.low[v] = @min(env.low[v], env.low[to]);
        }
    }
    if (env.low[v] == env.ord[v].?) {
        while (true) {
            const u = env.visited.pop().?;
            env.ord[u] = n;
            env.ids[u] = env.group_num;
            if (u == v) {
                break;
            }
        }
        env.group_num += 1;
    }
}

test SccGraph {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn check(allocator: Allocator) !void {
            var graph = SccGraph.init(allocator, 2);
            defer graph.deinit();
            try graph.addEdge(0, 1);
            const ids = (try graph.sccIds()).@"1";
            defer allocator.free(ids);
        }
    }.check, .{});
}
