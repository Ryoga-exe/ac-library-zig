const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// Segment Tree
/// Reference: https://en.wikipedia.org/wiki/Segment_tree
///
/// This is a wrapper around a tree of element type T, update operation op, and identity e.
/// The following should be defined.
///
/// - The type `S` of the monoid
/// - The binary operation `op: fn (S, S) S`
/// - The identity element `e: fn () S`
///
/// Initialize with `init`.
pub fn Segtree(comptime S: type, comptime op: fn (S, S) S, comptime e: fn () S) type {
    return struct {
        const Self = @This();

        /// original array length
        n: usize,
        /// internal tree size (power of two ≥ n)
        size: usize,
        /// tree height used by `set`
        log: usize,
        /// backing array: [size...2*size)
        d: []S,
        allocator: Allocator,

        /// Creates an empty tree of length `n`, initialised with the identity.
        /// Deinitialize with `deinit`.
        ///
        /// # Constraints
        ///
        /// - $0 \leq n < 10^8$
        ///
        /// # Complexity
        ///
        /// - $O(n)$
        pub fn init(allocator: Allocator, n: usize) !Self {
            const size = try math.ceilPowerOfTwo(usize, n);
            const log = @ctz(size);
            const self = Self{
                .n = n,
                .size = size,
                .log = log,
                .d = try allocator.alloc(S, 2 * size),
                .allocator = allocator,
            };
            @memset(self.d, e());
            return self;
        }

        /// Build a tree from an existing slice.
        /// Deinitialize with `deinit`.
        ///
        /// # Constraints
        ///
        /// - $0 \leq `v.len` < 10^8$
        ///
        /// # Complexity
        ///
        /// - $O(n)$ (where $n$ is the length of `v`)
        pub fn initFromSlice(allocator: Allocator, v: []const S) !Self {
            const n = v.len;
            const size = try math.ceilPowerOfTwo(usize, n);
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

        /// Release all allocated memory.
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.d);
        }

        /// Assigns `x` to `a[pos]`
        ///
        /// # Constraints
        ///
        /// - $0 \leq p < n$
        ///
        /// # Panics
        ///
        /// Panics if the above constraints are not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O(\log n)$
        pub fn set(self: *Self, pos: usize, x: S) void {
            assert(pos < self.n);
            const p = pos + self.size;
            self.d[p] = x;
            for (1..self.log + 1) |i| {
                self.update(p >> @intCast(i));
            }
        }

        /// Returns `a[p]`
        ///
        /// # Constraints
        ///
        /// - $0 \leq p < n$
        ///
        /// # Panics
        ///
        /// Panics if the above constraints are not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O(1)$
        pub fn get(self: *Self, p: usize) S {
            assert(p < self.n);
            return self.d[p + self.size];
        }

        /// Returns the underlying leaf slice `[0, n)`.
        ///
        /// # Complexity
        ///
        /// - $O(1)$
        pub fn getSlice(self: *Self) []S {
            return self.d[self.size .. self.size + self.n];
        }

        /// Returns op(a[l], ..., a[r - 1]), assuming the properties of the monoid.
        /// Returns e() if l = r.
        ///
        /// # Constraints
        ///
        /// - $0 \leq l \leq r < n$
        ///
        /// # Panics
        ///
        /// Panics if the above constraints are not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O(\log n)$
        pub fn prod(self: *Self, left: usize, right: usize) S {
            assert(left <= right and right <= self.n);

            var sml = e();
            var smr = e();

            var l = left + self.size;
            var r = right + self.size;

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

        /// Returns op(a[0], ..., a[n - 1]), assuming the properties of the monoid.
        /// Returns e() if n = 0.
        ///
        /// # Complexity
        ///
        /// - $O(1)$
        pub fn allProd(self: *Self) S {
            return self.d[1];
        }

        /// Applies binary search on the segment tree.
        /// Returns an index `r` that satisfies both of the following.
        ///
        /// - `r = l` or `f(context, op(a[l], a[l + 1], ..., a[r - 1])) = true`
        /// - `r = n` or `f(context, op(a[l], a[l + 1], ..., a[r])) = false`
        ///
        /// If `f` is monotone, this is the maximum `r` that satisfies `f(context, op(a[l], a[l + 1], ..., a[r - 1])) = true`.
        ///
        /// # Constraints
        ///
        /// - if `f` is called with the same argument, it returns the same value, i.e., `f` has no side effect.
        /// - `f(context, e()) = true`
        /// - $0 \leq l \leq n$
        ///
        /// # Panics
        ///
        /// Panics if the above constraints are not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O(\log n)$
        pub fn maxRight(self: *Self, left: usize, context: anytype, comptime f: fn (@TypeOf(context), S) bool) usize {
            assert(left <= self.n);
            assert(f(context, e()));

            if (left == self.n) {
                return self.n;
            }
            var l = left + self.size;
            var sm = e();
            while (true) {
                while (l % 2 == 0) {
                    l >>= 1;
                }
                if (!f(context, op(sm, self.d[l]))) {
                    while (l < self.size) {
                        l *= 2;
                        const res = op(sm, self.d[l]);
                        if (f(context, res)) {
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

        /// Applies binary search on the segment tree.
        /// Returns an index `l` that satisfies both of the following.
        ///
        /// - `l = r` or `f(context, op(a[l], a[l + 1], ..., a[r - 1])) = true`
        /// - `l = 0` or `f(context, op(a[l - 1], a[l], ..., a[r - 1])) = false`
        ///
        /// If `f` is monotone, this is the minimum `l` that satisfies `f(context, op(a[l], a[l + 1], ..., a[r - 1])) = true`.
        ///
        /// # Constraints
        ///
        /// - if `f` is called with the same argument, it returns the same value, i.e., `f` has no side effect.
        /// - `f(context, e()) = true`
        /// - $0 \leq r \leq n$
        ///
        /// # Panics
        ///
        /// Panics if the above constraints are not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O(\log n)$
        pub fn minLeft(self: *Self, right: usize, context: anytype, comptime f: fn (@TypeOf(context), S) bool) usize {
            assert(right <= self.n);
            assert(f(context, e()));

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
                if (!f(context, op(self.d[r], sm))) {
                    while (r < self.size) {
                        r = 2 * r + 1;
                        const res = op(self.d[r], sm);
                        if (f(context, res)) {
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

        /// Internal helper function:
        /// Recomputes node `k` from its two children.
        fn update(self: *Self, k: usize) void {
            self.d[k] = op(self.d[2 * k], self.d[2 * k + 1]);
        }
    };
}

/// Sugar helper that turns a *namespace* with fields `S`, `op`, and `e`.
///
/// Initialize with `init`.
pub fn SegtreeFromNS(comptime ns: anytype) type {
    return Segtree(
        ns.S,
        ns.op,
        ns.e,
    );
}

test "Segtree works" {
    const allocator = std.testing.allocator;
    var base = [_]i32{ 3, 1, 4, 1, 5, 9, 2, 6, 5, 3 };

    var segtree = try SegtreeFromNS(monoid.max(i32)).initFromSlice(allocator, &base);
    defer segtree.deinit();
    try tests.checkSegtree(&base, &segtree);

    segtree.set(6, 5);
    base[6] = 5;
    try tests.checkSegtree(&base, &segtree);

    segtree.set(6, 0);
    base[6] = 0;
    try tests.checkSegtree(&base, &segtree);
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
    var segtree = try SegtreeFromNS(monoid.max(usize)).initFromSlice(allocator, a);
    defer segtree.deinit();

    try std.testing.expectEqualSlices(usize, &[_]usize{ 1, 2, 3, 2, 1 }, segtree.getSlice());

    const f = struct {
        fn f(target: usize, v: usize) bool {
            return v < target;
        }
    }.f;

    for (query) |q| {
        var result: ?usize = null;
        if (q.t == 1) {
            segtree.set(q.x - 1, q.y);
        } else if (q.t == 2) {
            result = segtree.prod(q.x - 1, q.y);
        } else if (q.t == 3) {
            result = segtree.maxRight(q.x - 1, q.y, f) + 1;
        }
        try std.testing.expectEqual(q.expect, result);
    }
}

const monoid = struct {
    fn additive(comptime T: type) type {
        return struct {
            const S = T;
            fn op(x: S, y: S) S {
                return x + y;
            }
            fn e() S {
                return 0;
            }
        };
    }
    fn max(comptime T: type) type {
        return struct {
            const S = T;
            fn op(x: S, y: S) S {
                return @max(x, y);
            }
            fn e() S {
                return math.minInt(S);
            }
        };
    }
};

const tests = struct {
    fn checkSegtree(base: []const i32, segtree: anytype) !void {
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
            var acc = monoid.max(i32).e();
            for (0..n) |i| {
                acc = @max(acc, base[i]);
            }
            break :expected acc;
        }, segtree.allProd());
        const f = struct {
            fn f(target: i32, v: i32) bool {
                return v < target;
            }
        }.f;
        for (0..10) |k| {
            const target: i32 = @intCast(k);
            for (0..n + 1) |l| {
                try std.testing.expectEqual(expected: {
                    var acc = monoid.max(i32).e();
                    for (l..n) |pos| {
                        acc = monoid.max(i32).op(acc, base[pos]);
                        if (!f(target, acc)) {
                            break :expected pos;
                        }
                    }
                    break :expected n;
                }, segtree.maxRight(l, target, f));
            }
            for (0..n + 1) |r| {
                try std.testing.expectEqual(expected: {
                    var acc = monoid.max(i32).e();
                    for (0..r) |pos| {
                        acc = monoid.max(i32).op(acc, base[r - pos - 1]);
                        if (!f(target, acc)) {
                            break :expected r - pos;
                        }
                    }
                    break :expected 0;
                }, segtree.minLeft(r, target, f));
            }
        }
    }
    fn check(base: []const i32, segtree: anytype, l: usize, r: usize) bool {
        var expected: i32 = monoid.max(i32).e();
        for (l..r) |i| {
            expected = monoid.max(i32).op(expected, base[i]);
        }
        return expected == segtree.prod(l, r);
    }
};
