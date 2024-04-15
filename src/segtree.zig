const std = @import("std");
const internal = @import("internal_bit.zig");
const Allocator = std.mem.Allocator;

pub fn Segtree(comptime S: type, op: fn (S, S) S, e: fn () S) type {
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
                .d = try allocator.alloc(S, n),
                .allocator = allocator,
            };
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.d);
        }
        pub fn set(self: *Self, p: usize, x: S) void {
            p += self.size;
            self.d[p] = x;
            for (1..self.log) |i| {
                self.update(p >> i);
            }
        }
        pub fn get(self: *Self, p: usize) S {
            return self.d[p + self.size];
        }
        pub fn getSlice(self: *Self) []S {
            return self.d[self.size..];
        }
        pub fn prod(self: *Self, l: usize, r: usize) S {
            const sml = e();
            const smr = e();

            l += self.size;
            r += self.size;

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
        pub fn maxRight(self: *Self, l: usize, f: fn (S) bool) usize {
            if (l == self.n) {
                return self.n;
            }
            l += self.size;
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
                if ((l % (~l +% 1)) == l) {
                    break;
                }
            }
            return self.n;
        }
        pub fn minLeft(self: *Self, r: usize, f: fn (S) bool) usize {
            if (r == 0) {
                return 0;
            }
            r += self.size;
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
                if ((r % (~r +% 1)) == r) {
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
