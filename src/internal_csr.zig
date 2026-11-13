const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn Csr(comptime E: type) type {
    return struct {
        const Self = @This();

        start: []usize,
        elist: []E,
        allocator: Allocator,

        pub fn init(allocator: Allocator, n: usize, edges: []struct { usize, E }, initialValue: E) !Self {
            const start = try allocator.alloc(usize, n + 1);
            errdefer allocator.free(start);
            const elist = try allocator.alloc(E, edges.len);
            errdefer allocator.free(elist);
            const self = Self{
                .start = start,
                .elist = elist,
                .allocator = allocator,
            };

            @memset(self.start, 0);
            @memset(self.elist, initialValue);
            for (edges) |e| {
                self.start[e.@"0" + 1] += 1;
            }
            for (1..n + 1) |i| {
                self.start[i] += self.start[i - 1];
            }
            var counter = try allocator.alloc(usize, n + 1);
            defer allocator.free(counter);
            @memcpy(counter, self.start);
            for (edges) |e| {
                self.elist[counter[e.@"0"]] = e.@"1";
                counter[e.@"0"] += 1;
            }
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.start);
            self.allocator.free(self.elist);
        }
    };
}

test Csr {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn check(allocator: Allocator) !void {
            var edges = [_]struct { usize, usize }{ .{ 0, 1 }, .{ 1, 0 } };
            var graph = try Csr(usize).init(allocator, 2, &edges, 0);
            defer graph.deinit();
        }
    }.check, .{});
}
