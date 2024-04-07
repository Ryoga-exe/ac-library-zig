const std = @import("std");
pub const Dsu = @import("dsu.zig").Dsu;
pub const FenwickTree = @import("fenwicktree.zig").FenwickTree;
pub const FenwickTreeI64 = @import("fenwicktree.zig").FenwickTreeI64;
pub const FenwickTreeI32 = @import("fenwicktree.zig").FenwickTreeI32;

comptime {
    std.testing.refAllDecls(@This());
}
