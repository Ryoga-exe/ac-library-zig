//! A data structure for grouping elements based on given indices.
//!
//! `Groups` efficiently organizes elements into separate groups and provides
//! a way to retrieve members of a specific group. It is useful for partitioning
//! elements, such as dividing a graph into connected components.
//!
//! The caller is responsible for deallocating memory by calling `deinit`.
//!
//! # Example
//!
//! ```zig
//! var groups = try Groups.init(allocator, num_groups, group_index);
//! defer groups.deinit();
//!
//! const members = groups.get(group_id);
//! ```
//!
//! # Complexity
//!
//! - Initialization: $O(n)$
//! - Retrieval: $O(1)$

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Groups = @This();

len: usize,
data: []usize,
group_size: []usize,
offset: []usize,
allocator: Allocator,

/// Create a Group instance which will use a specified allocator.
/// Deinitialize with `deinit`.
///
/// - `group_num`: The number of groups.
/// - `group_index`: An array indicating the group assignment for each element.
///
/// # Errors
///
/// Returns an error if memory allocation fails.
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

/// Release all allocated memory.
pub fn deinit(self: *Groups) void {
    self.allocator.free(self.data);
    self.allocator.free(self.group_size);
    self.allocator.free(self.offset);
}

/// Retrieves the elements belonging to group `a`.
///
/// - `a`: Group index to query.
///
/// # Panics
///
/// Panics if `a` is out of bounds.
pub fn get(self: *Groups, a: usize) []usize {
    assert(a < self.len);
    const offset = self.offset[a];
    return self.data[offset .. offset + self.group_size[a]];
}
