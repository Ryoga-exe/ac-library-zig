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
