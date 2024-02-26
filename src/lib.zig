const std = @import("std");
pub const Dsu = @import("dsu.zig").Dsu;

comptime {
    std.testing.refAllDecls(@This());
}
