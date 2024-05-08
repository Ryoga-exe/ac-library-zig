const std = @import("std");
const internal = @import("internal_math.zig");
const assert = std.debug.assert;

pub fn powMod(x: i64, n: i64, m: u32) u32 {
    assert(0 <= n and 1 <= m);
    if (m == 1) {
        return 0;
    }
    var k = n;
    var bt = internal.Barrett.init(m);
    var r: u32 = 1;
    var y: u32 = @intCast(@mod(x, m));
    while (k != 0) {
        if (k & 1 != 0) {
            r = bt.mul(r, y);
        }
        y = bt.mul(y, y);
        k >>= 1;
    }
    return r;
}

// https://github.com/rust-lang-ja/ac-library-rs/blob/5323fca53ff8a49e67387ddfabc299110c17922c/src/math.rs#L215
test powMod {
    try std.testing.expectEqual(@as(u32, 0), powMod(0, 0, 1));
    try std.testing.expectEqual(@as(u32, 1), powMod(0, 0, 3));
    try std.testing.expectEqual(@as(u32, 1), powMod(0, 0, 723));
    try std.testing.expectEqual(@as(u32, 1), powMod(0, 0, 998244353));
    try std.testing.expectEqual(@as(u32, 1), powMod(0, 0, 1 << 31));

    try std.testing.expectEqual(@as(u32, 0), powMod(0, 1, 1));
    try std.testing.expectEqual(@as(u32, 0), powMod(0, 1, 3));
    try std.testing.expectEqual(@as(u32, 0), powMod(0, 1, 723));
    try std.testing.expectEqual(@as(u32, 0), powMod(0, 1, 998244353));
    try std.testing.expectEqual(@as(u32, 0), powMod(0, 1, 1 << 31));

    const maxInt = std.math.maxInt;

    try std.testing.expectEqual(@as(u32, 0), powMod(0, maxInt(i64), 1));
    try std.testing.expectEqual(@as(u32, 0), powMod(0, maxInt(i64), 3));
    try std.testing.expectEqual(@as(u32, 0), powMod(0, maxInt(i64), 723));
    try std.testing.expectEqual(@as(u32, 0), powMod(0, maxInt(i64), 998244353));
    try std.testing.expectEqual(@as(u32, 0), powMod(0, maxInt(i64), 1 << 31));

    try std.testing.expectEqual(@as(u32, 0), powMod(1, 0, 1));
    try std.testing.expectEqual(@as(u32, 1), powMod(1, 0, 3));
    try std.testing.expectEqual(@as(u32, 1), powMod(1, 0, 723));
    try std.testing.expectEqual(@as(u32, 1), powMod(1, 0, 998244353));
    try std.testing.expectEqual(@as(u32, 1), powMod(1, 0, 1 << 31));

    try std.testing.expectEqual(@as(u32, 0), powMod(maxInt(i64), maxInt(i64), 1));
    try std.testing.expectEqual(@as(u32, 1), powMod(maxInt(i64), maxInt(i64), 3));
    try std.testing.expectEqual(@as(u32, 640), powMod(maxInt(i64), maxInt(i64), 723));
    try std.testing.expectEqual(@as(u32, 683296792), powMod(maxInt(i64), maxInt(i64), 998244353));
    try std.testing.expectEqual(@as(u32, 2147483647), powMod(maxInt(i64), maxInt(i64), 1 << 31));

    try std.testing.expectEqual(@as(u32, 8), powMod(2, 3, 1_000_000_007));
    try std.testing.expectEqual(@as(u32, 78125), powMod(5, 7, 1_000_000_007));
    try std.testing.expectEqual(@as(u32, 565291922), powMod(123, 456, 1_000_000_007));
}

pub fn invMod(x: i64, m: i64) i64 {
    assert(1 <= m);
    const z = internal.invGcd(x, m);
    assert(z.@"0" == 1);
    return z.@"1";
}

test invMod {
    try std.testing.expectEqual(@as(i64, 1), @mod(invMod(3, 998244353) * 3, 998244353));
    try std.testing.expectEqual(@as(i64, 1), @mod(invMod(123, 998244353) * 123, 998244353));
    try std.testing.expectEqual(@as(i64, 1), @mod(invMod(456, 998244353) * 456, 998244353));

    try std.testing.expectEqual(@as(i64, 1), @mod(invMod(3, 1_000_000_007) * 3, 1_000_000_007));
    try std.testing.expectEqual(@as(i64, 1), @mod(invMod(123, 1_000_000_007) * 123, 1_000_000_007));
    try std.testing.expectEqual(@as(i64, 1), @mod(invMod(456, 1_000_000_007) * 456, 1_000_000_007));
}

