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

    pub fn zero() Threshold {
        return Threshold{
            .native = 0,
            .doubling = 0,
        };
    }
};

// SA-IS, linear-time suffix array construction
// Reference:
// G. Nong, S. Zhang, and W. H. Chan,
// Two Efficient Algorithms for Linear Time Suffix Array Construction
fn saIs(comptime threshold: Threshold, allocator: Allocator, s: []const usize, upper: usize) Allocator.Error![]usize {
    const n = s.len;
    switch (n) {
        0 => return allocator.alloc(usize, 0),
        1 => {
            var result = try allocator.alloc(usize, 1);
            result[0] = 0;
            return result;
        },
        2 => return allocator.dupe(usize, if (s[0] < s[1]) &.{ 0, 1 } else &.{ 1, 0 }),
        else => {},
    }
    if (n < threshold.native) {
        return saNaive(allocator, s);
    }
    if (n < threshold.doubling) {
        return saDoubling(allocator, s);
    }
    const sa = try allocator.alloc(usize, n);
    errdefer allocator.free(sa);
    var ls = try allocator.alloc(bool, n);
    defer allocator.free(ls);
    @memset(sa, 0);
    @memset(ls, false);
    for (0..n - 1) |rev| {
        const i = n - 2 - rev;
        ls[i] = if (s[i] == s[i + 1]) ls[i + 1] else s[i] < s[i + 1];
    }
    var sum_l = try allocator.alloc(usize, upper + 1);
    defer allocator.free(sum_l);
    var sum_s = try allocator.alloc(usize, upper + 1);
    defer allocator.free(sum_s);
    @memset(sum_l, 0);
    @memset(sum_s, 0);
    for (0..n) |i| {
        if (!ls[i]) {
            sum_s[s[i]] += 1;
        } else {
            sum_l[s[i] + 1] += 1;
        }
    }
    for (0..upper + 1) |i| {
        sum_s[i] += sum_l[i];
        if (i < upper) {
            sum_l[i + 1] += sum_s[i];
        }
    }

    // sa's origin is 1.
    const induce = struct {
        pub const Closure = struct {
            allocator: Allocator,
            n: usize,
            s: []const usize,
            ls: []bool,
            sum_s: []const usize,
            sum_l: []const usize,
        };
        pub fn f(closure: Closure, sav: []usize, lms: []const usize) Allocator.Error!void {
            @memset(sav, 0);
            var buf = try closure.allocator.dupe(usize, closure.sum_s);
            defer closure.allocator.free(buf);
            for (lms) |d| {
                if (d == closure.n) {
                    continue;
                }
                sav[buf[closure.s[d]]] = d + 1;
                buf[closure.s[d]] += 1;
            }
            @memcpy(buf, closure.sum_l);
            sav[buf[closure.s[closure.n - 1]]] = closure.n;
            buf[closure.s[closure.n - 1]] += 1;
            for (0..closure.n) |i| {
                const v = sav[i];
                if (v >= 2 and !closure.ls[v - 2]) {
                    sav[buf[closure.s[v - 2]]] = v - 1;
                    buf[closure.s[v - 2]] += 1;
                }
            }
            @memcpy(buf, closure.sum_l);
            for (0..closure.n) |rev| {
                const i = closure.n - 1 - rev;
                const v = sav[i];
                if (v >= 2 and closure.ls[v - 2]) {
                    buf[closure.s[v - 2] + 1] -= 1;
                    sav[buf[closure.s[v - 2] + 1]] = v - 1;
                }
            }
        }
    };
    const closure = induce.Closure{
        .allocator = allocator,
        .n = n,
        .s = s,
        .ls = ls,
        .sum_s = sum_s,
        .sum_l = sum_l,
    };

    // origin: 1
    var lms_map = try allocator.alloc(usize, n + 1);
    defer allocator.free(lms_map);
    @memset(lms_map, 0);
    var m: usize = 0;
    for (1..n) |i| {
        if (!ls[i - 1] and ls[i]) {
            lms_map[i] = m + 1;
            m += 1;
        }
    }
    var lms = try std.ArrayList(usize).initCapacity(allocator, m);
    defer lms.deinit();
    for (1..n) |i| {
        if (!ls[i - 1] and ls[i]) {
            lms.appendAssumeCapacity(i);
        }
    }
    assert(lms.items.len == m);
    try induce.f(closure, sa, lms.items);

    if (m > 0) {
        var sorted_lms = try std.ArrayList(usize).initCapacity(allocator, m);
        defer sorted_lms.deinit();
        for (sa) |v| {
            if (lms_map[v - 1] != 0) {
                sorted_lms.appendAssumeCapacity(v - 1);
            }
        }
        var rec_s = try allocator.alloc(usize, m);
        defer allocator.free(rec_s);
        @memset(rec_s, 0);
        var rec_upper: usize = 0;
        rec_s[lms_map[sorted_lms.items[0] - 1]] = 0;
        for (1..m) |i| {
            var l = sorted_lms.items[i - 1];
            var r = sorted_lms.items[i];
            const end_l = if (lms_map[l] < m) lms.items[lms_map[l]] else n;
            const end_r = if (lms_map[r] < m) lms.items[lms_map[r]] else n;
            const same = same: {
                if (end_l - l != end_r - r) {
                    break :same false;
                } else {
                    while (l < end_l) {
                        if (s[l] != s[r]) {
                            break;
                        }
                        l += 1;
                        r += 1;
                    }
                }
                break :same l != n and s[l] == s[r];
            };
            if (!same) {
                rec_upper += 1;
            }
            rec_s[lms_map[sorted_lms.items[i]] - 1] = rec_upper;
        }
        const rec_sa = try saIs(threshold, allocator, rec_s, rec_upper);
        defer allocator.free(rec_sa);

        for (0..m) |i| {
            sorted_lms.items[i] = lms.items[rec_sa[i]];
        }

        try induce.f(closure, sa, sorted_lms.items);
    }
    for (sa) |*elem| {
        elem.* -= 1;
    }
    return sa;
}

// TODO: rewrite with meta programming technics
fn saIsI32(comptime threshold: Threshold, allocator: Allocator, s_i32: []const i32, upper: i32) Allocator.Error![]usize {
    const n = s_i32.len;
    const s = try allocator.alloc(usize, n);
    defer allocator.free(s);
    for (0..n) |i| {
        s[i] = @intCast(s_i32[i]);
    }
    return try saIs(threshold, allocator, s, @intCast(upper));
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

        const sa_is = try saIsI32(Threshold.zero(), allocator, array, 255);
        defer allocator.free(sa_is);
        try std.testing.expectEqualSlices(usize, t.expected, sa_is);

        // TODO: test suffixArray
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
