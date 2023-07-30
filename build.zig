const std = @import("std");

pub fn build(b: *std.Build) void {
    b.addModule("microbe", .{
        .source_file = .{ .path = "src/microbe.zig" },
    });
}
