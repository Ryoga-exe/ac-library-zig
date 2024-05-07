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
    const query = &[_]struct { a: i64, b: i64, g: i64 }{
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

    for (query) |q| {
        const res = invGcd(q.a, q.b);
        try std.testing.expectEqual(q.g, res.@"0");

        const b = @as(i128, q.b);
        try std.testing.expectEqual(@mod(@as(i128, q.g), b), @mod(@mod((@as(i128, res.@"1") * @as(i128, q.a)), b) + b, b));
    }
}
