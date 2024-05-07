const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Groups = @This();

len: usize,
data: []usize,
group_size: []usize,
offset: []usize,
allocator: Allocator,

pub fn init(allocator: Allocator, group_num: usize, group_index: []const ?usize) !Groups {
    var self = Groups{
        .len = group_num,
        .data = try allocator.alloc(usize, group_index.len),
        .group_size = try allocator.alloc(usize, group_num),
        .offset = try allocator.alloc(usize, group_num),
        .allocator = allocator,
    };
    @memset(self.group_size, 0);
    for (group_index) |index| {
        self.group_size[index.?] += 1;
    }
    self.offset[0] = 0;
    for (1..group_num) |i| {
        self.offset[i] = self.offset[i - 1] + self.group_size[i - 1];
    }
    var index = try allocator.alloc(usize, group_num);
    defer allocator.free(index);
    @memset(index, 0);
    for (0..group_index.len) |i| {
        const group = group_index[i].?;
        const offset = self.offset[group];
        self.data[offset + index[group]] = i;
        index[group] += 1;
    }
    return self;
}

pub fn deinit(self: *Groups) void {
    self.allocator.free(self.data);
    self.allocator.free(self.group_size);
    self.allocator.free(self.offset);
}

pub fn get(self: *Groups, a: usize) []usize {
    assert(a < self.len);
    const offset = self.offset[a];
    return self.data[offset .. offset + self.group_size[a]];
}
