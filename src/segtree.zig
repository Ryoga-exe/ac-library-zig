const std = @import("std");
const internal = @import("internal_bit.zig");
const Allocator = std.mem.Allocator;

pub fn Segtree(comptime S: type, comptime op: fn (S, S) S, comptime e: fn () S) type {
    return struct {
        const Self = @This();

        n: usize,
        size: usize,
        log: usize,
        d: []S,
        allocator: Allocator,

        pub fn init(allocator: Allocator, n: usize) !Self {
            const size = internal.bitCeil(n);
            const log = @ctz(size);
            var self = Self{
                .n = n,
                .size = size,
                .log = log,
                .d = try allocator.alloc(S, 2 * size),
                .allocator = allocator,
            };
            @memset(self.d, e());
            return self;
        }
        pub fn initFromSlice(allocator: Allocator, v: []const S) !Self {
            const n = v.len;
            const size = internal.bitCeil(n);
            const log = @ctz(size);
            var self = Self{
                .n = n,
                .size = size,
                .log = log,
                .d = try allocator.alloc(S, 2 * size),
                .allocator = allocator,
            };
            @memset(self.d, e());
            for (0..n) |i| {
                self.d[size + i] = v[i];
            }
            var i: usize = size - 1;
            while (i >= 1) : (i -= 1) {
                self.update(i);
            }
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.d);
        }
        pub fn set(self: *Self, pos: usize, x: S) void {
            const p = pos + self.size;
            self.d[p] = x;
            for (1..self.log + 1) |i| {
                self.update(p >> @intCast(i));
            }
        }
        pub fn get(self: *Self, p: usize) S {
            return self.d[p + self.size];
        }
        pub fn getSlice(self: *Self) []S {
            return self.d[self.size .. self.size + self.n];
        }
        pub fn prod(self: *Self, left: usize, right: usize) S {
            var sml = e();
            var smr = e();

            var l = left + self.size;
            var r = right + self.size;

            while (l < r) {
                if (l & 1 != 0) {
                    sml = op(sml, self.d[l]);
                    l += 1;
                }
                if (r & 1 != 0) {
                    r -= 1;
                    smr = op(self.d[r], smr);
                }
                l >>= 1;
                r >>= 1;
            }

            return op(sml, smr);
        }
        pub fn allProd(self: *Self) S {
            return self.d[1];
        }
        pub fn maxRight(self: *Self, left: usize, comptime f: fn (S) bool) usize {
            if (left == self.n) {
                return self.n;
            }
            var l = left + self.size;
            var sm = e();
            while (true) {
                while (l % 2 == 0) {
                    l >>= 1;
                }
                if (!f(op(sm, self.d[l]))) {
                    while (l < self.size) {
                        l *= 2;
                        const res = op(sm, self.d[l]);
                        if (f(res)) {
                            sm = res;
                            l += 1;
                        }
                    }
                    return l - self.size;
                }
                sm = op(sm, self.d[l]);
                l += 1;
                // (l & -l) == l
                if ((l & (~l +% 1)) == l) {
                    break;
                }
            }
            return self.n;
        }
        pub fn minLeft(self: *Self, right: usize, comptime f: fn (S) bool) usize {
            if (right == 0) {
                return 0;
            }
            var r = right + self.size;
            var sm = e();
            while (true) {
                r -= 1;
                while (r > 1 and r % 2 == 1) {
                    r >>= 1;
                }
                if (f(op(self.d[r], sm))) {
                    while (r < self.size) {
                        r = 2 * r + 1;
                        const res = op(self.d[r], sm);
                        if (f(res)) {
                            sm = res;
                            r -= 1;
                        }
                    }
                    return r + 1 - self.size;
                }
                sm = op(self.d[r], sm);
                // (r & -r) == r
                if ((r & (~r +% 1)) == r) {
                    break;
                }
            }
            return 0;
        }
        fn update(self: *Self, k: usize) void {
            self.d[k] = op(self.d[2 * k], self.d[2 * k + 1]);
        }
    };
}

const monoid = struct {
    fn additive(comptime T: type) type {
        return struct {
            fn op(x: T, y: T) T {
                return x + y;
            }
            fn e() T {
                return 0;
            }
        };
    }
    fn max(comptime T: type) type {
        return struct {
            fn op(x: T, y: T) T {
                return @max(x, y);
            }
            fn e() T {
                return 0;
            }
        };
    }
};

const tests = struct {
    var target: usize = 0;
    fn f(v: usize) bool {
        return v < target;
    }
};

test "Segtree works" {
    const allocator = std.testing.allocator;
    const base = &[_]i32{ 3, 1, 4, 1, 5, 9, 2, 6, 5, 3 };
    const n = base.len;
    _ = n;

    var segtree = try Segtree(i32, monoid.additive(i32).op, monoid.additive(i32).e).initFromSlice(allocator, base);
    defer segtree.deinit();
}

test "Segtree: ALPC-J sample" {
    // https://atcoder.jp/contests/practice2/tasks/practice2_j
    const a = &[_]usize{ 1, 2, 3, 2, 1 };
    const query = &[_]struct {
        t: usize,
        x: usize,
        y: usize,
        expect: ?usize,
    }{
        .{ .t = 2, .x = 1, .y = 5, .expect = 3 },
        .{ .t = 3, .x = 2, .y = 3, .expect = 3 },
        .{ .t = 1, .x = 3, .y = 1, .expect = null },
        .{ .t = 2, .x = 2, .y = 4, .expect = 2 },
        .{ .t = 3, .x = 1, .y = 3, .expect = 6 },
    };
    const allocator = std.testing.allocator;
    var segtree = try Segtree(usize, monoid.max(usize).op, monoid.additive(usize).e).initFromSlice(allocator, a);
    defer segtree.deinit();

    try std.testing.expectEqualSlices(usize, &[_]usize{ 1, 2, 3, 2, 1 }, segtree.getSlice());

    for (query) |q| {
        var result: ?usize = null;
        if (q.t == 1) {
            segtree.set(q.x - 1, q.y);
        } else if (q.t == 2) {
            result = segtree.prod(q.x - 1, q.y);
        } else if (q.t == 3) {
            tests.target = q.y;
            result = segtree.maxRight(q.x - 1, tests.f) + 1;
        }
        try std.testing.expectEqual(q.expect, result);
    }
}
