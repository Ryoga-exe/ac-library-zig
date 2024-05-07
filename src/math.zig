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
    try std.testing.expectEqual(@as(i64, 1), @mod(invMod(3, 1_000_000_007) * 3, 1_000_000_007));
    try std.testing.expectEqual(@as(i64, 1), @mod(invMod(123, 1_000_000_007) * 123, 1_000_000_007));
    try std.testing.expectEqual(@as(i64, 1), @mod(invMod(456, 1_000_000_007) * 456, 1_000_000_007));
}
