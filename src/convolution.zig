const std = @import("std");
const Allocator = std.mem.Allocator;
const Modint = @import("modint.zig").StaticModint;
const assert = std.debug.assert;

const internal = @import("internal_math.zig");

/// Calculates the $(+, \times)$ convolution in $\mathbb{Z}/p\mathbb{Z}$.
/// Caller must free returned memory.
///
/// Returns a empty `T[]` if `a` or `b` is empty.
///
/// # Constraints
///
/// - $2 \leq m \leq 2 \times 10^9$
/// - `mod` is a prime number.
/// - $\exists c \text{ s.t. } 2^c \mid (m - 1), |a| + |b| - 1 \leq 2^c$
/// - $(0, m] \subseteq$ `T`
///
/// # Complexity
///
/// - $O(n \log n + \log m)$ where $n = |a| + |b|$.
///
pub fn convolution(comptime mod: u32, comptime T: type, allocator: Allocator, a: []const T, b: []const T) ![]T {
    const Mint = Modint(mod);
    const n = a.len;
    const m = b.len;
    if (n == 0 or m == 0) {
        return allocator.alloc(T, 0);
    }

    var a_tmp = try allocator.alloc(Mint, n);
    defer allocator.free(a_tmp);
    var b_tmp = try allocator.alloc(Mint, m);
    defer allocator.free(b_tmp);

    for (a, 0..) |x, i| {
        a_tmp[i] = Mint.init(x);
    }
    for (b, 0..) |x, i| {
        b_tmp[i] = Mint.init(x);
    }

    const c_mi = try convolutionModint(mod, allocator, a_tmp, b_tmp);
    defer allocator.free(c_mi);

    var out = try allocator.alloc(T, c_mi.len);
    for (c_mi, 0..) |v, i| {
        out[i] = v.as(T);
    }
    return out;
}

/// Calculates the $(+, \times)$ convolution in $\mathbb{Z}/p\mathbb{Z}$.
/// Caller must free returned memory.
///
/// Returns a empty `T[]` if `a` or `b` is empty.
///
/// # Constraints
///
/// - $2 \leq m \leq 2 \times 10^9$
/// - `mod` is a prime number.
/// - $\exists c \text{ s.t. } 2^c \mid (m - 1), |a| + |b| - 1 \leq 2^c$
/// - $(0, m] \subseteq$ `T`
///
/// # Complexity
///
/// - $O(n \log n + \log m)$ where $n = |a| + |b|$.
///
pub fn convolutionModint(comptime mod: u32, allocator: Allocator, a: []const Modint(mod), b: []const Modint(mod)) ![]Modint(mod) {
    const Mint = Modint(mod);
    const n = a.len;
    const m = b.len;
    if (n == 0 or m == 0) {
        return allocator.alloc(Mint, 0);
    }

    if (@min(n, m) <= 60) {
        return convolutionNaiveModint(mod, allocator, a, b);
    }

    // convolutionFFT
    const z = try std.math.ceilPowerOfTwo(usize, n + m - 1);
    assert(@mod(mod - 1, z) == 0);

    var a_tmp = try allocator.alloc(Mint, z);
    errdefer allocator.free(a_tmp);
    var b_tmp = try allocator.alloc(Mint, z);
    defer allocator.free(b_tmp);

    @memcpy(a_tmp[0..n], a);
    @memset(a_tmp[n..], Mint.raw(0));
    @memcpy(b_tmp[0..m], b);
    @memset(b_tmp[m..], Mint.raw(0));

    butterfly(mod, a_tmp);
    butterfly(mod, b_tmp);
    for (a_tmp, b_tmp) |*ai, bi| {
        ai.* = ai.mul(bi);
    }
    butterflyInv(mod, a_tmp);

    a_tmp = try allocator.realloc(a_tmp, n + m - 1);
    const iz = Mint.init(z).inv();
    for (a_tmp) |*ai| {
        ai.* = ai.mul(iz);
    }
    return a_tmp;
}

