//! A Disjoint set union (DSU) with union by size and path compression.
//!
//! See: [Zvi Galil and Giuseppe F. Italiano, Data structures and algorithms for disjoint set union problems](https://core.ac.uk/download/pdf/161439519.pdf)
//!
//! Initialize with `init`.
//! Is owned by the caller and should be freed with `deinit`.

const std = @import("std");
const Groups = @import("internal_groups.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Dsu = @This();

/// The size of the DSU
n: usize,
/// root node: -1 * component size
/// otherwise: parent
parent_or_size: []i32,
allocator: Allocator,

/// Create a DSU instance which will use a specified allocator.
/// Deinitialize with `deinit`.
pub fn init(allocator: Allocator, n: usize) !Dsu {
    const self = Dsu{
        .n = n,
        .parent_or_size = try allocator.alloc(i32, n),
        .allocator = allocator,
    };
    @memset(self.parent_or_size, -1);
    return self;
}

/// Release all allocated memory.
pub fn deinit(self: *Dsu) void {
    self.allocator.free(self.parent_or_size);
}

/// Performs the Uɴɪᴏɴ operation.
///
/// If $a, b$ are connected, it returns their leader;
/// if they are disconnected, it returns a new leader.
///
/// # Constraints
///
/// - $0 \leq a < n$
/// - $0 \leq b < n$
///
/// # Panics
///
/// Panics if the above constraint is not satisfied.
///
/// # Complexity
///
/// - $O(\alpha(n))$ amortized
pub fn merge(self: *Dsu, a: usize, b: usize) usize {
    assert(a < self.n);
    assert(b < self.n);
    var x = self.leader(a);
    var y = self.leader(b);
    if (x == y) {
        return x;
    }
    if (-self.parent_or_size[x] < -self.parent_or_size[y]) {
        std.mem.swap(usize, &x, &y);
    }
    self.parent_or_size[x] += self.parent_or_size[y];
    self.parent_or_size[y] = @intCast(x);
    return x;
}

/// Returns whether the vertices $a$ and $b$ are in the same connected component.
///
/// # Constraints
///
/// - $0 \leq a < n$
/// - $0 \leq b < n$
///
/// # Panics
///
/// Panics if the above constraint is not satisfied.
///
/// # Complexity
///
/// - $O(\alpha(n))$ amortized
pub fn same(self: *Dsu, a: usize, b: usize) bool {
    assert(a < self.n);
    assert(b < self.n);
    return self.leader(a) == self.leader(b);
}

/// Performs the Fɪɴᴅ operation.
///
/// # Constraints
///
/// - $0 \leq a < n$
///
/// # Panics
///
/// Panics if the above constraint is not satisfied.
///
/// # Complexity
///
/// - $O(\alpha(n))$ amortized
pub fn leader(self: *Dsu, a: usize) usize {
    assert(a < self.n);
    if (self.parent_or_size[a] < 0) {
        return a;
    }
    self.parent_or_size[a] = @intCast(self.leader(@intCast(self.parent_or_size[a])));
    return @intCast(self.parent_or_size[a]);
}

/// Returns the size of the connected component that contains the vertex $a$.
///
/// # Constraints
///
/// - $0 \leq a < n$
///
/// # Panics
///
/// Panics if the above constraint is not satisfied.
///
/// # Complexity
///
/// - $O(\alpha(n))$ amortized
pub fn size(self: *Dsu, a: usize) usize {
    assert(a < self.n);
    const x = self.leader(a);
    return @intCast(-self.parent_or_size[x]);
}

/// Divides the graph into connected components.
/// The result may not be ordered.
///
/// Is owned by the caller and should be freed with `Groups.deinit`.
///
/// # Complexity
///
/// - $O(n)$
pub fn groups(self: *Dsu) !Groups {
    var group_index = try self.allocator.alloc(?usize, self.n);
    defer self.allocator.free(group_index);
    @memset(group_index, null);
    var index: usize = 0;
    for (0..self.n) |i| {
        const leader_buf = self.leader(i);
        if (group_index[leader_buf]) |leader_index| {
            group_index[i] = leader_index;
        } else {
            group_index[leader_buf] = index;
            group_index[i] = index;
            index += 1;
        }
    }
    return try Groups.init(self.allocator, index, group_index);
}

test Dsu {
    const allocator = std.testing.allocator;
    var d = try Dsu.init(allocator, 4);
    defer d.deinit();
    _ = d.merge(0, 1);
    try std.testing.expect(d.same(0, 1));
    _ = d.merge(1, 2);
    try std.testing.expect(d.same(0, 2));
    try std.testing.expectEqual(@as(usize, 3), d.size(0));
    try std.testing.expect(!d.same(0, 3));

    var g = try d.groups();
    defer g.deinit();
    try std.testing.expectEqual(@as(usize, 2), g.len);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 0, 1, 2 }, g.get(0));
    try std.testing.expectEqualSlices(usize, &[_]usize{3}, g.get(1));
}
