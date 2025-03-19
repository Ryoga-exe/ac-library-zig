const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const internal = @import("internal_csr.zig");
const math = std.math;
const assert = std.debug.assert;

/// Solves [Minimum-cost flow problem](https://en.wikipedia.org/wiki/Minimum-cost_flow_problem).
///
/// `Cap` and `Cost` are the type of the capacity and the cost, respectively.
///
/// Initialize with `init`.
/// Is owned by the caller and should be freed with `deinit`.
///
/// # Constraints
///
/// - `Cap` and `Cost` must be signed integers.
pub fn McfGraph(comptime Cap: type, comptime Cost: type) type {
    comptime {
        if (!isSignedInteger(Cap)) {
            @compileError("Cap must be a signed integer.");
        }
        if (!isSignedInteger(Cost)) {
            @compileError("Cost must be a signed integer.");
        }
    }
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

        /// Creates adirected graph with `n` vertices and `0` edges.
        /// Deinitialize with `deinit`.
        ///
        /// # Constraints
        ///
        /// - $0 \leq n < 10^8$
        ///
        /// # Complexity
        ///
        /// - $O(n)$
        pub fn init(allocator: Allocator, n: usize) Self {
            return Self{
                .allocator = allocator,
                .edges = .init(allocator),
                .n = n,
            };
        }

        /// Release all allocated memory.
        pub fn deinit(self: *Self) void {
            self.edges.deinit();
        }

        /// Adds an edge oriented from `from` to `to` with capacity `cap` and cost `cost`.
        /// Returns an integer k such that this is the k-th edge that is added.
        ///
        /// # Constraints
        ///
        /// - $0 \leq$ `from` $< n$
        /// - $0 \leq$ `to` $< n$
        /// - $0 \leq$ `cap`, `cost`
        ///
        /// # Complexity
        ///
        /// - $O(1)$ amortized
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
            return self.flowWithCapacity(s, t, math.maxInt(Cap));
        }

        pub fn flowWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) Allocator.Error!CapCostPair {
            const result = try self.slopeWithCapacity(s, t, flow_limit);
            defer self.allocator.free(result);
            return result[result.len - 1];
        }

        pub fn slope(self: *Self, s: usize, t: usize) Allocator.Error![]CapCostPair {
            return self.slopeWithCapacity(s, t, math.maxInt(Cap));
        }

        pub fn slopeWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) Allocator.Error![]CapCostPair {
            const n = self.n;
            const allocator = self.allocator;
            assert(0 <= s and s < n);
            assert(0 <= t and t < n);
            assert(s != t);

            const m = self.edges.items.len;
            var edge_idx = try allocator.alloc(usize, m);
            defer allocator.free(edge_idx);

            var g = blk: {
                var degree = try allocator.alloc(usize, n);
                defer allocator.free(degree);
                @memset(degree, 0);
                var redge_idx = try allocator.alloc(usize, m);
                defer allocator.free(redge_idx);

                var elist = try ArrayList(struct { usize, InsideEdge }).initCapacity(allocator, 2 * m);
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
                var g = try internal.Csr(InsideEdge).init(allocator, n, elist, .zero);
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
                const dual_dist = try allocator.alloc(struct { Cost, Cost }, n);
                defer allocator.free(dual_dist);
                @memset(dual_dist, .{ 0, 0 });
                const prev_e = try allocator.alloc(usize, n);
                defer allocator.free(prev_e);
                @memset(prev_e, 0);
                const vis = try allocator.alloc(bool, n);
                defer allocator.free(vis);

                var flow_current: Cap = 0;
                var cost_current: Cost = 0;
                var prev_cost_per_flow: Cost = -1;
                var result = ArrayList(CapCostPair).init(allocator);
                try result.append(CapCostPair{ 0, 0 });
                while (flow_current < flow_limit) {
                    if (!try self.refineDual(s, t, g, dual_dist, vis, prev_e)) {
                        break;
                    }
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
                    const d = -dual_dist[s].@"0";
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

        fn refineDual(
            self: Self,
            s: usize,
            t: usize,
            g: internal.Csr(InsideEdge),
            dual: []struct { Cost, Cost },
            vis: []bool,
            prev_e: []usize,
        ) Allocator.Error!bool {
            const allocator = self.allocator;
            for (0..self.n) |i| {
                dual[i].@"1" = math.maxInt(Cost);
            }
            @memset(vis, false);

            const Q = struct {
                const Q = @This();
                key: Cost,
                to: usize,
                fn lessThan(_: void, a: Q, b: Q) math.Order {
                    return math.order(a.key, b.key);
                }
            };
            var que_min = ArrayList(usize).init(allocator);
            defer que_min.deinit();
            var que = std.PriorityQueue(Q, void, Q.lessThan).init(allocator, {});
            defer que.deinit();

            dual[s].@"1" = 0;
            try que_min.append(s);
            while (que.count() > 0 or que_min.items.len > 0) {
                const v = que_min.pop() orelse que.remove().to;
                if (vis[v]) {
                    continue;
                }
                vis[v] = true;
                if (v == t) {
                    break;
                }
                const dual_v, const dist_v = dual[v];
                for (g.start[v]..g.start[v + 1]) |i| {
                    const e = g.elist[i];
                    if (e.cap == 0) {
                        continue;
                    }
                    const cost = e.cost - dual[e.to].@"0" + dual_v;
                    if (dual[e.to].@"1" - dist_v > cost) {
                        const dist_to = dist_v + cost;
                        dual[e.to].@"1" = dist_to;
                        prev_e[e.to] = e.rev;
                        if (dist_to == dist_v) {
                            try que_min.append(e.to);
                        } else {
                            try que.add(Q{ .key = dist_to, .to = e.to });
                        }
                    }
                }
            }
            if (!vis[t]) {
                return false;
            }

            for (0..self.n) |v| {
                if (!vis[v]) {
                    continue;
                }
                dual[v].@"0" -= dual[t].@"1" - dual[v].@"1";
            }
            return true;
        }
    };
}

inline fn isSignedInteger(comptime T: type) bool {
    return comptime switch (@typeInfo(T)) {
        .int => |info| info.signedness == .signed,
        else => false,
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
