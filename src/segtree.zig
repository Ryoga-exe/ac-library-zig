const std = @import("std");
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
            var self = Self{
                .n = n,
                .size = n, // TODO:
                .log = n, // TODO:
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
            // TODO: not implemented yet
            _ = self;
            _ = l;
            _ = f;
        }
        pub fn minLeft(self: *Self, r: usize, f: fn (S) bool) usize {
            // TODO: not implemented yet
            _ = self;
            _ = r;
            _ = f;
        }
        fn update(self: *Self, k: usize) void {
            self.d[k] = op(self.d[2 * k], self.d[2 * k + 1]);
        }
    };
}
