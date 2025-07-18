//! Implementation of the [Maximum flow problem](https://en.wikipedia.org/wiki/Maximum_flow_problem) solver.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const internal = @import("internal_queue.zig");

/// Dinic-based [Maximum flow problem](https://en.wikipedia.org/wiki/Maximum_flow_problem) solver.
///
/// `MfGraph` models a directed network with capacities on the edges and
/// efficiently computes **maximum flow** as well as a corresponding
/// **minimum s-t cut**.
///
/// `Cap` is the type of the capacity.
///
/// Initialize with `init`.
/// Is owned by the caller and should be freed with `deinit`.
///
/// Internally, for each edge $e$, it stores the flow amount $f_e$ and the capacity $c_e$.
/// Let $\mathrm{out}(v)$ and $\mathrm{in}(v)$ be the set of edges starts and ends at $v$, respectively.
/// For each vertex $v$, let $g(v, f) = \sum_{e \in \mathrm{in}(v)}{f_e} - \sum_{e \in \mathrm{out}(v)}{f_e}$.
///
/// # Constraints
///
/// - `Cap` must be signed integer types.
pub fn MfGraph(comptime Cap: type) type {
    const InternalEdge = struct {
        to: usize,
        rev: usize,
        cap: Cap,
    };

    const Position = ArrayList(struct { usize, usize });
    const Graph = ArrayList(InternalEdge);

    return struct {
        const Self = @This();

        /// Represents a (forward) edge in the residual network.
        ///
        /// Each edge has a source vertex (`from`), a destination vertex (`to`),
        /// a original capacity (`cap`), the current flow (`flow`).
        pub const Edge = struct {
            from: usize,
            to: usize,
            cap: Cap,
            flow: Cap,
        };

        allocator: Allocator,

        /// The size of the vertices.
        n: usize,

        /// Positions of forward edges
        pos: Position,

        /// Residual graph
        g: []Graph,

        /// Creates adirected graph with `n` vertices and no edges.
        /// Must be deinitialized with `deinit`.
        ///
        /// # Constraints
        ///
        /// - $0 \leq n < 10^8$
        ///
        /// # Complexity
        ///
        /// - $O(n)$
        pub fn init(allocator: Allocator, n: usize) Allocator.Error!Self {
            const g = try allocator.alloc(Graph, n);
            for (g) |*item| {
                item.* = .init(allocator);
            }
            return Self{
                .allocator = allocator,
                .n = n,
                .pos = .init(allocator),
                .g = g,
            };
        }

        /// Release all allocated memory.
        pub fn deinit(self: Self) void {
            self.pos.deinit();
            for (self.g) |item| {
                item.deinit();
            }
            self.allocator.free(self.g);
        }

        /// Adds an edge oriented from `from` to `to` with capacity `cap`.
        /// Returns an integer k such that this is the k-th edge that is added.
        ///
        /// # Constraints
        ///
        /// - $0 \leq$ `from` $< n$
        /// - $0 \leq$ `to` $< n$
        /// - `from` $\neq$ `to`
        /// - $0 \leq$ `cap`
        ///
        /// # Panics
        ///
        /// Panics if the above constraint is not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O(1)$ amortized
        pub fn addEdge(self: *Self, from: usize, to: usize, cap: Cap) Allocator.Error!usize {
            assert(from < self.n);
            assert(to < self.n);
            assert(0 <= cap);
            const m = self.pos.items.len;
            try self.pos.append(.{ from, self.g[from].items.len });
            const rev = self.g[to].items.len + @intFromBool(from == to);
            try self.g[from].append(InternalEdge{ .to = to, .rev = rev, .cap = cap });
            const rev2 = self.g[from].items.len - 1;
            try self.g[to].append(InternalEdge{
                .to = from,
                .rev = rev2,
                .cap = 0,
            });
            return m;
        }

        /// Returns the current internal state of the `i`-th edge.
        /// The edges are ordered in the same order as added by `addEdge`.
        ///
        /// # Constraints
        ///
        /// - $0 \leq i < m$
        ///
        /// # Panics
        ///
        /// Panics if the above constraint is not satisfied.
        pub fn getEdge(self: Self, i: usize) Edge {
            const g = self.g;
            const pos = self.pos.items;
            const m = pos.len;
            assert(i < m);

            const e = g[pos[i].@"0"].items[pos[i].@"1"];
            const re = g[e.to].items[e.rev];
            return Edge{
                .from = pos[i].@"0",
                .to = e.to,
                .cap = e.cap + re.cap,
                .flow = re.cap,
            };
        }

        /// Returns cloned of the current internal state of the edges.
        /// The edges are ordered in the same order as added by `addEdge`.
        ///
        /// The caller owns the returned memory, and caller should  free with `allocator.free`.
        pub fn edges(self: Self) Allocator.Error![]Edge {
            const m = self.pos.items.len;
            var result = try self.allocator.alloc(Edge, m);
            for (0..m) |i| {
                result[i] = self.getEdge(i);
            }
            return result;
        }

        /// Overwrite the capacity/flow of the `i`-th edge.
        /// Changes the capacity and the flow amount of the `i`-th edge to `new_cap` and `new_flow`, respectively.
        /// It doesn't change the capacity or the flow amount of other edges.
        ///
        /// # Constraints
        ///
        /// - $0 \leq i < m$
        /// - $0 \leq$ `new_flow` $\leq$ `new_cap`
        ///
        /// # Panics
        ///
        /// Panics if the above constraint is not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O(1)$
        pub fn changeEdge(self: *Self, i: usize, new_cap: Cap, new_flow: Cap) void {
            const pos = self.pos.items;
            const m = pos.len;
            assert(i < m);
            assert(0 <= new_flow and new_flow <= new_cap);
            var e = self.g[pos[i].@"0"].items[self.pos[i].@"1"].*;
            e.cap = new_cap - new_flow;
            self.g[e.to].items[e.rev].cap = new_flow;
        }

        /// Augments the flow from `s` to `t` as much as possible.
        /// Returns the amount of the flow augmented.
        ///
        /// It changes the flow amount of each edge.
        /// Let $f_e$ and $f_e'$ be the flow amount of edge $e$ before and after calling it, respectively.
        /// Precisely, it changes the flow amount as follows.
        ///
        /// - $0 \leq f_e' \leq c_e$
        /// - $g(v, f) = g(v, f')$ holds for all vertices $v$ other than $s$ and $t$.
        /// - $g(t, f') - g(t, f)$ is maximized under these conditions. It returns this $g(t, f') - g(t, f)$.
        ///
        /// # Constraints
        ///
        /// - $s \neq t$
        /// - $0 \leq s, t \lt n$
        /// - The answer should be in `Cap`.
        ///
        /// # Panics
        ///
        /// Panics if the above constraint is not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O((n + m) \sqrt{m})$ (if all the capacities are $1$),
        /// - $O(n^2 m)$ (general), or
        /// - $O(F(n + m))$, where $F$ is the returned value
        ///
        /// where $m$ is the number of added edges.
        pub fn flow(self: *Self, s: usize, t: usize) Allocator.Error!Cap {
            return self.flowWithCapacity(s, t, std.math.maxInt(Cap));
        }

        /// Auguments the flow from `s` to `t` as much as possible, until reaching the amount of `flow_limit`.
        /// Returns the amount of the flow augmented.
        ///
        /// It changes the flow amount of each edge.
        /// Let $f_e$ and $f_e'$ be the flow amount of edge $e$ before and after calling it, respectively.
        /// Precisely, it changes the flow amount as follows.
        ///
        /// - $0 \leq f_e' \leq c_e$
        /// - $g(v, f) = g(v, f')$ holds for all vertices $v$ other than $s$ and $t$.
        /// - $g(t, f') - g(t, f) \leq$ `flow_limit`
        /// - $g(t, f') - g(t, f)$ is maximized under these conditions. It returns this $g(t, f') - g(t, f)$.
        ///
        /// # Constraints
        ///
        /// - $s \neq t$
        /// - $0 \leq s, t \lt n$
        /// - The answer should be in `Cap`.
        ///
        /// # Panics
        ///
        /// Panics if the above constraint is not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O((n + m) \sqrt{m})$ (if all the capacities are $1$),
        /// - $O(n^2 m)$ (general), or
        /// - $O(F(n + m))$, where $F$ is the returned value
        ///
        /// where $m$ is the number of added edges.
        pub fn flowWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) Allocator.Error!Cap {
            const n = self.n;
            assert(s < n);
            assert(t < n);
            assert(s != t);
            assert(0 <= flow_limit);

            var flowCalc = struct {
                const Calc = @This();

                graph: *Self,
                s: usize,
                t: usize,
                flow_limit: Cap,
                level: []i32,
                iter: []usize,
                que: internal.SimpleQueue(usize),

                pub fn bfs(calc: *Calc) Allocator.Error!void {
                    @memset(calc.level, -1);
                    calc.level[calc.s] = 0;
                    calc.que.clearAndFree();
                    try calc.que.push(calc.s);
                    while (calc.que.pop()) |v| {
                        for (calc.graph.g[v].items) |e| {
                            if (e.cap == 0 or calc.level[e.to] >= 0) {
                                continue;
                            }
                            calc.level[e.to] = calc.level[v] + 1;
                            if (e.to == calc.t) {
                                return;
                            }
                            try calc.que.push(e.to);
                        }
                    }
                }
                pub fn dfs(calc: *Calc, v: usize, up: Cap) Allocator.Error!Cap {
                    if (v == calc.s) {
                        return up;
                    }
                    var res: Cap = 0;
                    const level_v = calc.level[v];
                    for (calc.iter[v]..calc.graph.g[v].items.len) |i| {
                        calc.iter[v] = i;
                        const e = calc.graph.g[v].items[i];
                        if (level_v <= calc.level[e.to] or calc.graph.g[e.to].items[e.rev].cap == 0) {
                            continue;
                        }
                        const d = try calc.dfs(e.to, @min(up - res, calc.graph.g[e.to].items[e.rev].cap));
                        if (d <= 0) {
                            continue;
                        }
                        calc.graph.g[v].items[i].cap += d;
                        calc.graph.g[e.to].items[e.rev].cap -= d;
                        res += d;
                        if (res == up) {
                            return res;
                        }
                    }
                    calc.iter[v] = calc.graph.g[v].items.len;
                    return res;
                }
            }{
                .graph = self,
                .s = s,
                .t = t,
                .flow_limit = flow_limit,
                .level = try self.allocator.alloc(i32, n),
                .iter = try self.allocator.alloc(usize, n),
                .que = .init(self.allocator),
            };
            defer {
                self.allocator.free(flowCalc.level);
                self.allocator.free(flowCalc.iter);
                flowCalc.que.deinit();
            }

            var result: Cap = 0;
            while (result < flow_limit) {
                try flowCalc.bfs();
                if (flowCalc.level[t] == -1) {
                    break;
                }
                @memset(flowCalc.iter, 0);
                while (result < flow_limit) {
                    const f = try flowCalc.dfs(t, flow_limit - result);
                    if (f == 0) {
                        break;
                    }
                    result += f;
                }
            }
            return result;
        }

        /// Returns a boolean slice of length `n`, such that the `i`-th element is `true`
        /// if and only if there is a directed path from `s` to `i` in the residual network.
        /// The returned slice corresponds to a s-t minimum cut after calling `flow(s, t)` exactly once.
        ///
        /// The residual network is the graph whose edge set is given by gathering $(u, v)$
        /// for each edge $e = (u, v, f_e, c_e)$ with $f_e < c_e$ and $(v, u)$ for each edge $e$ with $0 < f_e$.
        /// Returns the set of the vertices that is reachable from `s` in the residual network.
        ///
        /// # Complexity
        ///
        /// - $O(n + m)$, where $m$ is the number of added edges.
        pub fn minCut(self: Self, s: usize) Allocator.Error![]bool {
            var visited = try self.allocator.alloc(bool, self.n);
            @memset(visited, false);

            var que = try internal.SimpleQueue(usize).initCapacity(self.allocator, self.n);
            defer que.deinit();
            que.pushAssumeCapacity(s);

            while (que.pop()) |p| {
                visited[p] = true;
                for (self.g[p].items) |e| {
                    if (e.cap != 0 and !visited[e.to]) {
                        visited[e.to] = true;
                        que.pushAssumeCapacity(e.to);
                    }
                }
            }
            return visited;
        }
    };
}

