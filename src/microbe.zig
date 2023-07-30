const std = @import("std");
const builtin = @import("builtin");
const config = @import("config");
const chip = @import("chip");
const root = @import("root");

const clocks = @import("clocks.zig");
pub const Tick = clocks.Tick;
pub const Microtick = clocks.Microtick;

pub const pads = @import("pads.zig");
pub const dma = @import("dma.zig");
pub const bus = @import("bus.zig");
pub const uart = @import("uart.zig");
pub const jtag = @import("jtag.zig");

pub fn defaultLog(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = message_level;
    _ = scope;
    _ = format;
    _ = args;
}

pub fn defaultPanic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("microbe PANIC: {s}", .{message});

    if (builtin.cpu.arch != .avr) {
        var index: usize = 0;
        var iter = std.debug.StackIterator.init(@returnAddress(), null);
        while (iter.next()) |address| : (index += 1) {
            if (index == 0) {
                std.log.err("stack trace:", .{});
            }
            std.log.err("{d: >3}: 0x{X:0>8}", .{ index, address });
        }
    }
    if (@import("builtin").mode == .Debug) {
        // attach a breakpoint, this might trigger another
        // panic internally, so only do that in debug mode.
        std.log.info("triggering breakpoint...", .{});
        @breakpoint();
    }
    hang();
}

/// Hangs the processor and will stop doing anything useful. Use with caution!
pub fn hang() noreturn {
    while (true) {
        // "this loop has side effects, don't optimize the endless loop away please. thanks!"
        asm volatile ("" ::: "memory");
    }
}

/// This is the logical entry point for microbe.
/// It will invoke the main function from the root source file and provide error return handling
/// align(4) shouldn't be necessary here, but sometimes zig ends up using align(2) on arm for some reason...
fn start() align(4) callconv(.C) noreturn {
    if (!@hasDecl(root, "main")) {
        @compileError("The root source file must provide a public function main!");
    }

    // There usually isn't any core- or chip-specific setup needed, but this prevents an issue
    // where the vector table isn't actually exported if nothing in the program uses anything
    // from `core`.
    if (@hasDecl(chip.core, "init")) {
        chip.core.init();
    }

    if (@hasDecl(chip, "init")) {
        chip.init();
    }

    config.initRam();

    if (@hasDecl(root, "init")) {
        root.init();
    }

    if (@hasDecl(root, "clocks")) {
        chip.clocks.init(root.clocks);
    }

    const main_fn = @field(root, "main");
    const info: std.builtin.Type = @typeInfo(@TypeOf(main_fn));

    if (info != .Fn or info.Fn.args.len > 0) {
        @compileError("main must be either 'pub fn main() void' or 'pub fn main() !void'.");
    }

    if (info.Fn.calling_convention == .Async) {
        @compileError("TODO: Event loop not supported.");
    }

    if (@typeInfo(info.Fn.return_type.?) == .ErrorUnion) {
        main_fn() catch |err| @panic(@errorName(err));
    } else {
        main_fn();
    }

    // TODO consider putting the core to sleep?

    hang();
}
