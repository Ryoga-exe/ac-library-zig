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

    var fw = try ac.FenwickTreeI64.init(allocator, n);
    defer fw.deinit();
    for (0..n) |i| {
        fw.add(i, try io.input(i64));
    }

    for (0..q) |_| {
        const t = try io.input(u1);
        if (t == 0) {
            const p, const x = try io.input(struct { usize, i64 });
            fw.add(p, x);
        } else {
            const l, const r = try io.input(struct { usize, usize });
            try stdout.print("{}\n", .{fw.sum(l, r)});
        }
    }

    try stdout.flush();
}
