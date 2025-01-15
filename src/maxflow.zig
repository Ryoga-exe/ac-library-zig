const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn MfGraph(comptime Cap: type) type {
    return struct {
        const Self = @This();

        const Edge = struct {
            from: usize,
            to: usize,
            cap: Cap,
            flow: Cap,
        };

        const InternalEdge = struct {
            to: usize,
            rev: usize,
            cap: Cap,
        };

        const Position = std.ArrayList(struct { usize, usize });
        const Graph = std.ArrayList(InternalEdge);

        allocator: Allocator,
        n: usize,
        pos: Position,
        g: []Graph,

        pub fn init(allocator: Allocator, n: usize) Allocator.Error!Self {
            const g = try allocator.alloc(Graph, n);
            for (g) |*item| {
                item.* = Graph.init(allocator);
            }
            return MfGraph{
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
            const m = self.pos.items.len;
            assert(i < m);
            const e = self.g[self.pos[i].@"0"].items[self.pos[i].@"1"];
            const re = self.g[e.to].items[e.rev];
            return Edge{
                .from = self.pos[i].@"0",
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
            _ = self; // autofix
            _ = i; // autofix
            _ = new_cap; // autofix
            _ = new_flow; // autofix
        }
    };
}
