const std = @import("std");
const internal = @import("internal_math.zig");
const assert = std.debug.assert;

/// Modular integer with a **compile-time** modulus `m`.
///
/// # Constraints
///
/// - `m >= 1` (otherwise a compile error)
pub fn StaticModint(comptime m: comptime_int) type {
    if (m < 1) {
        @compileError("m must be greater than or equal to 1");
    }

    // The smallest unsigned integer type that fits `[0, m-1]`.
    const T = comptime std.math.IntFittingRange(0, m - 1);

    return struct {
        const Self = @This();
        /// `true` if `m` is prime (evaluated at comptime).
        const prime = internal.comptimeIsPrime(m);

        /// Stored canonical representative in `[0, m-1]`.
        val: T,

        /// Returns the modulus (`m`).
        pub fn mod(_: Self) comptime_int {
            return m;
        }

        /// Constructs `StaticModint` from a `v < m` without taking mod.
        /// It is the function for constant-factor speedup.
        ///
        /// # Constraints
        ///
        /// - `v` is less than `m`
        ///
        pub fn raw(v: anytype) Self {
            return Self{ .val = @intCast(v) };
        }

        /// Returns the representative with casting to another integer `Type`.
        pub fn as(self: Self, Type: type) Type {
            return @intCast(self.val);
        }

        /// Constructs a value reduced modulo `m`.
        /// Works for both signed and unsigned integers.
        pub fn init(v: anytype) Self {
            return Self{ .val = std.math.comptimeMod(v, m) };
        }

        /// Monoid sum over a slice, reduced mod `m`.
        /// Returns `Σ v[i] (mod m)`.
        pub fn sum(Type: type, v: []const Type) Self {
            var x = Self.init(0);
            for (v) |e| {
                x.addAsg(e);
            }
            return x;
        }

        /// Monoid product over a slice, reduced mod `m`.
        /// Returns `∏ v[i] (mod m)`.
        pub fn product(Type: type, v: []const Type) Self {
            var x = Self.init(1);
            for (v) |e| {
                x.mulAsg(e);
            }
            return x;
        }

        /// Returns `self + v (mod m)`.
        pub inline fn add(self: Self, v: anytype) Self {
            const x: T = switch (@TypeOf(v)) {
                inline Self => v.val,
                inline else => std.math.comptimeMod(v, m),
            };
            return Self{
                .val = std.math.comptimeMod(self.val + x, m),
            };
        }

        /// Returns `self - v (mod m)`.
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

        /// Returns `self * v (mod m)`.
        pub inline fn mul(self: Self, v: anytype) Self {
            const x: T = switch (@TypeOf(v)) {
                inline Self => v.val,
                inline else => std.math.comptimeMod(v, m),
            };
            return Self{
                .val = std.math.comptimeMod(std.math.mulWide(T, self.val, x), m),
            };
        }

        /// Returns `self / v (mod m)` (i.e., `self * inv(v)`).
        ///
        /// # Panics
        ///
        /// Panics in debug if `v` is not invertible when `m` is composite.
        pub inline fn div(self: Self, v: anytype) Self {
            const x: T = switch (@TypeOf(v)) {
                inline Self => v.inv().val,
                inline else => Self.init(v).inv().val,
            };
            return self.mul(x);
        }

        /// In-place `+= v (mod m)`.
        pub inline fn addAsg(self: *Self, v: anytype) void {
            self.val = self.add(v).val;
        }

        /// In-place `-= v (mod m)`.
        pub inline fn subAsg(self: *Self, v: anytype) void {
            self.val = self.sub(v).val;
        }

        /// In-place `*= v (mod m)`.
        pub inline fn mulAsg(self: *Self, v: anytype) void {
            self.val = self.mul(v).val;
        }

        /// In-place `/= v (mod m)`.
        pub inline fn divAsg(self: *Self, v: anytype) void {
            self.val = self.div(v).val;
        }

        /// Returns `-self (mod m)`.
        pub inline fn negate(self: Self) Self {
            return Self.raw(0).sub(self.val);
        }

        /// Returns `self` to the power of `n`.
        pub inline fn pow(self: Self, n: anytype) Self {
            @setEvalBranchQuota(100000);
            assert(0 <= n);
            var x = self;
            var r = Self.init(1);
            var _n: std.math.IntFittingRange(0, n) = n;
            while (_n > 0) : (_n >>= 1) {
                if (_n & 1 == 1) {
                    r = r.mul(x);
                }
                x = x.mul(x);
            }
            return r;
        }

        /// Retruns the multiplicative inverse of `self`.
        ///
        /// # Panics
        ///
        /// Panics if the multiplicative inverse does not exist.
        pub inline fn inv(self: Self) Self {
            if (comptime prime) {
                return self.pow(m - 2);
            } else {
                const g, const x = internal.invGcd(self.val, m);
                assert(g == 1);
                return Self{
                    .val = @intCast(x),
                };
            }
        }
    };
}

