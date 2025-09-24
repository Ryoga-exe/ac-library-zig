const std = @import("std");

pub const Barrett = struct {
    const Self = @This();

    m: u32,
    im: u64,

    pub fn init(m: u32) Self {
        return Self{
            .m = m,
            .im = (@as(u64, @bitCast(@as(i64, -1))) / @as(u64, m)) +% 1,
        };
    }

    pub fn umod(self: Self) u32 {
        return self.m;
    }

    pub fn mul(self: *Self, a: u32, b: u32) u32 {
        // [1] m = 1
        // a = b = im = 0, so okay

        // [2] m >= 2
        // im = ceil(2^64 / m)
        // -> im * m = 2^64 + r (0 <= r < m)
        // let z = a*b = c*m + d (0 <= c, d < m)
        // a*b * im = (c*m + d) * im = c*(im*m) + d*im = c*2^64 + c*r + d*im
        // c*r + d*im < m * m + m * im < m * m + 2^64 + m <= 2^64 + m * (m + 1) < 2^64 * 2
        // ((ab * im) >> 64) == c or c + 1
        var z = @as(u64, a);
        z *= @as(u64, b);
        const x: u64 = @truncate(((@as(u128, z) * @as(u128, self.im)) >> 64));
        var v: u32 = @truncate(z -% (x *% @as(u64, self.m)));
        if (self.m <= v) {
            v +%= self.m;
        }
        return v;
    }
};

test Barrett {
    var b1 = Barrett.init(7);
    try std.testing.expectEqual(@as(u32, 7), b1.umod());
    try std.testing.expectEqual(@as(u32, 6), b1.mul(2, 3));
    try std.testing.expectEqual(@as(u32, 3), b1.mul(4, 6));
    try std.testing.expectEqual(@as(u32, 0), b1.mul(5, 0));

    var b2 = Barrett.init(998244353);
    try std.testing.expectEqual(@as(u33, 998244353), b2.umod());
    try std.testing.expectEqual(@as(u32, 6), b2.mul(2, 3));
    try std.testing.expectEqual(@as(u32, 919583920), b2.mul(3141592, 653589));
    try std.testing.expectEqual(@as(u32, 568012980), b2.mul(323846264, 338327950));

    var b3 = Barrett.init(2147483647);
    try std.testing.expectEqual(@as(u33, 2147483647), b3.umod());
    try std.testing.expectEqual(@as(u32, 2147483646), b3.mul(1073741824, 2147483645));
}

// (x ^ n) % m
pub fn comptimePowMod(x: comptime_int, n: comptime_int, m: comptime_int) comptime_int {
    if (!(0 <= n and 1 <= m)) {
        @compileError("Arguments do not satisfy 0 <= n and 1 <= m");
    }
    if (m == 1) {
        return 0;
    }
    var _n = n;
    var r = 1;
    var y = @mod(x, m);
    while (_n > 0) : (_n >>= 1) {
        if (_n & 1 == 1) {
            r = (r * y) % m;
        }
        y = (y * y) % m;
    }
    return r;
}

