const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn FenwickTreeI(comptime T: type, comptime e: T, comptime op: fn (T, T) T) type {
    return struct {
        const Self = @This();

        n: usize,
        data: []T,
        allocator: Allocator,

        pub fn init(allocator: Allocator, n: usize) !Self {
            var self = Self{
                .n = n,
                .data = try allocator.alloc(T, n),
                .allocator = allocator,
            };
            @memset(self.data, e);
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
        }
        pub fn add(self: *Self, idx: usize, val: T) void {
            var p = idx + 1;
            while (p <= self.n) {
                self.data[p - 1] = op(self.data[p - 1], val);
                p += p & (~p +% 1);
            }
        }
        pub fn sum(self: *Self, l: usize, r: usize) T {
            return self.accum(r) - self.accum(l);
        }
        fn accum(self: *Self, idx: usize) T {
            var r = idx;
            var s = @as(T, e);
            while (r > 0) {
                s += self.data[r - 1];
                r &= r - 1;
            }
            return s;
        }
    };
}

pub const FenwickTree = FenwickTreeI(i64, 0, addition);

fn addition(x: i64, y: i64) i64 {
    return x + y;
}

test "FenwickTree works" {
    const allocator = std.testing.allocator;
    var bit = try FenwickTree.init(allocator, 5);
    defer bit.deinit();
    // [1, 2, 3, 4, 5]
    for (0..5) |i| {
        bit.add(i, @intCast(i + 1));
    }
    try std.testing.expect(bit.sum(0, 5) == 15);
    try std.testing.expect(bit.sum(0, 4) == 10);
    try std.testing.expect(bit.sum(1, 3) == 5);

    // [1, 2, 6, 4, 5]
    bit.add(2, 3);
    try std.testing.expect(bit.sum(0, 5) == 18);
    try std.testing.expect(bit.sum(1, 4) == 12);
    try std.testing.expect(bit.sum(2, 3) == 6);
}
