const std = @import("std");
const Allocator = std.mem.Allocator;

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
        return self.leader(a) == self.leader(b);
    }
    pub fn leader(self: *Self, a: usize) usize {
        if (self.parent_or_size[a] < 0) {
            return a;
        }
        self.parent_or_size[a] = @intCast(self.leader(@intCast(self.parent_or_size[a])));
        return @intCast(self.parent_or_size[a]);
    }
    pub fn size(self: *Self, a: usize) usize {
        const x = self.leader(a);
        return @intCast(-self.parent_or_size[x]);
    }
    // pub fn groups(self: *Self) type {
    //     _ = self;
    // }
};

test "Dsu works" {
    const allocator = std.testing.allocator;
    var d = try Dsu.init(allocator, 4);
    defer d.deinit();
    _ = d.merge(0, 1);
    try std.testing.expect(d.same(0, 1));
    _ = d.merge(1, 2);
    try std.testing.expect(d.same(0, 2));
    try std.testing.expect(d.size(0) == 3);
    try std.testing.expect(!d.same(0, 3));
    // std.testing.expectEqualSlices(...):
}
