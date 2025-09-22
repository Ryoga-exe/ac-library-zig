const std = @import("std");
const Allocator = std.mem.Allocator;
const Modint = @import("modint.zig").StaticModint;
const assert = std.debug.assert;

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

    const c_mi = try convolutionModInt(mod, allocator, a_tmp, b_tmp);
    defer allocator.free(c_mi);

    var out = try allocator.alloc(T, c_mi.len);
    for (c_mi, 0..) |v, i| {
        out[i] = v.as(T);
    }
    return out;
}

pub fn convolutionModInt(comptime mod: u32, allocator: Allocator, a: []const Modint(mod), b: []const Modint(mod)) ![]Modint(mod) {
    const Mint = Modint(mod);
    const n = a.len;
    const m = b.len;
    if (n == 0 or m == 0) {
        return allocator.alloc(Mint, 0);
    }

    if (@min(n, m) <= 60) {
        // convolutionNaive
        var ans = try allocator.alloc(Mint, n + m - 1);
        for (0..m) |j| {
            for (0..n) |i| {
                // ans[i + j] += a[i] * b[j];
                ans[i + j].addAsg(a[i].mul(b[i]));
            }
        }
        return ans;
    }

    // convolutionFFT
    const z = std.math.ceilPowerOfTwo(usize, n + m - 1);
    assert(@mod(mod - 1, z) == 0);

    var a_tmp = try allocator.alloc(Mint, z);
    errdefer allocator.free(a_tmp);
    var b_tmp = try allocator.alloc(Mint, z);
    defer allocator.free(b_tmp);

    @memcpy(a_tmp[0..n], a);
    @memset(a_tmp[n..], Mint.raw(0));
    @memcpy(b_tmp[0..m], b);
    @memset(b_tmp[m..], Mint.raw(0));

    // butterfly(&a_tmp)
    // butterfly(&b_tmp)
    for (a_tmp, b_tmp) |*ai, bi| {
        ai.* = ai.mul(bi);
    }
    // butterflyInv(&a_tmp)

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
}
