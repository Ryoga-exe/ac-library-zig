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
        const x: u64 = @intCast(((@as(u128, z) * @as(u128, self.im)) >> 64));
        var v: u32 = @intCast(z -% (x *% @as(u64, self.m)));
        if (self.m <= v) {
            v +%= self.m;
        }
        return v;
    }
};
