const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
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
            const size = try math.ceilPowerOfTwo(usize, n);
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
            const size = try math.ceilPowerOfTwo(usize, n);
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
            @memset(self.lz, id());
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
            var i: u6 = @intCast(self.log);
            while (i >= 1) : (i -= 1) {
                self.push(p >> i);
            }
            self.d[p] = x;
            i = 1;
            while (i <= self.log) : (i += 1) {
                self.update(p >> i);
            }
        }
        pub fn get(self: *Self, pos: usize) S {
            assert(pos < self.n);
            const p = pos + self.size;
            var i: u6 = @intCast(self.log);
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

            var i: u6 = @intCast(self.log);
            while (i >= 1) : (i -= 1) {
                if (((l >> i) << i) != l) {
                    self.push(l >> i);
                }
                if (((r >> i) << i) != r) {
                    self.push((r - 1) >> i);
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
            var i: u6 = @intCast(self.log);
            while (i >= 1) : (i -= 1) {
                self.push(p >> i);
            }
            self.d[p] = mapping(f, self.d[p]);
            i = 1;
            while (i <= self.log) : (i += 1) {
                self.update(p >> i);
            }
        }
        pub fn applyRange(self: *Self, left: usize, right: usize, f: F) void {
            assert(left <= right and right <= self.n);
            if (left == right) {
                return;
            }

            var l = left + self.size;
            var r = right + self.size;

            var i: u6 = @intCast(self.log);
            while (i >= 1) : (i -= 1) {
                if (((l >> i) << i) != l) {
                    self.push(l >> i);
                }
                if (((r >> i) << i) != r) {
                    self.push((r - 1) >> i);
                }
            }

            {
                const l2 = l;
                const r2 = r;
                while (l < r) : ({
                    l >>= 1;
                    r >>= 1;
                }) {
                    if (l & 1 != 0) {
                        self.allApply(l, f);
                        l += 1;
                    }
                    if (r & 1 != 0) {
                        r -= 1;
                        self.allApply(r, f);
                    }
                }
                l = l2;
                r = r2;
            }

            i = 1;
            while (i <= self.log) : (i += 1) {
                if (((l >> i) << i) != l) {
                    self.update(l >> i);
                }
                if (((r >> i) << i) != r) {
                    self.update((r - 1) >> i);
                }
            }
        }
        pub fn maxRight(self: *Self, left: usize, context: anytype, comptime g: fn (@TypeOf(context), S) bool) usize {
            assert(left <= self.n);
            assert(g(context, e()));

            if (left == self.n) {
                return self.n;
            }
            var l = left + self.size;
            var i: u6 = @intCast(self.log);
            while (i >= 1) : (i -= 1) {
                self.push(l >> i);
            }
            var sm = e();
            while (true) {
                while (l % 2 == 0) {
                    l >>= 1;
                }
                if (!g(context, op(sm, self.d[l]))) {
                    while (l < self.size) {
                        self.push(l);
                        l *= 2;
                        const res = op(sm, self.d[l]);
                        if (g(context, res)) {
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
        pub fn minLeft(self: *Self, right: usize, context: anytype, comptime g: fn (@TypeOf(context), S) bool) usize {
            assert(right <= self.n);
            assert(g(context, e()));

            if (right == 0) {
                return 0;
            }
            var r = right + self.size;
            var i: u6 = @intCast(self.log);
            while (i >= 1) : (i -= 1) {
                self.push((r - 1) >> i);
            }
            var sm = e();
            while (true) {
                r -= 1;
                while (r > 1 and r % 2 != 0) {
                    r >>= 1;
                }
                if (!g(context, op(self.d[r], sm))) {
                    while (r < self.size) {
                        self.push(r);
                        r = 2 * r + 1;
                        const res = op(self.d[r], sm);
                        if (g(context, res)) {
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

pub fn LazySegtreeFromNS(comptime ns: anytype) type {
    return LazySegtree(
        ns.S,
        ns.op,
        ns.e,
        ns.F,
        ns.mapping,
        ns.composition,
        ns.id,
    );
}

test "LazySegtree works" {
    const allocator = std.testing.allocator;
    var base = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6, 5, 3 };
    var segtree = try LazySegtreeFromNS(tests.max_add).initFromSlice(allocator, &base);
    defer segtree.deinit();

    try tests.checkSegtree(&base, &segtree);

    segtree.set(6, 5);
    base[6] = 5;
    try tests.checkSegtree(&base, &segtree);

    segtree.apply(5, 1);
    base[5] += 1;
    try tests.checkSegtree(&base, &segtree);

    segtree.set(6, 0);
    base[6] = 0;
    try tests.checkSegtree(&base, &segtree);

    segtree.applyRange(3, 8, 2);
    for (3..8) |i| {
        base[i] += 2;
    }
    try tests.checkSegtree(&base, &segtree);

    segtree.applyRange(2, 6, 7);
    for (2..6) |i| {
        base[i] += 7;
    }
    try tests.checkSegtree(&base, &segtree);
}

test "LazySegtree: ALPC-L sample" {
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
    var seg = try LazySegtreeFromNS(tests.inversion).init(allocator, n);
    defer seg.deinit();

    for (0..n) |i| {
        if (a[i] == 0) {
            seg.set(i, tests.inversion.S{ .zero = 1, .one = 0, .inversion = 0 });
        } else {
            seg.set(i, tests.inversion.S{ .zero = 0, .one = 1, .inversion = 0 });
        }
    }

    for (query) |q| {
        var result: ?i64 = null;
        if (q.t == 1) {
            seg.applyRange(q.l - 1, q.r, true);
        } else {
            result = seg.prod(q.l - 1, q.r).inversion;
        }
        try std.testing.expectEqual(q.expect, result);
    }
}

const tests = struct {
    const max_add = struct {
        const S = i32;
        const F = i32;
        fn op(x: S, y: S) S {
            return @max(x, y);
        }
        fn e() S {
            return math.minInt(S);
        }
        fn mapping(f: F, x: S) S {
            return f + x;
        }
        fn composition(f: F, g: F) F {
            return f + g;
        }
        fn id() F {
            return 0;
        }
    };
    const inversion = struct {
        const S = struct {
            zero: i64,
            one: i64,
            inversion: i64,
        };
        const F = bool;
        fn op(l: S, r: S) S {
            return S{
                .zero = l.zero + r.zero,
                .one = l.one + r.one,
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
    fn checkSegtree(base: []const i32, segtree: *LazySegtreeFromNS(max_add)) !void {
        const n = base.len;
        for (0..n) |i| {
            try std.testing.expectEqual(base[i], segtree.get(i));
        }
        for (0..n + 1) |i| {
            try std.testing.expect(check(base, segtree, 0, i));
            try std.testing.expect(check(base, segtree, i, n));
            for (i..n + 1) |j| {
                try std.testing.expect(check(base, segtree, i, j));
            }
        }
        try std.testing.expectEqual(expected: {
            var acc = max_add.e();
            for (0..n) |i| {
                acc = @max(acc, base[i]);
            }
            break :expected acc;
        }, segtree.allProd());

        const f = struct {
            pub fn f(k: max_add.S, x: max_add.S) bool {
                return x < k;
            }
        }.f;
        for (0..10) |k| {
            const target: max_add.S = @intCast(k);
            for (0..n + 1) |l| {
                try std.testing.expectEqual(
                    expected: {
                        var acc = max_add.e();
                        for (l..n) |pos| {
                            acc = max_add.op(acc, base[pos]);
                            if (!f(target, acc)) {
                                break :expected pos;
                            }
                        }
                        break :expected n;
                    },
                    segtree.maxRight(l, target, f),
                );
            }
            for (0..n + 1) |r| {
                try std.testing.expectEqual(
                    expected: {
                        var acc = max_add.e();
                        for (0..r) |pos| {
                            acc = max_add.op(acc, base[r - pos - 1]);
                            if (!f(target, acc)) {
                                break :expected r - pos;
                            }
                        }
                        break :expected 0;
                    },
                    segtree.minLeft(r, target, f),
                );
            }
        }
    }
    fn check(base: []const i32, segtree: *LazySegtreeFromNS(max_add), l: usize, r: usize) bool {
        var expected: i32 = max_add.e();
        for (l..r) |i| {
            expected = max_add.op(expected, base[i]);
        }
        return expected == segtree.prod(l, r);
    }
};