/// Modint for `mod = 998244353`.
pub const Modint998244353 = StaticModint(998244353);
/// Modint for `mod = 1000000007`.
pub const Modint1000000007 = StaticModint(1000000007);

/// Modular integer with a **runtime**-set modulus.
///
/// The modulus is shared across all values of the *same instantiation*
/// `DynamicModint(id)`. Use different `id`s to keep separate global moduli.
pub fn DynamicModint(id: comptime_int) type {
    return struct {
        const Self = @This();
        const _id = id; // disambiguates the type

        /// Shared Barrett reducer for this type instantiation.
        var bt = internal.Barrett.init(998244353);

        /// Stored canonical representative in `[0, mod()-1]`.
        val: u32,

        /// Returns the modulus.
        pub fn mod() u32 {
            return bt.umod();
        }

        /// Sets the modulus for this type.
        /// It must be called first.
        ///
        /// # Panics
        ///
        /// Panics if `m == 0`.
        pub fn setMod(m: u32) void {
            if (m == 0) {
                @panic("the modulus must not be 0");
            }
            Self.bt = internal.Barrett.init(m);
        }

        /// Constructs `DynamicModint` from a `v < m` without taking mod.
        /// It is the function for constant-factor speedup.
        ///
        /// # Constraints
        ///
        /// - `v` is less than `m`
        ///
        pub fn raw(v: anytype) Self {
            return Self{
                .val = @intCast(v),
            };
        }

        /// Returns the representative with casting to another integer `Type`.
        pub fn as(self: Self, Type: type) Type {
            return @intCast(self.val);
        }

        /// Constructs a value reduced modulo `m`.
        /// Works for both signed and unsigned integers.
        pub fn init(v: anytype) Self {
            return Self{
                .val = takeMod(v),
            };
        }

        /// Monoid sum over a slice, reduced mod `m`.
        /// Returns `Σ v[i] (mod m)`.
        pub fn sum(Type: type, v: []const Type) Self {
            var x = Self.init(0);
            for (v) |e| {
                x.addAsg(e);
            }
            return x;
        }

        /// Monoid product over a slice, reduced mod `m`.
        /// Returns `∏ v[i] (mod m)`.
        pub fn product(Type: type, v: []const Type) Self {
            var x = Self.init(1);
            for (v) |e| {
                x.mulAsg(e);
            }
            return x;
        }

        /// `self + v (mod mod())`.
        pub inline fn add(self: Self, v: anytype) Self {
            const x = self.val + switch (@TypeOf(v)) {
                inline Self => v.val,
                inline else => takeMod(v),
            };
            return Self{
                .val = if (x >= mod()) x - mod() else x,
            };
        }

        /// `self - v (mod mod())`.
        pub inline fn sub(self: Self, v: anytype) Self {
            const x = self.val -% switch (@TypeOf(v)) {
                inline Self => v.val,
                inline else => takeMod(v),
            };
            return Self{
                .val = if (x >= mod()) x - mod() else x,
            };
        }

        /// `self * v (mod mod())` using Barrett reduction.
        pub inline fn mul(self: Self, v: anytype) Self {
            const x = bt.mul(self.val, switch (@TypeOf(v)) {
                inline Self => v.val,
                inline else => takeMod(v),
            });
            return Self{
                .val = x,
            };
        }

        /// `self / v (mod mod())` (i.e., `self * inv(v)`).
        ///
        /// # Panics
        ///
        /// Panics in debug if `v` is not invertible when `m` is composite.
        pub inline fn div(self: Self, v: anytype) Self {
            const x = switch (@TypeOf(v)) {
                inline Self => v.inv().val,
                inline else => Self.init(v).inv().val,
            };
            return self.mul(x);
        }

        /// In-place `+= v`.
        pub inline fn addAsg(self: *Self, v: anytype) void {
            self.val = self.add(v).val;
        }

        /// In-place `-= v`.
        pub inline fn subAsg(self: *Self, v: anytype) void {
            self.val = self.sub(v).val;
        }

        /// In-place `*= v`.
        pub inline fn mulAsg(self: *Self, v: anytype) void {
            self.val = self.mul(v).val;
        }

        /// In-place `/= v`.
        pub inline fn divAsg(self: *Self, v: anytype) void {
            self.val = self.div(v).val;
        }

        /// `-self (mod mod())`.
        pub inline fn negate(self: Self) Self {
            return Self.raw(0).sub(self.val);
        }

        /// Returns `self` to the power of `n`.
        pub inline fn pow(self: Self, n: anytype) Self {
            assert(0 <= n);
            var x = self;
            var r = Self.init(1);
            var _n: std.math.IntFittingRange(0, n) = n;
            while (_n > 0) : (_n >>= 1) {
                if (_n & 1 == 1) {
                    r = r.mul(x);
                }
                x = x.mul(x);
            }
            return r;
        }

        /// Retruns the multiplicative inverse of `self`.
        ///
        /// # Panics
        ///
        /// Panics if the multiplicative inverse does not exist.
        pub inline fn inv(self: Self) Self {
            const g, const x = internal.invGcd(self.val, mod());
            assert(g == 1);
            return Self{
                .val = @intCast(x),
            };
        }

        /// Reduce `v` modulo current `mod()` to a canonical `u32` in `[0, mod()-1]`.
        fn takeMod(v: anytype) u32 {
            const m: i64 = @intCast(bt.umod());
            return @intCast(@mod(v, m));
        }
    };
}

