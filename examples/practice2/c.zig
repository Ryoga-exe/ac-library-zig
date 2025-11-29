const std = @import("std");
const ac = @import("ac-library");
const proconio = @import("proconio");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;
    var io = try proconio.init(allocator);
    defer io.deinit();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const t = try io.input(usize);

    for (0..t) |_| {
        const i = try io.input(struct {
            n: i64,
            m: i64,
            a: i64,
            b: i64,
        });
        try stdout.print("{d}\n", .{ac.floorSum(i.n, i.m, i.a, i.b)});
    }

    try stdout.flush();
}