/// Calculates the $(+, \times)$ convolution in `i64`.
/// Caller must free returned memory.
///
/// Returns a empty `Vec` if `a` or `b` is empty.
///
/// # Constraints
///
/// - $|a| + |b| - 1 \leq 2^{24}$
/// - All elements of the result are inside of the range of `i64`
///
/// # Complexity
///
/// - $O(n \log n)$ where $n = |a| + |b|$.
///
pub fn convolutionI64(allocator: Allocator, a: []const i64, b: []const i64) ![]i64 {
    const n = a.len;
    const m = b.len;
    if (n == 0 or m == 0) {
        return allocator.alloc(i64, 0);
    }

    const m1: u64 = 754_974_721; // 2^24 * 45 + 1
    const m2: u64 = 167_772_161; // 2^25 * 5 + 1
    const m3: u64 = 469_762_049; // 2^26 * 7 + 1
    const m2m3: u64 = m2 * m3;
    const m1m3: u64 = m1 * m3;
    const m1m2: u64 = m1 * m2;
    const m1m2m3: u64 = m1m2 *% m3;

    const inv1 = internal.invGcd(m2m3, m1).@"1";
    const inv2 = internal.invGcd(m1m3, m2).@"1";
    const inv3 = internal.invGcd(m1m2, m3).@"1";

    const c1 = try convolution(m1, i64, allocator, a, b);
    defer allocator.free(c1);
    const c2 = try convolution(m2, i64, allocator, a, b);
    defer allocator.free(c2);
    const c3 = try convolution(m3, i64, allocator, a, b);
    defer allocator.free(c3);

    var c = try allocator.alloc(i64, n + m - 1);
    for (0..c.len) |i| {
        var x: u64 = 0;
        x +%= @as(u64, @bitCast(@rem((c1[i] *% inv1), m1))) *% m2m3;
        x +%= @as(u64, @bitCast(@rem((c2[i] *% inv2), m2))) *% m1m3;
        x +%= @as(u64, @bitCast(@rem((c3[i] *% inv3), m3))) *% m1m2;
        // B = 2^63, -B <= x, r(real value) < B
        // (x, x - M, x - 2M, or x - 3M) = r (mod 2B)
        // r = c1[i] (mod MOD1)
        // focus on MOD1
        // r = x, x - M', x - 2M', x - 3M' (M' = M % 2^64) (mod 2B)
        // r = x,
        //     x - M' + (0 or 2B),
        //     x - 2M' + (0, 2B or 4B),
        //     x - 3M' + (0, 2B, 4B or 6B) (without mod!)
        // (r - x) = 0, (0)
        //           - M' + (0 or 2B), (1)
        //           -2M' + (0 or 2B or 4B), (2)
        //           -3M' + (0 or 2B or 4B or 6B) (3) (mod MOD1)
        // we checked that
        //   ((1) mod MOD1) mod 5 = 2
        //   ((2) mod MOD1) mod 5 = 3
        //   ((3) mod MOD1) mod 5 = 4
        var diff: i64 = c1[i] - @as(i64, @intCast(@mod(x, m1)));
        if (diff < 0) {
            diff += m1;
        }
        const offset = [5]u64{ 0, 0, m1m2m3, 2 * m1m2m3, 3 * m1m2m3 };
        x -%= offset[@intCast(@mod(diff, 5))];
        c[i] = @bitCast(x);
    }
    return c;
}

