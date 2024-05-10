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
                self.push(p >> i);
            }
            self.d[p] = x;
            for (1..self.log + 1) |k| {
                self.update(p >> k);
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
            const l = left + self.size;
            const r = right + self.size;

            var i: usize = self.log;
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
            var i: usize = self.log;
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

            var i: usize = self.log;
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
                if (((l >> i) << i) != l) {
                    self.update(l >> i);
                }
                if (((r >> i) << i) != r) {
                    self.update((r - 1) >> i);
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
