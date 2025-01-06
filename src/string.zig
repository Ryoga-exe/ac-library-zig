const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

fn saNaive(s: []i32) void {
    _ = s; // autofix
}

fn saDoubling(s: []i32) void {
    _ = s; // autofix
}

fn saIs() void {}

// Reference:
// T. Kasai, G. Lee, H. Arimura, S. Arikawa, and K. Park,
// Linear-Time Longest-Common-Prefix Computation in Suffix Arrays and Its
// Applications
pub fn lcpArrayArbitrary(comptime T: type, allocator: Allocator, s: []const T, sa: []const usize) Allocator.Error![]usize {
    const n = s.len;
    assert(n >= 1);
    const rnk = try allocator.alloc(usize, n);
    defer allocator.free(rnk);
    for (0..n) |i| {
        rnk[sa[i]] = i;
    }
    var lcp = try allocator.alloc(usize, n - 1);
    errdefer allocator.free(lcp);
    var h: usize = 0;
    for (0..n - 1) |i| {
        h -|= 1;
        if (rnk[i] == 0) {
            continue;
        }
        const j = sa[rnk[i] - 1];
        while (j + h < n and i + h < n) {
            if (s[j + h] != s[i + h]) {
                break;
            }
            h += 1;
        }
        lcp[rnk[i] - 1] = h;
    }
    return lcp;
}

pub fn lcpArray(allocator: Allocator, s: []const u8, sa: []const usize) !Allocator.Error![]usize {
    return try lcpArrayArbitrary(u8, allocator, s, sa);
}

test lcpArray {
    const allocator = std.testing.allocator;
    _ = allocator; // autofix

    const tests = [_]struct { str: []const u8, expected: []const usize }{
        .{
            .str = "abracadabra",
            .expected = &[_]usize{ 1, 4, 1, 1, 0, 3, 0, 0, 0, 2 },
        },
        .{
            .str = "mmiissiissiippii", // an example taken from https://mametter.hatenablog.com/entry/20180130/p1
            .expected = &[_]usize{ 1, 2, 2, 6, 1, 1, 5, 0, 1, 0, 1, 0, 3, 1, 4 },
        },
    };

    for (tests) |t| {
        _ = t; // autofix
        // const lcp = try lcpArray(allocator, t.str);
        // defer allocator.free(lcp);
        // try std.testing.expectEqualSlices(usize, t.expected, lcp);
    }
}

// Reference:
// D. Gusfield,
// Algorithms on Strings, Trees, and Sequences: Computer Science and
// Computational Biology
pub fn zAlgorithmArbitrary(comptime T: type, allocator: Allocator, s: []const T) Allocator.Error![]usize {
    const n = s.len;
    var z = try allocator.alloc(usize, n);
    errdefer allocator.free(z);
    if (n == 0) {
        return z;
    }
    z[0] = 0;
    var j: usize = 0;
    for (1..n) |i| {
        var k = if (j + z[j] <= i) 0 else @min(j + z[j] - i, z[i - j]);
        while (i + k < n and s[k] == s[i + k]) {
            k += 1;
        }
        z[i] = k;
        if (j + z[j] < i + z[i]) {
            j = i;
        }
    }
    z[0] = n;
    return z;
}

pub fn zAlgorithm(allocator: Allocator, s: []const u8) Allocator.Error![]usize {
    return try zAlgorithmArbitrary(u8, allocator, s);
}

test zAlgorithm {
    const allocator = std.testing.allocator;

    const tests = [_]struct { str: []const u8, expected: []const usize }{
        .{
            .str = "abracadabra",
            .expected = &[_]usize{ 11, 0, 0, 1, 0, 1, 0, 4, 0, 0, 1 },
        },
        .{
            .str = "ababababa",
            .expected = &[_]usize{ 9, 0, 7, 0, 5, 0, 3, 0, 1 },
        },
    };

    for (tests) |t| {
        const z = try zAlgorithm(allocator, t.str);
        defer allocator.free(z);
        try std.testing.expectEqualSlices(usize, t.expected, z);
    }
}