// internal
fn prepareFFT(comptime mod: u32) struct {
    sum_e: [30]Modint(mod),
    sum_ie: [30]Modint(mod),
} {
    const Mint = Modint(mod);
    var sum_e = [_]Mint{Mint.raw(0)} ** 30;
    var sum_ie = [_]Mint{Mint.raw(0)} ** 30;

    const g = Mint.raw(internal.comptimePrimitiveRoot(mod));
    const cnt2: usize = @intCast(@ctz(mod - 1));
    var e = g.pow((mod - 1) >> @intCast(cnt2));
    var ie = e.inv();

    var i: isize = @as(isize, @intCast(cnt2)) - 2;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        if (idx < 30) {
            sum_e[idx] = e;
            sum_ie[idx] = ie;
        }
        e.mulAsg(e);
        ie.mulAsg(ie);
    }

    // prefix product
    var acc = Mint.raw(1);
    for (0..30) |j| {
        acc.mulAsg(sum_e[j]);
        sum_e[j] = acc;
    }
    acc = Mint.raw(1);
    for (0..30) |j| {
        acc.mulAsg(sum_ie[j]);
        sum_ie[j] = acc;
    }

    return .{ .sum_e = sum_e, .sum_ie = sum_ie };
}

fn butterfly(comptime mod: u32, a: []Modint(mod)) void {
    const Mint = Modint(mod);
    const n = a.len;
    const h = std.math.log2_int_ceil(usize, n);
    const sum_e = prepareFFT(mod).sum_e;

    for (1..h + 1) |ph| {
        const w: usize = @as(usize, 1) << @truncate(ph - 1);
        const p: usize = @as(usize, 1) << @truncate(h - ph);
        var now = Mint.raw(1);
        for (0..w) |s| {
            const offset = s << @truncate(h - ph + 1);
            for (0..p) |i| {
                const l = a[i + offset];
                const r = a[i + offset + p].mul(now);
                a[i + offset] = l.add(r);
                a[i + offset + p] = l.sub(r);
            }
            const idx = trailingZerosOfNot(s);
            // idx is always < 30 for our moduli; also sum_e pre-filled with 1.
            now.mulAsg(sum_e[idx]);
        }
    }
}

fn butterflyInv(comptime mod: u32, a: []Modint(mod)) void {
    const Mint = Modint(mod);
    const n = a.len;
    const h = std.math.log2_int_ceil(usize, n);
    const sum_ie = prepareFFT(mod).sum_ie;

    var phi: isize = @intCast(h);
    while (phi >= 1) : (phi -= 1) {
        const ph: usize = @intCast(phi);
        const w: usize = @as(usize, 1) << @truncate(ph - 1);
        const p: usize = @as(usize, 1) << @truncate(h - ph);
        var inow = Mint.raw(1);
        for (0..w) |s| {
            const offset = s << @truncate(h - ph + 1);
            for (0..p) |i| {
                const l = a[i + offset];
                const r = a[i + offset + p];
                a[i + offset] = l.add(r);
                // M + l - r (to avoid negative)
                const t = Mint.raw(mod + l.val - r.val).mul(inow);
                a[i + offset + p] = t;
            }
            const idx = trailingZerosOfNot(s);
            inow.mulAsg(sum_ie[idx]);
        }
    }
}

fn convolutionNaiveModint(comptime mod: u32, allocator: Allocator, a: []const Modint(mod), b: []const Modint(mod)) ![]Modint(mod) {
    const Mint = Modint(mod);
    const n = a.len;
    const m = b.len;

    var ans = try allocator.alloc(Mint, n + m - 1);
    @memset(ans, Mint.raw(0));
    for (0..m) |j| {
        for (0..n) |i| {
            // ans[i + j] += a[i] * b[j];
            ans[i + j].addAsg(a[i].mul(b[j]));
        }
    }
    return ans;
}

fn convolutionNaive(comptime mod: u32, comptime T: type, allocator: Allocator, a: []const T, b: []const T) ![]T {
    const n = a.len;
    const m = b.len;
    var ans = try allocator.alloc(T, n + m - 1);
    @memset(ans, 0);
    for (0..m) |j| {
        for (0..n) |i| {
            ans[i + j] += @intCast(std.math.comptimeMod(std.math.mulWide(T, a[i], b[j]), mod));
            if (ans[i + j] >= mod) {
                ans[i + j] -= mod;
            }
        }
    }
    return ans;
}

