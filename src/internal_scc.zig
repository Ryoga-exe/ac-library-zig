const std = @import("std");
const Allocator = std.mem.Allocator;

pub const SccGraph = struct {
    const Self = @This();

    n: usize,
    edges: []std.ArrayList(usize),
    allocator: Allocator,

    pub fn init(allocator: Allocator, n: usize) !Self {
        var self = Self{
            .n = n,
            .edges = try allocator.alloc(std.ArrayList(usize), n),
            .allocator = allocator,
        };
        for (0..self.n) |i| {
            self.edges[i] = std.ArrayList(usize).init(allocator);
        }
        return self;
    }
    pub fn deinit(self: *Self) void {
        for (self.edges) |*edge| {
            edge.deinit();
        }
        self.allocator.free(self.edges);
    }
    pub fn numVertices(self: Self) usize {
        return self.n;
    }
    pub fn addEdge(self: *Self, from: usize, to: usize) !void {
        try self.edges[from].append(to);
    }
    pub fn sccIds(self: Self) std.meta.Tuple(&.{ usize, usize }) {
        _ = self;
    }
};
