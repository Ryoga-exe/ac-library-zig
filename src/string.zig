const std = @import("std");
const Allocator = std.mem.Allocator;

fn saNaive(s: []i32) void {
    _ = s; // autofix
}

fn saDoubling(s: []i32) void {
    _ = s; // autofix
}

fn saIs() void {}

pub fn suffixArray() void {}

pub fn lcpArray() void {}

// Reference:
// D. Gusfield,
// Algorithms on Strings, Trees, and Sequences: Computer Science and
// Computational Biology
pub fn zAlgorithmArbitrary(comptime T: type, allocator: Allocator, s: []const T) Allocator.Error![]usize {
    const n = s.len;
    var z = try allocator.alloc(usize, n);
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
        const lcp = try zAlgorithm(allocator, t.str);
        defer allocator.free(lcp);
        try std.testing.expectEqualSlices(usize, t.expected, lcp);
    }
}
