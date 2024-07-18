const std = @import("std");

pub fn StaticModint(comptime m: comptime_int) type {
    if (m < 1) {
        @compileError("m must be greater than or equal to 1");
    }

    const T = std.math.IntFittingRange(0, m - 1);
    const U = std.math.IntFittingRange(0, (m - 1) * (m - 1));

    return struct {
        const Self = @This();

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
            if (y > m) {
                y -%= m;
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
    };
}

const DynamicModint = struct {};

test StaticModint {
    var s = StaticModint(12).init(0);
    std.debug.print("{}\n", .{s.v});
    s = s.add(1).add(1);
    s = s.add(s).mul(2);
    s = s.add(s).sub(10);
    std.debug.print("{}\n", .{s.v});
}