pub fn crt(r: []const i64, m: []const i64) struct { i64, i64 } {
    assert(r.len == m.len);

    // Contracts: 0 <= r0 < m0
    var r0: i64 = 0;
    var m0: i64 = 1;
    for (r, m) |rr, mm| {
        assert(1 <= mm);
        var ri = @mod(rr, mm);
        var mi = mm;
        if (m0 < mi) {
            std.mem.swap(i64, &r0, &ri);
            std.mem.swap(i64, &m0, &mi);
        }
        if (@mod(m0, mi) == 0) {
            if (@mod(r0, mi) != ri) {
                return .{ 0, 0 };
            }
            continue;
        }
        // assume: m0 > mi, lcm(m0, mi) >= 2 * max(m0, mi)

        // (r0, m0), (ri, mi) -> (r2, m2 = lcm(m0, m1));
        // r2 % m0 = r0
        // r2 % mi = ri
        // -> (r0 + x*m0) % mi = ri
        // -> x*u0*g = ri-r0 (mod u1*g) (u0*g = m0, u1*g = mi)
        // -> x = (ri - r0) / g * inv(u0) (mod u1)

        // im = inv(u0) (mod u1) (0 <= im < u1)
        const gim = internal.invGcd(m0, mi);
        const g = gim.@"0";
        const im = gim.@"1";
        const ui = @divFloor(mi, g);
        // |ri - r0| < (m0 + mi) <= lcm(m0, mi)
        if (@mod(ri - r0, g) != 0) {
            return .{ 0, 0 };
        }
        // u1 * u1 <= mi * mi / g / g <= m0 * mi / g = lcm(m0, mi)
        const x = @mod(@mod(@divFloor(ri - r0, g), ui) * im, ui);

        // |r0| + |m0 * x|
        // < m0 + m0 * (u1 - 1)
        // = m0 + m0 * mi / g - m0
        // = lcm(m0, mi)
        r0 += x * m0;
        m0 *= ui; // -> lcm(m0, mi)
        if (r0 < 0) {
            r0 += m0;
        }
    }

    return .{ r0, m0 };
}

test crt {
    const tests = [_]struct { a: []const i64, b: []const i64, expected: struct { i64, i64 } }{
        .{
            .a = &[_]i64{ 44, 23, 13 },
            .b = &[_]i64{ 13, 50, 22 },
            .expected = .{ 1773, 7150 },
        },
        .{
            .a = &[_]i64{ 12345, 67890, 99999 },
            .b = &[_]i64{ 13, 444321, 95318 },
            .expected = .{ 103333581255, 550573258014 },
        },
        .{
            .a = &[_]i64{ 0, 3, 4 },
            .b = &[_]i64{ 1, 9, 5 },
            .expected = .{ 39, 45 },
        },
    };

    for (tests) |t| {
        const expected = t.expected;
        const result = crt(t.a, t.b);

        try std.testing.expectEqual(expected.@"0", result.@"0");
        try std.testing.expectEqual(expected.@"1", result.@"1");
    }
}

pub fn floorSum(n: i64, m: i64, a: i64, b: i64) i64 {
    var ans: i64 = 0;
    var a_ = a;
    if (a >= m) {
        ans +%= @divFloor((n - 1) *% n *% @divFloor(a, m), 2);
        a_ = @mod(a, m);
    }
    var b_ = b;
    if (b >= m) {
        ans +%= n *% @divFloor(b, m);
        b_ = @mod(b, m);
    }

    const y_max = @divFloor(a_ *% n +% b_, m);
    const x_max = y_max *% m -% b_;
    if (y_max == 0) {
        return ans;
    }
    ans +%= (n -% @divFloor((x_max +% a_ -% 1), a_)) *% y_max;
    ans +%= floorSum(y_max, a_, m, @mod((a_ - @mod(x_max, a_)), a_));
    return ans;
}

test floorSum {
    try std.testing.expectEqual(@as(i64, 0), floorSum(0, 1, 0, 0));
    try std.testing.expectEqual(@as(i64, 500_000_000_500_000_000), floorSum(1_000_000_000, 1, 1, 1));
    try std.testing.expectEqual(@as(i64, 499_999_999_500_000_000), floorSum(1_000_000_000, 1_000_000_000, 999_999_999, 999_999_999));
    try std.testing.expectEqual(@as(i64, 22014575), floorSum(332955, 5590132, 2231, 999423));
}
