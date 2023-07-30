const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("microbe", .{
        .source_file = .{ .path = "src/microbe.zig" },
    });
    _ = b.addModule("chip_util", .{
        .source_file = .{ .path = "src/chip_util.zig" },
    });
}
