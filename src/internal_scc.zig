const std = @import("std");
const Csr = @import("internal_csr.zig").Csr;
const Groups = @import("internal_groups.zig");
const Allocator = std.mem.Allocator;

const SccGraph = @This();

const Edge = struct {
    to: usize,
};
const Env = struct {
    g: Csr(Edge),
    now_ord: usize,
    group_num: usize,
    visited: std.ArrayList(usize),
    low: []usize,
    ord: []?usize,
    ids: []usize,
};

n: usize,
edges: std.ArrayList(struct { usize, Edge }),
allocator: Allocator,

pub fn init(allocator: Allocator, n: usize) SccGraph {
    const self = SccGraph{
        .n = n,
        .edges = std.ArrayList(struct { usize, Edge }).init(allocator),
        .allocator = allocator,
    };
    return self;
}
pub fn deinit(self: *SccGraph) void {
    self.edges.deinit();
}
pub fn numVertices(self: SccGraph) usize {
    return self.n;
}
pub fn addEdge(self: *SccGraph, from: usize, to: usize) !void {
    try self.edges.append(.{ from, Edge{ .to = to } });
}
pub fn sccIds(self: SccGraph) !struct { usize, []usize } {
    var env = Env{
        .g = try Csr(Edge).init(self.allocator, self.n, self.edges, Edge{ .to = 0 }),
        .now_ord = 0,
        .group_num = 0,
        .visited = try std.ArrayList(usize).initCapacity(self.allocator, self.n),
        .low = try self.allocator.alloc(usize, self.n),
        .ord = try self.allocator.alloc(?usize, self.n),
        .ids = try self.allocator.alloc(usize, self.n),
    };

    @memset(env.low, 0);
    @memset(env.ord, null);
    @memset(env.ids, 0);

    defer {
        env.g.deinit();
        env.visited.deinit();
        self.allocator.free(env.low);
        self.allocator.free(env.ord);
        self.allocator.free(env.ids);
    }

    for (0..self.n) |i| {
        if (env.ord[i] == null) {
            try dfs(i, self.n, &env);
        }
    }
    for (0..self.n) |i| {
        env.ids[i] = env.group_num - 1 - env.ids[i];
    }
    return .{ env.group_num, try self.allocator.dupe(usize, env.ids) };
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
    return try Groups.init(self.allocator, group_num, group_index);
}
fn dfs(v: usize, n: usize, env: *Env) !void {
    env.low[v] = env.now_ord;
    env.ord[v] = env.now_ord;
    env.now_ord += 1;
    try env.visited.append(v);

    for (env.g.start[v]..env.g.start[v + 1]) |i| {
        const to = env.g.elist[i].to;
        if (env.ord[to]) |ord| {
            env.low[v] = @min(env.low[v], ord);
        } else {
            try dfs(to, n, env);
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
