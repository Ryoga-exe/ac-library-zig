const std = @import("std");
const Csr = @import("internal_csr.zig").Csr;
const Allocator = std.mem.Allocator;

pub const SccGraph = struct {
    const Self = @This();

    const Edge = struct {
        to: usize,
    };

    n: usize,
    edges: std.ArrayList(std.meta.Tuple(.{ usize, Edge })),
    allocator: Allocator,

    pub fn init(allocator: Allocator, n: usize) Self {
        var self = Self{
            .n = n,
            .edges = std.ArrayList(std.meta.Tuple(.{ usize, Edge })).init(allocator),
            .allocator = allocator,
        };
        return self;
    }
    pub fn deinit(self: *Self) void {
        self.edges.deinit();
    }
    pub fn numVertices(self: Self) usize {
        return self.n;
    }
    pub fn addEdge(self: *Self, from: usize, to: usize) !void {
        try self.edges.append(.{ from, Edge{ .to = to } });
    }
    pub fn sccIds(self: Self) std.meta.Tuple(&.{ usize, usize }) {
        var env = struct {
            g: Csr(Edge),
            now_ord: usize,
            group_num: usize,
            visited: []usize,
            low: []usize,
            ord: []?usize,
            ids: []usize,
        }{
            .g = Csr(Edge).init(self.allocator, self.n, self.edges, Edge{ .to = 0 }),
            .now_ord = 0,
            .group_num = 0,
            .visited = self.allocator.alloc(usize, self.n),
            .low = self.allocator.alloc(usize, self.n),
            .ord = self.allocator.alloc(?usize, self.n),
            .ids = self.allocator.alloc(usize, self.n),
        };

        @memset(env.low, 0);
        @memset(env.ord, null);
        @memset(env.ids, 0);

        defer {
            self.allocator.free(env.visited);
            self.allocator.free(env.low);
            self.allocator.free(env.ord);
            self.allocator.free(env.ids);
        }
    }
};
