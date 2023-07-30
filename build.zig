const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("microbe", .{
        .source_file = .{ .path = "src/microbe.zig" },
    });
}
