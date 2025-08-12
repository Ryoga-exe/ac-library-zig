const std = @import("std");
const internal = @import("internal_math.zig");

pub fn StaticModint(comptime m: comptime_int) type {
    if (m < 1) {
        @compileError("m must be greater than or equal to 1");
    }

    const T = comptime std.math.IntFittingRange(0, m - 1);

    return struct {
        const Self = @This();
        const prime = internal.comptimeIsPrime(m);

        val: T,

        pub inline fn mod(_: Self) comptime_int {
            return m;
        }

        pub inline fn raw(v: anytype) Self {
            return Self{ .val = @intCast(v) };
        }

        pub inline fn as(self: Self, Type: type) Type {
            return @intCast(self.val);
        }

        pub inline fn init(v: anytype) Self {
            return Self{ .val = std.math.comptimeMod(v, m) };
        }

        pub inline fn add(self: Self, v: anytype) Self {
            const x: T = switch (@TypeOf(v)) {
                inline Self => v.val,
                inline else => std.math.comptimeMod(v, m),
            };
            return Self{
                .val = std.math.comptimeMod(self.val + x, m),
            };
        }

        pub inline fn sub(self: Self, v: anytype) Self {
            const x: T = switch (@TypeOf(v)) {
                inline Self => v.val,
                inline else => std.math.comptimeMod(v, m),
            };
            var y: T = self.val -% x;
            if (y >= m) {
                y +%= m;
            }
            return Self{
                .val = y,
            };
        }

        pub inline fn mul(self: Self, v: anytype) Self {
            const x: T = switch (@TypeOf(v)) {
                inline Self => v.val,
                inline else => std.math.comptimeMod(v, m),
            };
            return Self{
                .val = std.math.comptimeMod(std.math.mulWide(T, self.val, x), m),
            };
        }

        pub inline fn div(self: Self, v: anytype) Self {
            const x: T = switch (@TypeOf(v)) {
                inline Self => v.inv().val,
                inline else => Self.init(v).inv().val,
            };
            return self.mul(x);
        }

        pub inline fn addAsg(self: *Self, v: anytype) void {
            self.val = self.add(v).val;
        }

        pub inline fn subAsg(self: *Self, v: anytype) void {
            self.val = self.sub(v).val;
        }

        pub inline fn mulAsg(self: *Self, v: anytype) void {
            self.val = self.mul(v).val;
        }

        pub inline fn divAsg(self: *Self, v: anytype) void {
            self.val = self.div(v).val;
        }

        pub inline fn negate(self: Self) Self {
            return Self.raw(0).sub(self.val);
        }

        pub inline fn pow(self: Self, n: anytype) Self {
            @setEvalBranchQuota(100000);
            std.debug.assert(0 <= n);
            var x: Self = self;
            var r: Self = Self.raw(1);
            var _n: std.math.IntFittingRange(0, n) = n;
            while (_n > 0) : (_n >>= 1) {
                if (_n & 1 == 1) {
                    r = r.mul(x);
                }
                x = x.mul(x);
            }
            return r;
        }

        pub inline fn inv(self: Self) Self {
            if (comptime prime) {
                return self.pow(m - 2);
            } else {
                const g, const x = internal.invGcd(self.v, m);
                std.debug.assert(g == 1);
                return x;
            }
        }
    };
}

pub const DynamicModint = struct {
    const Self = @This();

    v: u32,
    m: u32,
    bt: internal.Barrett,

    pub inline fn mod(self: Self) u32 {
        return self.m;
    }
    pub inline fn raw(v: anytype) Self {
        return Self{ .v = @intCast(v) };
    }
    pub inline fn val(self: Self) u32 {
        return self.v;
    }
    pub inline fn as(self: Self, Type: type) Type {
        return @intCast(self.v);
    }
    pub inline fn init(v: anytype) Self {
        _ = v; // autofix
    }
    pub fn setMod(v: anytype) void {
        _ = v; // autofix
    }
};

pub const Modint998244353 = StaticModint(998244353);
pub const Modint1000000007 = StaticModint(1000000007);

const testing = std.testing;
const expectEqual = testing.expectEqual;
test StaticModint {
    // init
    try expectEqual(Modint1000000007.init(0).val, 0);
    try expectEqual(Modint1000000007.init(1).val, 1);
    try expectEqual(Modint1000000007.init(1_000_000_008).val, 1);
    try expectEqual(Modint1000000007.init(-1).val, 1_000_000_006);

    // add
    try expectEqual(Modint1000000007.init(1).add(1).val, 2);
    try expectEqual(Modint1000000007.init(1).add(2).add(3).val, 6);
    try expectEqual(Modint1000000007.init(1_000_000_006).add(2).val, 1);

    // sub
    try expectEqual(Modint1000000007.init(2).sub(1).val, 1);
    try expectEqual(Modint1000000007.init(3).sub(2).sub(1).val, 0);
    try expectEqual(Modint1000000007.init(0).sub(1).val, 1_000_000_006);

    // mul
    try expectEqual(Modint1000000007.init(1).mul(1).val, 1);
    try expectEqual(Modint1000000007.init(2).mul(2).val, 4);
    try expectEqual(Modint1000000007.init(1).mul(2).mul(3).val, 6);
    try expectEqual(Modint1000000007.init(100_000).mul(100_000).val, 999_999_937);

    // div
    try expectEqual(Modint1000000007.init(0).div(1).val, 0);
    try expectEqual(Modint1000000007.init(1).div(1).val, 1);
    try expectEqual(Modint1000000007.init(2).div(2).val, 1);
    try expectEqual(Modint1000000007.init(6).div(2).div(3).val, 1);
    try expectEqual(Modint1000000007.init(1).div(42).val, 23_809_524);

    // sum

    // product

    const f = Modint1000000007.init;
    const a = 10_293_812;
    const b = 9_083_240_982;

    // binop_coercion
    try expectEqual(f(a).add(b), f(a).add(f(b)));
    try expectEqual(f(a).sub(b), f(a).sub(f(b)));
    try expectEqual(f(a).mul(b), f(a).mul(f(b)));
    try expectEqual(f(a).div(b), f(a).div(f(b)));

    // assign_coercion
    const expected = f(a).add(b).mul(b).sub(b).div(b).val;
    var c = f(a);
    c.addAsg(b);
    c.mulAsg(b);
    c.subAsg(b);
    c.divAsg(b);
    try expectEqual(expected, c.val);
}
