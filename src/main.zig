const std = @import("std");
const fs = std.fs;
const path_mod = @import("path.zig");
const completion = @import("completion.zig");

const version = "0.1.0";

const Args = struct {
    old: ?[]const u8 = null,
    new: ?[]const u8 = null,
    path: ?[]const u8 = null,
    dry_run: bool = false,
    complete: ?u8 = null, // 1 or 2
    help: bool = false,
    show_version: bool = false,
};

fn parseArgs(args: []const []const u8) Args {
    var result = Args{};
    var i: usize = 1; // Skip program name

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            result.help = true;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            result.show_version = true;
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            result.dry_run = true;
        } else if (std.mem.eql(u8, arg, "--path")) {
            i += 1;
            if (i < args.len) result.path = args[i];
        } else if (std.mem.eql(u8, arg, "--complete")) {
            i += 1;
            if (i < args.len) {
                result.complete = std.fmt.parseInt(u8, args[i], 10) catch null;
            }
        } else if (arg[0] != '-') {
            if (result.old == null) {
                result.old = arg;
            } else if (result.new == null) {
                result.new = arg;
            }
        }
    }

    return result;
}

fn printHelp(writer: anytype) !void {
    try writer.writeAll(
        \\swapdir - swap directory path components
        \\
        \\USAGE:
        \\    swapdir <old> <new>
        \\    swapdir [OPTIONS] <old> <new>
        \\
        \\ARGS:
        \\    <old>    Substring to find in current path
        \\    <new>    Replacement substring
        \\
        \\OPTIONS:
        \\    -h, --help           Show this help
        \\    -v, --version        Show version
        \\    --path <PATH>        Use PATH instead of current directory
        \\    --dry-run            Show result without validating path exists
        \\    --complete <N>       Generate completions (N=1 or 2)
        \\
        \\EXAMPLES:
        \\    swapdir frontend backend    # /a/frontend/b -> /a/backend/b
        \\    swapdir src test            # /proj/src/foo -> /proj/test/foo
        \\
        \\EXIT CODES:
        \\    0  Success
        \\    1  No match found
        \\    2  No valid path exists
        \\    3  Invalid arguments
        \\    4  Multiple valid paths (selection needed)
        \\
    );
}

fn getCwd(allocator: std.mem.Allocator) ![]const u8 {
    var buf: [fs.max_path_bytes]u8 = undefined;
    const cwd = try fs.cwd().realpath(".", &buf);
    return allocator.dupe(u8, cwd);
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const parsed = parseArgs(args);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_buf: [4096]u8 = undefined;
    var stderr_writer = fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    if (parsed.help) {
        try printHelp(stdout);
        return 0;
    }

    if (parsed.show_version) {
        try stdout.print("swapdir {s}\n", .{version});
        return 0;
    }

    // Get current path
    const current_path = if (parsed.path) |p|
        try allocator.dupe(u8, p)
    else
        try getCwd(allocator);


    // Handle completion mode
    if (parsed.complete) |n| {
        if (n == 1) {
            const components = try completion.getPathComponents(allocator, current_path);

            for (components) |c| {
                try stdout.print("{s}\n", .{c});
            }
            return 0;
        } else if (n == 2) {
            const first_arg = parsed.old orelse {
                try stderr.print("Error: --complete 2 requires first argument\n", .{});
                return 3;
            };
            const siblings = try completion.getSiblingCompletions(allocator, current_path, first_arg);

            for (siblings) |s| {
                try stdout.print("{s}\n", .{s});
            }
            return 0;
        } else {
            try stderr.print("Error: --complete requires 1 or 2\n", .{});
            return 3;
        }
    }

    // Normal swap mode
    const old = parsed.old orelse {
        try stderr.print("Error: missing <old> argument\n", .{});
        try printHelp(stderr);
        return 3;
    };

    const new = parsed.new orelse {
        try stderr.print("Error: missing <new> argument\n", .{});
        try printHelp(stderr);
        return 3;
    };

    const result = path_mod.swapPath(allocator, current_path, old, new, .{
        .dry_run = parsed.dry_run,
    }) catch |err| {
        switch (err) {
            error.NoMatchFound => {
                try stderr.print("Error: \"{s}\" not found in path {s}\n", .{ old, current_path });
                return 1;
            },
            error.NoValidPath => {
                try stderr.print("Error: No valid path after replacing \"{s}\" with \"{s}\"\n", .{ old, new });
                return 2;
            },
            error.EmptySubstring => {
                try stderr.print("Error: <old> cannot be empty\n", .{});
                return 3;
            },
            error.OutOfMemory => {
                try stderr.print("Error: out of memory\n", .{});
                return 5;
            },
        }
    };


    switch (result) {
        .single => |new_path| {
            try stdout.print("{s}\n", .{new_path});
            return 0;
        },
        .multiple => |paths| {
            try stdout.print("MULTIPLE\n", .{});
            for (paths) |p| {
                try stdout.print("{s}\n", .{p});
            }
            return 4;
        },
    }
}

// Tests

test "parseArgs basic" {
    const args = [_][]const u8{ "swapdir", "old", "new" };
    const parsed = parseArgs(&args);

    try std.testing.expectEqualStrings("old", parsed.old.?);
    try std.testing.expectEqualStrings("new", parsed.new.?);
    try std.testing.expect(!parsed.dry_run);
}

test "parseArgs with options" {
    const args = [_][]const u8{ "swapdir", "--dry-run", "--path", "/some/path", "old", "new" };
    const parsed = parseArgs(&args);

    try std.testing.expectEqualStrings("old", parsed.old.?);
    try std.testing.expectEqualStrings("new", parsed.new.?);
    try std.testing.expect(parsed.dry_run);
    try std.testing.expectEqualStrings("/some/path", parsed.path.?);
}

test "parseArgs help" {
    const args = [_][]const u8{ "swapdir", "--help" };
    const parsed = parseArgs(&args);

    try std.testing.expect(parsed.help);
}

test "parseArgs complete" {
    const args = [_][]const u8{ "swapdir", "--complete", "1" };
    const parsed = parseArgs(&args);

    try std.testing.expectEqual(@as(u8, 1), parsed.complete.?);
}
