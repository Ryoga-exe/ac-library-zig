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

    const n, const q = try io.input(struct { usize, usize });

    var dsu = try ac.Dsu.init(allocator, n);
    defer dsu.deinit();
    for (0..q) |_| {
        const t, const u, const v = try io.input(struct { u1, usize, usize });

        if (t == 0) {
            _ = dsu.merge(u, v);
        } else {
            try stdout.print("{}\n", .{@intFromBool(dsu.same(u, v))});
        }
    }

    try stdout.flush();
}
