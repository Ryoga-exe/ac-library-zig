const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn FenwickTree(comptime T: type, comptime e: T, comptime op: fn (T, T) T) type {
    return struct {
        const Self = @This();

        n: usize,
        data: []T,
        allocator: Allocator,

        pub fn init(allocator: Allocator, n: usize) !Self {
            const self = Self{
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
            assert(idx < self.n);
            var p = idx + 1;
            while (p <= self.n) {
                self.data[p - 1] = op(self.data[p - 1], val);
                p += p & (~p +% 1);
            }
        }
        pub fn sum(self: *Self, l: usize, r: usize) T {
            assert(l <= r and r <= self.n);
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

pub const FenwickTreeI64 = FenwickTree(i64, 0, operation(i64).addition);
pub const FenwickTreeI32 = FenwickTree(i32, 0, operation(i32).addition);

fn operation(comptime T: type) type {
    return struct {
        pub fn addition(x: T, y: T) T {
            return x + y;
        }
        pub fn bitAnd(x: T, y: T) T {
            return x & y;
        }
        pub fn bitXor(x: T, y: T) T {
            return x ^ y;
        }
    };
}

test "FenwickTree works" {
    const allocator = std.testing.allocator;
    var bit = try FenwickTreeI64.init(allocator, 5);
    defer bit.deinit();
    // [1, 2, 3, 4, 5]
    for (0..5) |i| {
        bit.add(i, @intCast(i + 1));
    }
    try std.testing.expectEqual(@as(i64, 15), bit.sum(0, 5));
    try std.testing.expectEqual(@as(i64, 10), bit.sum(0, 4));
    try std.testing.expectEqual(@as(i64, 5), bit.sum(1, 3));

    // [1, 2, 6, 4, 5]
    bit.add(2, 3);
    try std.testing.expectEqual(@as(i64, 18), bit.sum(0, 5));
    try std.testing.expectEqual(@as(i64, 12), bit.sum(1, 4));
    try std.testing.expectEqual(@as(i64, 6), bit.sum(2, 3));
}