test comptimePowMod {
    const i32max = std.math.maxInt(i32);
    const i64max = std.math.maxInt(i64);
    const tests = comptime &[_]struct { x: comptime_int, n: comptime_int, m: comptime_int, expects: comptime_int }{
        .{ .x = 0, .n = 0, .m = 1, .expects = 0 },
        .{ .x = 0, .n = 0, .m = 3, .expects = 1 },
        .{ .x = 0, .n = 0, .m = 723, .expects = 1 },
        .{ .x = 0, .n = 0, .m = 998244353, .expects = 1 },
        .{ .x = 0, .n = 0, .m = i32max, .expects = 1 },

        .{ .x = 0, .n = 1, .m = 1, .expects = 0 },
        .{ .x = 0, .n = 1, .m = 3, .expects = 0 },
        .{ .x = 0, .n = 1, .m = 723, .expects = 0 },
        .{ .x = 0, .n = 1, .m = 998244353, .expects = 0 },
        .{ .x = 0, .n = 1, .m = i32max, .expects = 0 },

        .{ .x = 0, .n = i64max, .m = 1, .expects = 0 },
        .{ .x = 0, .n = i64max, .m = 3, .expects = 0 },
        .{ .x = 0, .n = i64max, .m = 723, .expects = 0 },
        .{ .x = 0, .n = i64max, .m = 998244353, .expects = 0 },
        .{ .x = 0, .n = i64max, .m = i32max, .expects = 0 },

        .{ .x = 1, .n = 0, .m = 1, .expects = 0 },
        .{ .x = 1, .n = 0, .m = 3, .expects = 1 },
        .{ .x = 1, .n = 0, .m = 723, .expects = 1 },
        .{ .x = 1, .n = 0, .m = 998244353, .expects = 1 },
        .{ .x = 1, .n = 0, .m = i32max, .expects = 1 },

        .{ .x = 1, .n = 1, .m = 1, .expects = 0 },
        .{ .x = 1, .n = 1, .m = 3, .expects = 1 },
        .{ .x = 1, .n = 1, .m = 723, .expects = 1 },
        .{ .x = 1, .n = 1, .m = 998244353, .expects = 1 },
        .{ .x = 1, .n = 1, .m = i32max, .expects = 1 },

        .{ .x = 1, .n = i64max, .m = 1, .expects = 0 },
        .{ .x = 1, .n = i64max, .m = 3, .expects = 1 },
        .{ .x = 1, .n = i64max, .m = 723, .expects = 1 },
        .{ .x = 1, .n = i64max, .m = 998244353, .expects = 1 },
        .{ .x = 1, .n = i64max, .m = i32max, .expects = 1 },

        .{ .x = i64max, .n = 0, .m = 1, .expects = 0 },
        .{ .x = i64max, .n = 0, .m = 3, .expects = 1 },
        .{ .x = i64max, .n = 0, .m = 723, .expects = 1 },
        .{ .x = i64max, .n = 0, .m = 998244353, .expects = 1 },
        .{ .x = i64max, .n = 0, .m = i32max, .expects = 1 },

        .{ .x = i64max, .n = i64max, .m = 1, .expects = 0 },
        .{ .x = i64max, .n = i64max, .m = 3, .expects = 1 },
        .{ .x = i64max, .n = i64max, .m = 723, .expects = 640 },
        .{ .x = i64max, .n = i64max, .m = 998244353, .expects = 683296792 },
        .{ .x = i64max, .n = i64max, .m = i32max, .expects = 1 },

        .{ .x = 2, .n = 3, .m = 1_000_000_007, .expects = 8 },
        .{ .x = 5, .n = 7, .m = 1_000_000_007, .expects = 78125 },
        .{ .x = 123, .n = 456, .m = 1_000_000_007, .expects = 565291922 },
    };
    inline for (tests) |t| {
        try std.testing.expectEqual(t.expects, comptimePowMod(t.x, t.n, t.m));
    }
}

// Reference:
// M. Forisek and J. Jancina,
// Fast Primality Testing for Integers That Fit into a Machine Word
pub fn comptimeIsPrime(n: comptime_int) bool {
    if (n == 2) {
        return true;
    } else if (n <= 1 or n % 2 == 0) {
        return false;
    }
    const base = std.math.log2(n);
    const upper = (1 << base) - 1;
    const magnitude_bits = if (upper >= n) base else base + 1;

    // Reference:
    // https://en.wikipedia.org/wiki/Miller%E2%80%93Rabin_primality_test
    // https://miller-rabin.appspot.com/
    // https://oeis.org/A014233
    const seq = switch (magnitude_bits) {
        0...32 => [_]comptime_int{ 2, 7, 61 },
        33...64 => [_]comptime_int{ 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37 },
        else => @compileError("n is too large"),
    };

    inline for (seq) |v| {
        if (n == v) {
            return true;
        }
    }

    const d = comptime blk: {
        var d = n - 1;
        while (d % 2 == 0) {
            d /= 2;
        }
        break :blk d;
    };
    inline for (seq) |a| {
        const t, const y = comptime blk: {
            var t = d;
            var y = comptimePowMod(a, t, n);
            while (t != n - 1 and y != 1 and y != n - 1) : (t <<= 1) {
                y = y * y % n;
            }
            break :blk .{ t, y };
        };
        if (y != n - 1 and t % 2 == 0) {
            return false;
        }
    }
    return true;
}

test comptimeIsPrime {
    const tests = comptime &[_]struct { x: comptime_int, expects: bool }{
        .{ .x = 0, .expects = false },
        .{ .x = 1, .expects = false },
        .{ .x = 2, .expects = true },
        .{ .x = 3, .expects = true },
        .{ .x = 4, .expects = false },
        .{ .x = 5, .expects = true },
        .{ .x = 6, .expects = false },
        .{ .x = 7, .expects = true },
        .{ .x = 8, .expects = false },
        .{ .x = 9, .expects = false },

        // .{ .x = 57, .expect = true },
        .{ .x = 57, .expects = false },
        .{ .x = 58, .expects = false },
        .{ .x = 59, .expects = true },
        .{ .x = 60, .expects = false },
        .{ .x = 61, .expects = true },
        .{ .x = 62, .expects = false },

        .{ .x = 701928443, .expects = false },
        .{ .x = 998244353, .expects = true },
        .{ .x = 1_000_000_000, .expects = false },
        .{ .x = 1_000_000_007, .expects = true },

        .{ .x = std.math.maxInt(i32), .expects = true },
        .{ .x = std.math.maxInt(i62), .expects = true },
        .{ .x = std.math.maxInt(i64), .expects = false },
    };
    inline for (tests) |t| {
        try std.testing.expectEqual(t.expects, comptimeIsPrime(t.x));
    }
}