/// Alias handy for dynamic-mod situations where the `id` value is irrelevant.
/// You will usually want your own `id` to keep moduli separate across modules.
pub const Modint = DynamicModint(-1);

const testing = std.testing;
const expectEqual = testing.expectEqual;
test StaticModint {
    const init = Modint1000000007.init;
    const sum = Modint1000000007.sum;
    const product = Modint1000000007.product;

    // init
    try expectEqual(init(0).val, 0);
    try expectEqual(init(1).val, 1);
    try expectEqual(init(1_000_000_008).val, 1);
    try expectEqual(init(-1).val, 1_000_000_006);

    // add
    try expectEqual(init(1).add(1).val, 2);
    try expectEqual(init(1).add(2).add(3).val, 6);
    try expectEqual(init(1_000_000_006).add(2).val, 1);

    // sub
    try expectEqual(init(2).sub(1).val, 1);
    try expectEqual(init(3).sub(2).sub(1).val, 0);
    try expectEqual(init(0).sub(1).val, 1_000_000_006);

    // mul
    try expectEqual(init(1).mul(1).val, 1);
    try expectEqual(init(2).mul(2).val, 4);
    try expectEqual(init(1).mul(2).mul(3).val, 6);
    try expectEqual(init(100_000).mul(100_000).val, 999_999_937);

    // div
    try expectEqual(init(0).div(1).val, 0);
    try expectEqual(init(1).div(1).val, 1);
    try expectEqual(init(2).div(2).val, 1);
    try expectEqual(init(6).div(2).div(3).val, 1);
    try expectEqual(init(1).div(42).val, 23_809_524);

    // sum
    try expectEqual(init(-3).val, sum(i32, &[_]i32{ -1, 2, -3, 4, -5 }).val);

    // product
    try expectEqual(init(-120).val, product(i32, &[_]i32{ -1, 2, -3, 4, -5 }).val);

    // binop_coercion
    const a = 10_293_812;
    const b = 9_083_240_982;

    try expectEqual(init(a).add(b), init(a).add(init(b)));
    try expectEqual(init(a).sub(b), init(a).sub(init(b)));
    try expectEqual(init(a).mul(b), init(a).mul(init(b)));
    try expectEqual(init(a).div(b), init(a).div(init(b)));

    // assign_coercion
    const expected = init(a).add(b).mul(b).sub(b).div(b).val;
    var c = init(a);
    c.addAsg(b);
    c.mulAsg(b);
    c.subAsg(b);
    c.divAsg(b);
    try expectEqual(expected, c.val);
}

test DynamicModint {
    const Mint1007 = DynamicModint(1007);
    Mint1007.setMod(1007);

    const init = Mint1007.init;
    const sum = Mint1007.sum;
    const product = Mint1007.product;

    // sum
    try expectEqual(init(-3).val, sum(i32, &[_]i32{ -1, 2, -3, 4, -5 }).val);

    // product
    try expectEqual(init(-120).val, product(i32, &[_]i32{ -1, 2, -3, 4, -5 }).val);

    // binop_coercion
    const a = 10_293_812;
    const b = 9_083_240_982;

    try expectEqual(init(a).add(b), init(a).add(init(b)));
    try expectEqual(init(a).sub(b), init(a).sub(init(b)));
    try expectEqual(init(a).mul(b), init(a).mul(init(b)));
    try expectEqual(init(a).div(b), init(a).div(init(b)));

    // assign_coercion
    const expected = init(a).add(b).mul(b).sub(b).div(b).val;
    var c = init(a);
    c.addAsg(b);
    c.mulAsg(b);
    c.subAsg(b);
    c.divAsg(b);
    try expectEqual(expected, c.val);

    // mod = 1 (corner case)
    const Mint1 = DynamicModint(1);
    Mint1.setMod(1);

    const x = Mint1.init(123).pow(0);
    try expectEqual(0, x.val);
}