const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;
test "test_max_flow_wikipedia" {
    // From https://commons.wikimedia.org/wiki/File:Min_cut.png
    // Under CC BY-SA 3.0 https://creativecommons.org/licenses/by-sa/3.0/deed.en
    const allocator = testing.allocator;
    const MfGraphI32 = MfGraph(i32);

    var graph = try MfGraphI32.init(allocator, 6);
    defer graph.deinit();

    try expectEqual(0, try graph.addEdge(0, 1, 3));
    try expectEqual(1, try graph.addEdge(0, 2, 3));
    try expectEqual(2, try graph.addEdge(1, 2, 2));
    try expectEqual(3, try graph.addEdge(1, 3, 3));
    try expectEqual(4, try graph.addEdge(2, 4, 2));
    try expectEqual(5, try graph.addEdge(3, 4, 4));
    try expectEqual(6, try graph.addEdge(3, 5, 2));
    try expectEqual(7, try graph.addEdge(4, 5, 3));

    try expectEqual(5, try graph.flow(0, 5));

    const edges = try graph.edges();
    defer allocator.free(edges);
    try expectEqualSlices(MfGraphI32.Edge, &.{
        .{ .from = 0, .to = 1, .cap = 3, .flow = 3 },
        .{ .from = 0, .to = 2, .cap = 3, .flow = 2 },
        .{ .from = 1, .to = 2, .cap = 2, .flow = 0 },
        .{ .from = 1, .to = 3, .cap = 3, .flow = 3 },
        .{ .from = 2, .to = 4, .cap = 2, .flow = 2 },
        .{ .from = 3, .to = 4, .cap = 4, .flow = 1 },
        .{ .from = 3, .to = 5, .cap = 2, .flow = 2 },
        .{ .from = 4, .to = 5, .cap = 3, .flow = 3 },
    }, edges);

    const minCut = try graph.minCut(0);
    defer allocator.free(minCut);
    try expectEqualSlices(bool, &.{ true, false, true, false, false, false }, minCut);
}