fn convolutionNaiveI64(allocator: Allocator, a: []const i64, b: []const i64) ![]i64 {
    const n = a.len;
    const m = b.len;
    var ans = try allocator.alloc(i64, n + m - 1);
    @memset(ans, 0);
    for (0..m) |j| {
        for (0..n) |i| {
            ans[i + j] +%= a[i] *% b[j];
        }
    }
    return ans;
}

fn trailingZerosOfNot(s: usize) u32 {
    return @ctz(~s);
}

const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L51-L71
test "convolution test: empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const mod = 998244353;
    const Mint = Modint(mod);
    try expectEqual((try convolution(mod, i32, allocator, &.{}, &.{})).len, 0);
    try expectEqual((try convolution(mod, i32, allocator, &.{}, &.{ 1, 2 })).len, 0);
    try expectEqual((try convolution(mod, i32, allocator, &.{ 1, 2 }, &.{})).len, 0);
    try expectEqual((try convolution(mod, i32, allocator, &.{1}, &.{})).len, 0);
    try expectEqual((try convolution(mod, i64, allocator, &.{}, &.{})).len, 0);
    try expectEqual((try convolution(mod, i64, allocator, &.{}, &.{ 1, 2 })).len, 0);
    try expectEqual((try convolutionModint(mod, allocator, &.{}, &.{})).len, 0);
    try expectEqual((try convolutionModint(mod, allocator, &.{}, &.{ Mint.init(1), Mint.init(2) })).len, 0);
    try expectEqual((try convolutionModint(mod, allocator, &.{ Mint.init(1), Mint.init(2) }, &.{})).len, 0);
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L73-L85
test "convolution test: mid" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const n: usize = 1234;
    const m: usize = 2345;

    const mod = 998244353;
    const Mint = Modint(mod);

    const rand = std.crypto.random;
    const a = try allocator.alloc(Mint, n);
    const b = try allocator.alloc(Mint, m);
    defer allocator.free(b);

    for (a) |*elem| {
        elem.* = Mint.init(rand.intRangeAtMost(u32, 0, mod - 1));
    }
    for (b) |*elem| {
        elem.* = Mint.init(rand.intRangeAtMost(u32, 0, mod - 1));
    }

    try expectEqualSlices(
        Mint,
        try convolutionNaiveModint(mod, allocator, a, b),
        try convolutionModint(mod, allocator, a, b),
    );
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L87-L118
test "convolution test: simple s mod" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const rand = std.crypto.random;

    inline for (.{ 998_244_353, 924_844_033 }) |mod| {
        const Mint = Modint(mod);
        for (1..20) |n| {
            for (1..20) |m| {
                const a = try allocator.alloc(Mint, n);
                const b = try allocator.alloc(Mint, m);

                for (a) |*elem| {
                    elem.* = Mint.init(rand.intRangeAtMost(u32, 0, mod - 1));
                }
                for (b) |*elem| {
                    elem.* = Mint.init(rand.intRangeAtMost(u32, 0, mod - 1));
                }

                try expectEqualSlices(
                    Mint,
                    try convolutionNaiveModint(mod, allocator, a, b),
                    try convolutionModint(mod, allocator, a, b),
                );
            }
        }
    }
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L120-L150
test "convolution test: simple i32" {
    try simpleTest(i32);
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L152-L182
test "convolution test: simple u32" {
    try simpleTest(u32);
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L184-L214
test "convolution test: simple i64" {
    try simpleTest(i64);
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L216-L246
test "convolution test: simple u64" {
    try simpleTest(u64);
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L249-L279
test "convolution test: simple i128" {
    try simpleTest(i128);
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L281-L311
test "convolution test: simple u128" {
    try simpleTest(u128);
}

fn simpleTest(T: type) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const rand = std.crypto.random;

    inline for (.{ 998_244_353, 924_844_033 }) |mod| {
        for (1..20) |n| {
            for (1..20) |m| {
                const a = try allocator.alloc(T, n);
                const b = try allocator.alloc(T, m);

                for (a) |*elem| {
                    elem.* = rand.intRangeAtMost(T, 0, mod - 1);
                }
                for (b) |*elem| {
                    elem.* = rand.intRangeAtMost(T, 0, mod - 1);
                }

                try expectEqualSlices(
                    T,
                    try convolutionNaive(mod, T, allocator, a, b),
                    try convolution(mod, T, allocator, a, b),
                );
            }
        }
    }
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L315-L329
test "convolution test: conv_ll" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    for (1..20) |n| {
        for (1..20) |m| {
            const a = try allocator.alloc(i64, n);
            const b = try allocator.alloc(i64, m);

            const rand = std.crypto.random;

            for (a) |*elem| {
                elem.* = rand.intRangeAtMost(i64, -500_000, 1_000_000 - 1);
            }
            for (b) |*elem| {
                elem.* = rand.intRangeAtMost(i64, -500_000, 1_000_000 - 1);
            }

            try expectEqualSlices(
                i64,
                try convolutionNaiveI64(allocator, a, b),
                try convolutionI64(allocator, a, b),
            );
        }
    }
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L331-L356
test "convolution test: conv_ll_bound" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const mod1 = 469762049; // 2^26
    const mod2 = 167772161; // 2^25
    const mod3 = 754974721; // 2^24
    const m2m3: u64 = mod2 * mod3;
    const m1m3: u64 = mod1 * mod3;
    const m1m2: u64 = mod1 * mod2;

    for (0..2000 + 1) |raw_i| {
        const i = @as(i64, @intCast(raw_i)) - 1000;
        const base = @as(u64, 0) -% (m1m2 + m1m3 + m2m3);
        const a = [1]i64{@as(i64, @bitCast(base)) + i};
        const b = [1]i64{1};

        try expectEqualSlices(i64, &a, try convolutionI64(allocator, &a, &b));
    }

    for (0..1000) |i| {
        const a = [1]i64{std.math.minInt(i64) + @as(i64, @intCast(i))};
        const b = [1]i64{1};

        try expectEqualSlices(i64, &a, try convolutionI64(allocator, &a, &b));
    }

    for (0..1000) |i| {
        const a = [1]i64{std.math.maxInt(i64) - @as(i64, @intCast(i))};
        const b = [1]i64{1};

        try expectEqualSlices(i64, &a, try convolutionI64(allocator, &a, &b));
    }
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L358-L371
test "convolution test: conv_641" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 641 = 128 * 5 + 1
    const mod = 641;

    const a = try allocator.alloc(i64, 64);
    const b = try allocator.alloc(i64, 65);

    const rand = std.crypto.random;

    for (a) |*elem| {
        elem.* = rand.intRangeAtMost(i64, 0, mod - 1);
    }
    for (b) |*elem| {
        elem.* = rand.intRangeAtMost(i64, 0, mod - 1);
    }

    try expectEqualSlices(
        i64,
        try convolutionNaive(mod, i64, allocator, a, b),
        try convolution(mod, i64, allocator, a, b),
    );
}

// https://github.com/atcoder/ac-library/blob/8250de484ae0ab597391db58040a602e0dc1a419/test/unittest/convolution_test.cpp#L373-L386
test "convolution test: conv_18433" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // 18433 = 2048 * 9 + 1
    const mod = 18433;

    const a = try allocator.alloc(i64, 1024);
    const b = try allocator.alloc(i64, 1025);

    const rand = std.crypto.random;

    for (a) |*elem| {
        elem.* = rand.intRangeAtMost(i64, 0, mod - 1);
    }
    for (b) |*elem| {
        elem.* = rand.intRangeAtMost(i64, 0, mod - 1);
    }

    try expectEqualSlices(
        i64,
        try convolutionNaive(mod, i64, allocator, a, b),
        try convolution(mod, i64, allocator, a, b),
    );
}
