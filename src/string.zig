const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

fn saNaive(allocator: Allocator, s: []const i32) Allocator.Error![]usize {
    const n = s.len;
    var sa = try allocator.alloc(usize, n);
    errdefer allocator.free(sa);
    for (0..n) |i| {
        sa[i] = i;
    }
    const cmp = struct {
        var closure: struct {
            n: usize,
            s: []const i32,
        } = undefined;
        fn f(_: void, lhs: usize, rhs: usize) bool {
            var l = lhs;
            var r = rhs;
            if (l == r) {
                return false;
            }
            while (l < closure.n and r < closure.n) {
                if (closure.s[l] != closure.s[r]) {
                    return closure.s[l] < closure.s[r];
                }
                l += 1;
                r += 1;
            }
            return l == closure.n;
        }
    };
    cmp.closure = .{
        .n = n,
        .s = s,
    };
    std.mem.sort(usize, sa, {}, cmp.f);
    return sa;
}

fn saDoubling(allocator: Allocator, s: []const i32) Allocator.Error![]usize {
    const n = s.len;
    var sa = try allocator.alloc(usize, n);
    errdefer allocator.free(sa);
    for (0..n) |i| {
        sa[i] = i;
    }
    const rnk = try allocator.dupe(i32, s);
    defer allocator.free(rnk);
    const tmp = try allocator.alloc(i32, n);
    defer allocator.free(tmp);
    @memset(tmp, 0);
    var k: usize = 1;
    while (k < n) : (k *= 2) {
        const cmp = struct {
            var closure: struct {
                n: usize,
                k: usize,
                rnk: []i32,
            } = undefined;
            fn f(_: void, x: usize, y: usize) bool {
                if (closure.rnk[x] != closure.rnk[y]) {
                    return closure.rnk[x] < closure.rnk[y];
                }
                const rx = if (x + closure.k < closure.n) closure.rnk[x + closure.k] else -1;
                const ry = if (y + closure.k < closure.n) closure.rnk[y + closure.k] else -1;
                return rx < ry;
            }
        };
        cmp.closure = .{
            .n = n,
            .k = k,
            .rnk = rnk,
        };
        std.mem.sort(usize, sa, {}, cmp.f);
        tmp[sa[0]] = 0;
        for (1..n) |i| {
            tmp[sa[i]] = tmp[sa[i - 1]] + (@intFromBool(cmp.f({}, sa[i - 1], sa[i])));
        }
        @memcpy(rnk, tmp);
    }
    return sa;
}

const Threshold = struct {
    native: usize,
    doubling: usize,

    pub fn default() Threshold {
        return Threshold{
            .native = 10,
            .doubling = 40,
        };
    }
};

fn saIs(comptime threshold: Threshold, allocator: Allocator, s: []const usize, upper: usize) Allocator.Error![]usize {
    _ = upper; // autofix
    const n = s.len;
    switch (n) {
        0 => return try allocator.alloc(usize, 0),
        1 => {
            var result = try allocator.alloc(usize, 1);
            result[0] = 0;
            return result;
        },
        2 => {
            var result = try allocator.alloc(usize, 1);
            if (s[0] < s[1]) {
                result[0] = 0;
                result[1] = 1;
            } else {
                result[0] = 1;
                result[1] = 0;
            }
            return result;
        },
        else => {},
    }
    if (n < threshold.native) {
        return try saNaive(allocator, s);
    }
    if (n < threshold.doubling) {
        return try saDoubling(allocator, s);
    }
    const sa = try allocator.alloc(usize, n);
    const ls = try allocator.alloc(bool, n);
    @memset(sa, 0);
    @memset(ls, false);
    // TODO: impl
    return sa;
}

test saNaive {
    const allocator = std.testing.allocator;
    const array = [_]i32{ 0, 1, 2, 3, 4 };
    const sa = try saNaive(allocator, &array);
    defer allocator.free(sa);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 0, 1, 2, 3, 4 }, sa);
}

test saDoubling {
    const allocator = std.testing.allocator;
    const array = [_]i32{ 0, 1, 2, 3, 4 };
    const sa = try saDoubling(allocator, &array);
    defer allocator.free(sa);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 0, 1, 2, 3, 4 }, sa);
}

test "verify all" {
    const allocator = std.testing.allocator;

    const tests = [_]struct { str: []const u8, expected: []const usize }{
        .{
            .str = "abracadabra",
            .expected = &[_]usize{ 10, 7, 0, 3, 5, 8, 1, 4, 6, 9, 2 },
        },
        .{
            .str = "mmiissiissiippii", // an example taken from https://mametter.hatenablog.com/entry/20180130/p1
            .expected = &[_]usize{ 15, 14, 10, 6, 2, 11, 7, 3, 1, 0, 13, 12, 9, 5, 8, 4 },
        },
    };

    for (tests) |t| {
        const n = t.str.len;
        var array = try allocator.alloc(i32, n);
        defer allocator.free(array);
        for (0..n) |i| {
            array[i] = @intCast(t.str[i]);
        }

        const sa = try saDoubling(allocator, array);
        defer allocator.free(sa);
        try std.testing.expectEqualSlices(usize, t.expected, sa);

        const sa_native = try saNaive(allocator, array);
        defer allocator.free(sa_native);
        try std.testing.expectEqualSlices(usize, t.expected, sa_native);

        // TODO: test saIs and suffixArray
    }
}

pub fn suffixArrayManual(s: []const i32, upper: i32) Allocator.Error![]usize {
    assert(upper >= 0);
    for (s) |elem| {
        assert(0 <= elem and elem <= upper);
    }
    // TODO: saIsI32
}

pub fn suffixArrayArbitrary(comptime T: type, allocator: Allocator, s: []const T) Allocator.Error![]usize {
    const n = s.len;
    var idx = try allocator.alloc(usize, n);
    defer allocator.free(idx);
    for (0..n) |i| {
        idx[i] = i;
    }
    std.mem.sort(usize, &idx, {}, struct {
        fn cmp(l: usize, r: usize) bool {
            s[l] < s[r];
        }
    }.cmp);
    var s2 = try allocator.alloc(usize, n);
    defer allocator.free(s2);
    var now = 0;
    for (0..n) |i| {
        if (i > 0 and s[idx[i - 1]] != s[idx[i]]) {
            now += 1;
        }
        s2[idx[i]] = now;
    }
    // TODO: saIsI32
}

pub fn suffixArray(allocator: Allocator, s: []const u8) Allocator.Error![]usize {
    _ = allocator; // autofix
    _ = s; // autofix
    // TODO: impl
}

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
    @memset(lcp, 0);
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
        // TODO: test lcpArray
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
