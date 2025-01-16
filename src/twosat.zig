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

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "TwoSat: ALPC-H sample1" {
    // https://atcoder.jp/contests/practice2/tasks/practice2_h
    const allocator = testing.allocator;

    const n = 3;
    const d = 2;
    const x = [_]i32{ 1, 2, 0 };
    const y = [_]i32{ 4, 5, 6 };

    var t = try TwoSat.init(allocator, n);
    defer t.deinit();

    for (0..n) |i| {
        for (i + 1..n) |j| {
            if (@abs(x[i] - x[j]) < d) {
                try t.addClause(i, false, j, false);
            }
            if (@abs(x[i] - y[j]) < d) {
                try t.addClause(i, false, j, true);
            }
            if (@abs(y[i] - x[j]) < d) {
                try t.addClause(i, true, j, false);
            }
            if (@abs(y[i] - y[j]) < d) {
                try t.addClause(i, true, j, true);
            }
        }
    }
    try expect(try t.satisfiable());
    var res = try allocator.alloc(i32, n);
    defer allocator.free(res);
    for (t.answer, 0..) |v, i| {
        res[i] = if (v) x[i] else y[i];
    }

    // Check the min distance between flags
    std.mem.sortUnstable(i32, res, {}, struct {
        fn lessThan(_: void, lhs: i32, rhs: i32) bool {
            return lhs < rhs;
        }
    }.lessThan);
    var min_distance: i32 = std.math.maxInt(i32);
    for (1..n) |i| {
        min_distance = @min(min_distance, res[i] - res[i - 1]);
    }
    try expect(min_distance >= d);
}

test "TwoSat: ALPC-H sample2" {
    // https://atcoder.jp/contests/practice2/tasks/practice2_h
    const allocator = testing.allocator;

    const n = 3;
    const d = 3;
    const x = [_]i32{ 1, 2, 0 };
    const y = [_]i32{ 4, 5, 6 };

    var t = try TwoSat.init(allocator, n);
    defer t.deinit();

    for (0..n) |i| {
        for (i + 1..n) |j| {
            if (@abs(x[i] - x[j]) < d) {
                try t.addClause(i, false, j, false);
            }
            if (@abs(x[i] - y[j]) < d) {
                try t.addClause(i, false, j, true);
            }
            if (@abs(y[i] - x[j]) < d) {
                try t.addClause(i, true, j, false);
            }
            if (@abs(y[i] - y[j]) < d) {
                try t.addClause(i, true, j, true);
            }
        }
    }
    try expect(!(try t.satisfiable()));
}
