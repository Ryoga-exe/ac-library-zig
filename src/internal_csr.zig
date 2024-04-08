const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Csr(comptime E: type) type {
    return struct {
        const Self = @This();

        start: []usize,
        allocator: Allocator,

        pub fn init(allocator: Allocator, n: usize, edges: []const std.meta.Tuple(&.{ usize, E })) Self {
            const self = Self{
                .start = allocator.alloc(usize, n + 1),
                .allocator = allocator,
            };
            @memset(self.start, 0);
            for (edges) |e| {
                self.start[e.@"0" + 1] += 1;
            }
            for (1..n + 1) |i| {
                self.start[i] += self.start[i - 1];
            }
            // TODO: implement
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.start);
        }
    };
}
