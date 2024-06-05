const std = @import("std");
const Allocator = std.mem.Allocator;
const internal = @import("internal_bit.zig");
const assert = std.debug.assert;

pub fn LazySegtree(
    comptime S: type,
    comptime op: fn (S, S) S,
    comptime e: fn () S,
    comptime F: type,
    comptime mapping: fn (F, S) S,
    comptime composition: fn (F, F) F,
    comptime id: fn () F,
) type {
    return struct {
        const Self = @This();

        n: usize,
        size: usize,
        log: usize,
        d: []S,
        lz: []F,
        allocator: Allocator,

        pub fn init(allocator: Allocator, n: usize) !Self {
            const size = internal.bitCeil(n);
            const log = @ctz(size);
            const self = Self{
                .n = n,
                .size = size,
                .log = log,
                .d = try allocator.alloc(S, 2 * size),
                .lz = try allocator.alloc(F, size),
                .allocator = allocator,
            };
            @memset(self.d, e());
            @memset(self.lz, id());
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
                .lz = try allocator.alloc(F, size),
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
            self.allocator.free(self.lz);
        }
        pub fn set(self: *Self, pos: usize, x: S) void {
            assert(pos < self.n);
            const p = pos + self.size;
            var i: usize = self.log;
            while (i >= 1) : (i -= 1) {
                self.push(p >> @intCast(i));
            }
            self.d[p] = x;
            for (1..self.log + 1) |k| {
                self.update(p >> @intCast(k));
            }
        }
        pub fn get(self: *Self, pos: usize) S {
            assert(pos < self.n);
            const p = pos + self.size;
            var i: usize = self.log;
            while (i >= 1) : (i -= 1) {
                self.push(p >> i);
            }
            return self.d[p];
        }
        // pub fn getSlice(self: *Self) []S {
        //     _ = self;
        // }
        pub fn prod(self: *Self, left: usize, right: usize) S {
            assert(left <= right and right <= self.n);
            if (left == right) {
                return e();
            }
            var l = left + self.size;
            var r = right + self.size;

            var i: usize = self.log;
            while (i >= 1) : (i -= 1) {
                if (((l >> @intCast(i)) << @intCast(i)) != l) {
                    self.push(l >> @intCast(i));
                }
                if (((r >> @intCast(i)) << @intCast(i)) != r) {
                    self.push((r - 1) >> @intCast(i));
                }
            }

            var sml = e();
            var smr = e();
            while (l < r) : ({
                l >>= 1;
                r >>= 1;
            }) {
                if (l & 1 != 0) {
                    sml = op(sml, self.d[l]);
                    l += 1;
                }
                if (r & 1 != 0) {
                    r -= 1;
                    smr = op(self.d[r], smr);
                }
            }

            return op(sml, smr);
        }
        pub fn allProd(self: Self) S {
            return self.d[1];
        }
        pub fn apply(self: *Self, pos: usize, f: F) void {
            assert(pos < self.n);
            const p = pos + self.size;
            var i: usize = self.log;
            while (i >= 1) : (i -= 1) {
                self.push(p >> @intCast(i));
            }
            self.d[p] = mapping(f, self.d[p]);
            i = 1;
            while (i <= self.log) : (i += 1) {
                self.update(p >> @intCast(i));
            }
        }
        pub fn applyRange(self: *Self, left: usize, right: usize, f: F) void {
            assert(left <= right and right <= self.n);
            if (left == right) {
                return;
            }

            var l = left + self.size;
            var r = right + self.size;

            var i: usize = self.log;
            while (i >= 1) : (i -= 1) {
                if (((l >> @intCast(i)) << @intCast(i)) != l) {
                    self.push(l >> @intCast(i));
                }
                if (((r >> @intCast(i)) << @intCast(i)) != r) {
                    self.push((r - 1) >> @intCast(i));
                }
            }

            {
                const l2 = l;
                const r2 = r;
                while (l < r) {
                    if (l & 1 != 0) {
                        self.allApply(l, f);
                        l += 1;
                    }
                    if (r & 1 != 0) {
                        r -= 1;
                        self.allApply(r, f);
                    }
                    l >>= 1;
                    r >>= 1;
                }
                l = l2;
                r = r2;
            }

            i = 1;
            while (i <= self.log) : (i += 1) {
                if (((l >> @intCast(i)) << @intCast(i)) != l) {
                    self.update(l >> @intCast(i));
                }
                if (((r >> @intCast(i)) << @intCast(i)) != r) {
                    self.update((r - 1) >> @intCast(i));
                }
            }
        }
        pub fn maxRight(self: *Self, left: usize, comptime g: fn (S) bool) usize {
            assert(left <= self.n);
            assert(g(e()));

            if (left == self.n) {
                return self.n;
            }
            const l = left + self.size;
            var i: usize = self.log;
            while (i >= 1) : (i -= 1) {
                self.push(l >> i);
            }
            var sm = e();
            while (true) {
                while (l % 2 == 0) {
                    l >>= 1;
                }
                if (!g(op(sm, self.d[l]))) {
                    while (l < self.size) {
                        self.push(l);
                        l *= 2;
                        const res = op(sm, self.d[l]);
                        if (g(res)) {
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
        pub fn minLeft(self: *Self, right: usize, comptime g: fn (S) bool) usize {
            assert(right <= self.n);
            assert(g(e()));

            if (right == 0) {
                return 0;
            }
            const r = right + self.size;
            var i: usize = self.log;
            while (i >= 1) : (i -= 1) {
                self.push((r - 1) >> i);
            }
            var sm = e();
            while (true) {
                r -= 1;
                while (r > 1 and r % 2 != 0) {
                    r >>= 1;
                }
                if (!g(op(self.d[r], sm))) {
                    while (r < self.size) {
                        self.push(r);
                        r = 2 * r + 1;
                        const res = op(self.d[r], sm);
                        if (g(res)) {
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
        fn allApply(self: *Self, k: usize, f: F) void {
            self.d[k] = mapping(f, self.d[k]);
            if (k < self.size) {
                self.lz[k] = composition(f, self.lz[k]);
            }
        }
        fn push(self: *Self, k: usize) void {
            self.allApply(2 * k, self.lz[k]);
            self.allApply(2 * k + 1, self.lz[k]);
            self.lz[k] = id();
        }
    };
}

test "Segtree: ALPC-L sample" {
    // https://atcoder.jp/contests/practice2/tasks/practice2_l
    const n = 5;
    const a = &[_]i64{ 0, 1, 0, 0, 1 };
    const query = &[_]struct {
        t: usize,
        l: usize,
        r: usize,
        expect: ?i64,
    }{
        .{ .t = 2, .l = 1, .r = 5, .expect = 2 },
        .{ .t = 1, .l = 3, .r = 4, .expect = null },
        .{ .t = 2, .l = 2, .r = 5, .expect = 0 },
        .{ .t = 1, .l = 1, .r = 3, .expect = null },
        .{ .t = 2, .l = 1, .r = 2, .expect = 1 },
    };
    const allocator = std.testing.allocator;
    var seg = try LazySegtree(
        tests.S,
        tests.op,
        tests.e,
        tests.F,
        tests.mapping,
        tests.composition,
        tests.id,
    ).init(allocator, n);
    defer seg.deinit();

    for (0..n) |i| {
        if (a[i] == 0) {
            seg.set(i, tests.S{ .zero = 1, .one = 0, .inversion = 0 });
        } else {
            seg.set(i, tests.S{ .zero = 0, .one = 1, .inversion = 0 });
        }
    }

    for (query) |q| {
        var result: ?i64 = null;
        if (q.t == 1) {
            seg.applyRange(q.l, q.r, true);
        } else {
            result = seg.prod(q.l, q.r).inversion;
        }
        try std.testing.expectEqual(q.expect, result);
    }
}

const tests = struct {
    const S = struct {
        zero: i64,
        one: i64,
        inversion: i64,
    };
    const F = bool;
    fn op(l: S, r: S) S {
        return S{
            .zero = l.zero + r.zero,
            .one = l.one + r.zero,
            .inversion = l.inversion + r.inversion + l.one * r.zero,
        };
    }
    fn e() S {
        return S{ .zero = 0, .one = 0, .inversion = 0 };
    }
    fn mapping(l: F, r: S) S {
        if (!l) {
            return r;
        }
        // swap
        return S{
            .zero = r.one,
            .one = r.zero,
            .inversion = r.one * r.zero - r.inversion,
        };
    }
    fn composition(l: F, r: F) F {
        return (l and !r) or (!l and r);
    }
    fn id() F {
        return false;
    }
};