pub fn invGcd(a: i64, b: i64) struct { i64, i64 } {
    const c = @mod(a, b);
    if (c == 0) {
        return .{ b, 0 };
    }

    // Contracts:
    // [1] s - m0 * c = 0 (mod b)
    // [2] t - m1 * c = 0 (mod b)
    // [3] s * |m1| + t * |m0| <= b
    var s = b;
    var t = c;
    var m0: i64 = 0;
    var m1: i64 = 1;

    while (t != 0) {
        const u = @divFloor(s, t);
        s -= t * u;
        m0 -= m1 * u; // |m1 * u| <= |m1| * s <= b

        // [3]:
        // (s - t * u) * |m1| + t * |m0 - m1 * u|
        // <= s * |m1| - t * u * |m1| + t * (|m0| + |m1| * u)
        // = s * |m1| + t * |m0| <= b

        std.mem.swap(i64, &s, &t);
        std.mem.swap(i64, &m0, &m1);
    }
    // by [3]: |m0| <= b/g
    // by g != b: |m0| < b/g
    if (m0 < 0) {
        m0 += @divFloor(b, s);
    }
    return .{ s, m0 };
}

test invGcd {
    const maxInt = std.math.maxInt;
    const minInt = std.math.minInt;
    const tests = &[_]struct { a: i64, b: i64, g: i64 }{
        .{ .a = 0, .b = 1, .g = 1 },
        .{ .a = 0, .b = 1, .g = 1 },
        .{ .a = 0, .b = 4, .g = 4 },
        .{ .a = 0, .b = 7, .g = 7 },
        .{ .a = 2, .b = 3, .g = 1 },
        .{ .a = -2, .b = 3, .g = 1 },
        .{ .a = 4, .b = 6, .g = 2 },
        .{ .a = -4, .b = 6, .g = 2 },
        .{ .a = 13, .b = 23, .g = 1 },
        .{ .a = 57, .b = 81, .g = 3 },
        .{ .a = 12345, .b = 67890, .g = 15 },
        .{ .a = -3141592 * 6535, .b = 3141592 * 8979, .g = 3141592 },
        .{ .a = maxInt(i64), .b = maxInt(i64), .g = maxInt(i64) },
        .{ .a = minInt(i64), .b = maxInt(i64), .g = 1 },
    };

    for (tests) |t| {
        const g, const x = invGcd(t.a, t.b);
        try std.testing.expectEqual(t.g, g);

        const b = @as(i128, t.b);
        try std.testing.expectEqual(@mod(@as(i128, t.g), b), @mod(@mod((@as(i128, x) * @as(i128, t.a)), b) + b, b));
    }
}

/// Comptime primitive root
/// param `m` must be prime
/// returns primitive root (and minimum in now)
pub fn comptimePrimitiveRoot(m: comptime_int) comptime_int {
    switch (m) {
        2 => return 1,
        167_772_161 => return 3,
        469_762_049 => return 3,
        754_974_721 => return 11,
        998_244_353 => return 3,
        else => {},
    }

    comptime var divs = [_]comptime_int{0} ** 20;
    divs[0] = 2;
    comptime var cnt = 1;
    comptime var x = (m - 1) / 2;
    inline while (x % 2 == 0) {
        x /= 2;
    }
    comptime var i = 3;

    inline while (i * i <= x) : (i += 2) {
        if (x % i == 0) {
            divs[cnt] = i;
            cnt += 1;
            inline while (x % i == 0) {
                x /= i;
            }
        }
    }
    if (x > 1) {
        divs[cnt] = x;
        cnt += 1;
    }
    comptime var g = 2;
    inline while (true) : (g += 1) {
        var ok = true;
        for (divs[0..cnt]) |div| {
            if (comptimePowMod(g, (m - 1) / div, m) == 1) {
                ok = false;
                break;
            }
        }
        if (ok) {
            return g;
        }
    }
}

test comptimePrimitiveRoot {
    inline for (.{
        2,
        3,
        5,
        7,
        233,
        200003,
        998244353,
        1_000_000_007,
        std.math.maxInt(i32),
    }) |p| {
        try std.testing.expect(comptimeIsPrime(p));
        const g = comptimePrimitiveRoot(p);
        if (p != 2) {
            try std.testing.expect(g != 1);
        }

        const q = p - 1;
        comptime var i: comptime_int = 2;
        @setEvalBranchQuota(500000);
        inline while (i * i <= q) : (i += 1) {
            if (q % i != 0) {
                break;
            }
            try std.testing.expect(comptimePowMod(g, i, p) != 1);
            try std.testing.expect(comptimePowMod(g, q / i, p) != 1);
        }
        try std.testing.expectEqual(1, comptimePowMod(g, q, p));

        if (p < 1_000_000) {
            const allocator = std.testing.allocator;
            var hashmap = std.AutoHashMap(usize, void).init(allocator);
            defer hashmap.deinit();

            for (0..p - 1) |v| {
                try hashmap.put(v * g % p, {});
            }
            try std.testing.expectEqual(p - 1, hashmap.count());
        }
    }
}
