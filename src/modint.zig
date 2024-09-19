const std = @import("std");
const internal = @import("internal_math.zig");

pub fn StaticModint(comptime m: comptime_int) type {
    if (m < 1) {
        @compileError("m must be greater than or equal to 1");
    }

    const T = comptime std.math.IntFittingRange(0, m - 1);
    const U = comptime std.math.IntFittingRange(0, (m - 1) * (m - 1));

    return struct {
        const Self = @This();
        const prime = internal.comptimeIsPrime(m);

        v: T,

        pub fn raw(v: anytype) Self {
            return Self{ .v = @intCast(v) };
        }

        pub fn init(v: anytype) Self {
            return Self{ .v = std.math.comptimeMod(v, m) };
        }

        pub fn mod(comptime self: Self) comptime_int {
            _ = self; // autofix
            return m;
        }

        pub fn add(self: Self, v: anytype) Self {
            const x: U = switch (@TypeOf(v)) {
                Self => v.v,
                else => std.math.comptimeMod(v, m),
            };
            return Self{
                .v = std.math.comptimeMod(self.v + x, m),
            };
        }

        pub fn sub(self: Self, v: anytype) Self {
            const x: T = switch (@TypeOf(v)) {
                Self => v.v,
                else => std.math.comptimeMod(v, m),
            };
            var y: T = self.v -% x;
            if (y >= m) {
                y +%= m;
            }
            return Self{
                .v = y,
            };
        }

        pub fn mul(self: Self, v: anytype) Self {
            const x: U = switch (@TypeOf(v)) {
                Self => v.v,
                else => std.math.comptimeMod(v, m),
            };
            return Self{
                .v = std.math.comptimeMod(self.v * x, m),
            };
        }

        pub fn pow(self: Self, n: anytype) Self {
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

        pub fn inv(self: Self) Self {
            if (prime) {
                return self.pow(m - 2);
            } else {
                const g, const x = internal.invGcd(self.v, m);
                std.debug.assert(g == 1);
                return x;
            }
        }
    };
}

const DynamicModint = struct {};

test StaticModint {
    var s = StaticModint(13).init(0);
    std.debug.print("{}\n", .{s.v});
    s = s.add(1).add(1);
    std.debug.print("{}\n", .{s.v});
    s = s.pow(5);
    s = s.inv();
    std.debug.print("{}\n", .{s.v});
}
