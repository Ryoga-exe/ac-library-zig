const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const internal = @import("internal_queue.zig");

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

        pub const Edge = struct {
            from: usize,
            to: usize,
            cap: Cap,
            flow: Cap,
        };

        allocator: Allocator,
        n: usize,
        pos: Position,
        g: []Graph,

        pub fn init(allocator: Allocator, n: usize) Allocator.Error!Self {
            const g = try allocator.alloc(Graph, n);
            for (g) |*item| {
                item.* = Graph.init(allocator);
            }
            return Self{
                .allocator = allocator,
                .n = n,
                .pos = Position.init(allocator),
                .g = g,
            };
        }

        pub fn deinit(self: Self) void {
            self.pos.deinit();
            for (self.g) |item| {
                item.deinit();
            }
            self.allocator.free(self.g);
        }

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

        pub fn edges(self: Self) Allocator.Error![]Edge {
            const m = self.pos.items.len;
            var result = try self.allocator.alloc(Edge, m);
            for (0..m) |i| {
                result[i] = self.getEdge(i);
            }
            return result;
        }

        pub fn changeEdge(self: *Self, i: usize, new_cap: Cap, new_flow: Cap) void {
            const pos = self.pos.items;
            const m = pos.len;
            assert(i < m);
            assert(0 <= new_flow and new_flow <= new_cap);
            var e = self.g[pos[i].@"0"].items[self.pos[i].@"1"].*;
            e.cap = new_cap - new_flow;
            self.g[e.to].items[e.rev].cap = new_flow;
        }

        pub fn flow(self: *Self, s: usize, t: usize) Allocator.Error!Cap {
            return self.flowWithCapacity(s, t, std.math.maxInt(Cap));
        }

        pub fn flowWithCapacity(self: *Self, s: usize, t: usize, flow_limit: Cap) Allocator.Error!Cap {
            const n = self.n;
            assert(s < n);
            assert(t < n);
            assert(s != t);
            assert(0 <= flow_limit);

            var flowCalc = struct {
                const Calc = @This();

                allocator: Allocator,
                graph: *Self,
                s: usize,
                t: usize,
                flow_limit: Cap,
                level: []i32,
                iter: []usize,
                que: internal.SimpleQueue(usize),

                pub fn deinit(calc: *Calc) void {
                    calc.allocator.free(calc.level);
                    calc.allocator.free(calc.iter);
                    calc.que.deinit();
                }
                pub fn bfs(calc: *Calc) Allocator.Error!void {
                    @memset(calc.level, -1);
                    calc.level[calc.s] = 0;
                    calc.que.clearAndFree();
                    try calc.que.push(calc.s);
                    while (!calc.que.empty()) {
                        const v = calc.que.pop().?;
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
                .allocator = self.allocator,
                .graph = self,
                .s = s,
                .t = t,
                .flow_limit = flow_limit,
                .level = try self.allocator.alloc(i32, n),
                .iter = try self.allocator.alloc(usize, n),
                .que = internal.SimpleQueue(usize).init(self.allocator),
            };
            defer flowCalc.deinit();

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
    for (0..n) |_| {
        _ = try graph.addEdge(1, 2, 1);
    }
    try expectEqual(n, try graph.flow(0, 2));
}
