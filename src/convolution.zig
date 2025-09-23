const std = @import("std");
const Allocator = std.mem.Allocator;
const Modint = @import("modint.zig").StaticModint;
const assert = std.debug.assert;

const internal = @import("internal_math.zig");

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

pub fn convolutionI64(allocator: Allocator, a: []const i64, b: []const i64) ![]i64 {
    _ = allocator; // autofix
    _ = a; // autofix
    _ = b; // autofix
    // TODO: implement
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
    const prep = prepareFFT(mod);
    const sum_e = prep.sum_e;

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
    const prep = prepareFFT(mod);
    const sum_ie = prep.sum_ie;

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

    try expectEqualSlices(Mint, try convolutionNaiveModint(mod, allocator, a, b), try convolutionModint(mod, allocator, a, b));
}