test "test_max_flow_wikipedia_multiple_edges" {
    // From https://commons.wikimedia.org/wiki/File:Min_cut.png
    // Under CC BY-SA 3.0 https://creativecommons.org/licenses/by-sa/3.0/deed.en
    const allocator = testing.allocator;
    const MfGraphI32 = MfGraph(i32);

    var graph = try MfGraphI32.init(allocator, 6);
    defer graph.deinit();
    for ([_]struct { usize, usize, usize }{
        .{ 0, 1, 3 },
        .{ 0, 2, 3 },
        .{ 1, 2, 2 },
        .{ 1, 3, 3 },
        .{ 2, 4, 2 },
        .{ 3, 4, 4 },
        .{ 3, 5, 2 },
        .{ 4, 5, 3 },
    }) |edge| {
        const u, const v, const c = edge;
        for (0..c) |_| {
            _ = try graph.addEdge(u, v, 1);
        }
    }

    try expectEqual(5, try graph.flow(0, 5));

    const minCut = try graph.minCut(0);
    defer allocator.free(minCut);
    try expectEqualSlices(bool, &.{ true, false, true, false, false, false }, minCut);
}

test "test_max_flow_misawa" {
    // Originally by @MiSawa
    // From https://gist.github.com/MiSawa/47b1d99c372daffb6891662db1a2b686
    const allocator = testing.allocator;
    const MfGraphI32 = MfGraph(i32);

    const n = 100;
    var graph = try MfGraphI32.init(allocator, (n + 1) * 2 + 5);
    defer graph.deinit();

    const s, const a, const b, const c, const t = .{ 0, 1, 2, 3, 4 };
    _ = try graph.addEdge(s, a, 1);
    _ = try graph.addEdge(s, b, 2);
    _ = try graph.addEdge(b, a, 2);
    _ = try graph.addEdge(c, t, 2);
    for (0..n) |index| {
        const i = 2 * index + 5;
        for (0..2) |j| {
            for (2..4) |k| {
                _ = try graph.addEdge(i + j, i + k, 3);
            }
        }
    }
    for (0..2) |j| {
        _ = try graph.addEdge(a, 5 + j, 3);
        _ = try graph.addEdge(2 * n + 5 + j, c, 3);
    }

    try expectEqual(2, try graph.flow(s, t));
}

test "test_dont_repeat_same_phase" {
    const allocator = testing.allocator;
    const MfGraphI32 = MfGraph(i32);

    const n = 100_000;
    var graph = try MfGraphI32.init(allocator, 3);
    defer graph.deinit();
    _ = try graph.addEdge(0, 1, n);
    for (0..n) |_| {
        _ = try graph.addEdge(1, 2, 1);
    }
    try expectEqual(n, try graph.flow(0, 2));
}
