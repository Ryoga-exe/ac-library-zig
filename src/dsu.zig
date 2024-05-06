const std = @import("std");
const Groups = @import("internal_groups.zig").Groups;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const Dsu = struct {
    const Self = @This();

    n: usize,
    parent_or_size: []i32,
    allocator: Allocator,

    pub fn init(allocator: Allocator, n: usize) !Self {
        var self = Self{
            .n = n,
            .parent_or_size = try allocator.alloc(i32, n),
            .allocator = allocator,
        };
        @memset(self.parent_or_size, -1);
        return self;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.parent_or_size);
    }
    pub fn merge(self: *Self, a: usize, b: usize) usize {
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
    pub fn same(self: *Self, a: usize, b: usize) bool {
        assert(a < self.n);
        assert(b < self.n);
        return self.leader(a) == self.leader(b);
    }
    pub fn leader(self: *Self, a: usize) usize {
        assert(a < self.n);
        if (self.parent_or_size[a] < 0) {
            return a;
        }
        self.parent_or_size[a] = @intCast(self.leader(@intCast(self.parent_or_size[a])));
        return @intCast(self.parent_or_size[a]);
    }
    pub fn size(self: *Self, a: usize) usize {
        assert(a < self.n);
        const x = self.leader(a);
        return @intCast(-self.parent_or_size[x]);
    }
    pub fn groups(self: *Self) !Groups {
        var group_index = try self.allocator.alloc(?usize, self.n);
        defer self.allocator.free(group_index);
        @memset(group_index, null);
        var index: usize = 0;
        for (0..self.n) |i| {
            const leader_buf = self.leader(i);
            if (group_index[leader_buf] == null) {
                group_index[leader_buf] = index;
                group_index[i] = index;
                index += 1;
            } else {
                group_index[i] = group_index[leader_buf];
            }
        }
        return try Groups.init(self.allocator, index, group_index);
    }
};

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

    var groups = try d.groups();
    defer groups.deinit();
    try std.testing.expectEqual(@as(usize, 2), groups.len);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 0, 1, 2 }, groups.get(0));
    try std.testing.expectEqualSlices(usize, &[_]usize{3}, groups.get(1));
}
