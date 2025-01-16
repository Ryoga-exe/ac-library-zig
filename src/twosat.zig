const std = @import("std");
const SccGraph = @import("internal_scc.zig").SccGraph;
const TwoSat = @This();
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

allocator: Allocator,
n: usize,
scc: SccGraph,
answer: []bool,

pub fn init(allocator: Allocator, n: usize) Allocator.Error!TwoSat {
    return TwoSat{
        .allocator = allocator,
        .n = n,
        .scc = SccGraph.init(allocator, 2 * n),
        .answer = try allocator.alloc(bool, n),
    };
}

pub fn deinit(self: *TwoSat) void {
    self.scc.deinit();
    self.allocator.free(self.answer);
}

pub fn addClause(self: *TwoSat, i: usize, f: bool, j: usize, g: bool) Allocator.Error!void {
    assert(i < self.n and j < self.n);
    try self.scc.addEdge(2 * i + @intFromBool(!f), 2 * j + @intFromBool(g));
    try self.scc.addEdge(2 * j + @intFromBool(!g), 2 * i + @intFromBool(f));
}

pub fn satisfiable(self: *TwoSat) Allocator.Error!bool {
    const id = (try self.scc.sccIds()).@"1";
    defer self.allocator.free(id);
    for (0..self.n) |i| {
        if (id[2 * i] == id[2 * i + 1]) {
            return false;
        }
        self.answer[i] = id[2 * i] < id[2 * i + 1];
    }
    return true;
}
