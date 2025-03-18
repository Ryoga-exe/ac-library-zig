const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const internal = struct {
    const Csr = @import("internal_csr.zig").Csr;
};

pub fn McfGraph(comptime Cap: type, comptime Cost: type) type {
    // TODO: check Cap and Cost is signed integer
    return struct {
        const Self = @This();

        pub const Edge = struct {
            from: usize,
            to: usize,
            cap: Cap,
            flow: Cap,
            cost: Cost,
        };
        const Edges = ArrayList(Edge);
        const CapCostPair = struct { Cap, Cost };

        allocator: Allocator,
        edges: Edges,
        n: usize,

        pub fn init(allocator: Allocator, n: usize) Self {
            return Self{
                .allocator = allocator,
                .edges = .init(allocator),
                .n = n,
            };
        }

        pub fn deinit(self: *Self) void {
            self.edges.deinit();
        }

        pub fn addEdge(self: *Self, from: usize, to: usize, cap: Cap, cost: Cost) Allocator.Error!usize {
            assert(from < self.n);
            assert(to < self.n);
            assert(from != to);
            assert(0 <= cap);
            assert(0 <= cost);
            const m = self.edges.items.len;
            try self.edges.append(Edge{
                .from = from,
                .to = to,
                .cap = cap,
                .flow = 0,
                .cost = cost,
            });
            return m;
        }

        pub fn getEdge(self: Self, i: usize) Edge {
            const m = self.edges.items.len;
            assert(0 <= i and i < m);
            return self.edges.items[i];
        }

        pub fn cloneEdges(self: Self) Allocator.Error![]Edges {
            return self.g.clone();
        }

        pub fn flow(self: *Self, s: usize, t: usize) Allocator.Error!CapCostPair {
            return self.flowWithCapacity(s, t, std.math.maxInt(Cap));
        }

        pub fn flowWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) Allocator.Error!CapCostPair {
            const result = try self.slopeWithCapacity(s, t, flow_limit);
            defer self.allocator.free(result);
            return result[result.len - 1];
        }

        pub fn slope(self: *Self, s: usize, t: usize) Allocator.Error![]CapCostPair {
            return self.slopeWithCapacity(s, t, std.math.maxInt(Cap));
        }

        pub fn slopeWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) Allocator.Error![]CapCostPair {
            assert(0 <= s and s < self.n);
            assert(0 <= t and t < self.n);
            assert(s != t);

            const m = self.edges.items.len;
            var edge_idx = try self.allocator.alloc(usize, m);
            defer self.allocator.free(edge_idx);

            var g = blk: {
                var degree = try self.allocator.alloc(usize, self.n);
                defer self.allocator.free(degree);
                @memset(degree, 0);
                var redge_idx = try self.allocator.alloc(usize, m);
                defer self.allocator.free(redge_idx);

                var elist = try ArrayList(struct { usize, InsideEdge }).initCapacity(self.allocator, 2 * m);
                defer elist.deinit();
                for (0..m) |i| {
                    const e = self.edges.items[i];
                    edge_idx[i] = degree[e.from];
                    degree[e.from] += 1;
                    redge_idx[i] = degree[e.to];
                    degree[e.to] += 1;
                    elist.appendAssumeCapacity(.{
                        e.from,
                        InsideEdge{
                            .to = e.to,
                            .rev = undefined,
                            .cap = e.cap - e.flow,
                            .cost = e.cost,
                        },
                    });
                    elist.appendAssumeCapacity(.{
                        e.to,
                        InsideEdge{
                            .to = e.from,
                            .rev = undefined,
                            .cap = e.flow,
                            .cost = -e.cost,
                        },
                    });
                }
                var g = try internal.Csr(InsideEdge).init(self.allocator, self.n, elist, .zero);
                for (0..m) |i| {
                    const e = self.edges.items[i];
                    edge_idx[i] += g.start[e.from];
                    redge_idx[i] += g.start[e.to];
                    g.elist[edge_idx[i]].rev = redge_idx[i];
                    g.elist[redge_idx[i]].rev = edge_idx[i];
                }
                break :blk g;
            };
            defer g.deinit();

            const result = blk: {
                const dual_dist = try self.allocator.alloc(struct { Cost, Cost }, self.n);
                defer self.allocator.free(dual_dist);
                const prev_e = try self.allocator.alloc(usize, self.n);
                defer self.allocator.free(prev_e);
                // @memset(prev_e, 0);
                const vis = try self.allocator.alloc(bool, self.n);
                defer self.allocator.free(vis);

                var flow_current: Cap = 0;
                var cost_current: Cost = 0;
                var prev_cost_per_flow: Cost = -1;
                var result = ArrayList(CapCostPair).init(self.allocator);
                try result.append(CapCostPair{ 0, 0 });
                while (flow_current < flow_limit) {
                    // if (refineDual()) {
                    //      break;
                    // }
                    var c = flow_limit - flow_current;
                    var v = t;
                    while (v != s) : (v = g.elist[prev_e[v]].to) {
                        c = @min(c, g.elist[g.elist[prev_e[v]].rev].cap);
                    }
                    v = t;
                    while (v != s) : (v = g.elist[prev_e[v]].to) {
                        g.elist[prev_e[v]].cap += c;
                        const rev = g.elist[prev_e[v]].rev;
                        g.elist[rev].cap -= c;
                    }
                    const d: Cost = -dual_dist[s].@"0";
                    flow_current += c;
                    cost_current += c * d;
                    if (prev_cost_per_flow == d) {
                        _ = result.pop();
                    }
                    try result.append(CapCostPair{ flow_current, cost_current });
                    prev_cost_per_flow = d;
                }

                break :blk try result.toOwnedSlice();
            };

            for (0..m) |i| {
                const e = g.elist[edge_idx[i]];
                self.edges.items[i].flow = self.edges.items[i].cap - e.cap;
            }

            return result;
        }

        const InsideEdge = struct {
            to: usize,
            rev: usize,
            cap: Cap,
            cost: Cost,

            const zero = InsideEdge{
                .to = 0,
                .rev = 0,
                .cap = 0,
                .cost = 0,
            };
        };

        fn refineDual(self: Self, s: usize, t: usize, dual: []struct { Cost, Cost }, vis: []bool) bool {
            for (0..self.n) |i| {
                dual[i].@"1" = std.math.maxInt(Cost);
            }
            @memset(false, vis);

            const Q = struct {
                const Q = @This();
                key: Cost,
                to: usize,
                fn greaterThan(_: void, a: Q, b: Q) std.math.Order {
                    return std.math.order(a.key, b.key).invert();
                }
            };
            var que_min = ArrayList(usize).init(self.allocator);
            defer que_min.deinit();
            var que = std.PriorityQueue(Q, void, Q.greaterThan).init(self.allocator, {});
            defer que.deinit();

            dual[s].@"1" = 0;
            try que_min.append(s);
            while (que.count() > 0 or que_min.items.len > 0) {
                const v = que_min.pop() orelse que.remove();
                if (vis[v]) {
                    continue;
                }
                vis[v] = true;
                if (v == t) {
                    break;
                }
                const dual_v, const dist_v = dual[v];
                _ = dist_v; // autofix
                _ = dual_v; // autofix
            }
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
