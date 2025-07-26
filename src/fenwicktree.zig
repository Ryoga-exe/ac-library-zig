const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// Fenwick Tree (Binary‑Indexed Tree)
/// Reference: https://en.wikipedia.org/wiki/Fenwick_tree
///
/// This is a wrapper around a tree of element type T, identity e, and update operation op.
/// Initialize with `init`.
pub fn FenwickTree(comptime T: type, comptime e: T, comptime op: fn (T, T) T) type {
    return struct {
        const Self = @This();
        /// logical length of the array
        n: usize,
        /// internal 1‑based tree representation
        data: []T,
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
            const self = Self{
                .n = n,
                .data = try allocator.alloc(T, n),
                .allocator = allocator,
            };
            @memset(self.data, e);
            return self;
        }

        /// Release all allocated memory.
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
        }

        /// Processes `a[p] += x` (`a[p] = op(a[p], x)`).
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
        pub fn add(self: *Self, idx: usize, val: T) void {
            assert(idx < self.n);
            var p = idx + 1;
            while (p <= self.n) {
                self.data[p - 1] = op(self.data[p - 1], val);
                p += p & (~p +% 1);
            }
        }

        /// Returns `a[l] + a[l + 1] + ... + a[r - 1]` (`op(a[l], op(a[l + 1], op(..., a[r - 1])))`).
        ///
        /// # Constraints
        ///
        /// - $0 \leq l \leq r \leq n$
        ///
        /// # Panics
        ///
        /// Panics if the above constraints are not satisfied.
        ///
        /// # Complexity
        ///
        /// - $O(\log n)$
        pub fn sum(self: *Self, l: usize, r: usize) T {
            assert(l <= r and r <= self.n);
            return self.accum(r) - self.accum(l);
        }

        /// Internal helper, prefix sum of `[0, idx)`.
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

/// Convenient helper for i64 FenwickTree.
pub const FenwickTreeI64 = FenwickTree(i64, 0, operation(i64).addition);

/// Convenient helper for i32 FenwickTree.
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
