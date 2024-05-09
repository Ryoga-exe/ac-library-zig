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
        pub fn getSlice(self: *Self) []S {
            return self.d[self.size .. self.size + self.n];
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
