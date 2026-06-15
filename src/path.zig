const std = @import("std");
const fs = std.fs;
const Io = std.Io;
const mem = std.mem;
const Allocator = mem.Allocator;

pub const SwapError = error{
    NoMatchFound,
    NoValidPath,
    EmptySubstring,
    OutOfMemory,
};

pub const SwapResult = union(enum) {
    /// Single valid path found
    single: []const u8,
    /// Multiple valid paths - user must choose
    multiple: []const []const u8,
};

/// Find all positions where `needle` appears in `haystack`
pub fn findAllPositions(allocator: Allocator, haystack: []const u8, needle: []const u8) ![]usize {
    if (needle.len == 0) return &[_]usize{};
    if (needle.len > haystack.len) return &[_]usize{};

    var positions: std.ArrayList(usize) = .empty;
    errdefer positions.deinit(allocator);

    var i: usize = 0;
    while (i <= haystack.len - needle.len) {
        if (mem.eql(u8, haystack[i..][0..needle.len], needle)) {
            try positions.append(allocator, i);
            i += 1; // Allow overlapping matches
        } else {
            i += 1;
        }
    }

    return try positions.toOwnedSlice(allocator);
}

/// Replace substring at a specific position
pub fn replaceAt(allocator: Allocator, path: []const u8, pos: usize, old_len: usize, new: []const u8) ![]const u8 {
    const new_len = path.len - old_len + new.len;
    const result = try allocator.alloc(u8, new_len);
    errdefer allocator.free(result);

    // Copy prefix
    @memcpy(result[0..pos], path[0..pos]);
    // Copy replacement
    @memcpy(result[pos..][0..new.len], new);
    // Copy suffix
    @memcpy(result[pos + new.len ..], path[pos + old_len ..]);

    return result;
}

/// Check if a path exists on the filesystem
pub fn pathExists(io: Io, path: []const u8) bool {
    Io.Dir.accessAbsolute(io, path, .{}) catch return false;
    return true;
}

/// Swap occurrences of `old` with `new` in `path`.
/// Returns the valid path(s) that exist on the filesystem.
pub fn swapPath(
    allocator: Allocator,
    io: Io,
    path: []const u8,
    old: []const u8,
    new: []const u8,
    options: SwapOptions,
) SwapError!SwapResult {
    if (old.len == 0) return SwapError.EmptySubstring;

    // Find all positions where old appears
    const positions = findAllPositions(allocator, path, old) catch return SwapError.OutOfMemory;
    defer allocator.free(positions);

    if (positions.len == 0) return SwapError.NoMatchFound;

    // Generate candidate paths for each position
    var valid_paths: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (valid_paths.items) |p| allocator.free(p);
        valid_paths.deinit(allocator);
    }

    for (positions) |pos| {
        const candidate = replaceAt(allocator, path, pos, old.len, new) catch continue;

        if (options.dry_run or pathExists(io, candidate)) {
            valid_paths.append(allocator, candidate) catch {
                allocator.free(candidate);
                continue;
            };
        } else {
            allocator.free(candidate);
        }
    }

    if (valid_paths.items.len == 0) {
        return SwapError.NoValidPath;
    } else if (valid_paths.items.len == 1) {
        const result = valid_paths.items[0];
        valid_paths.deinit(allocator);
        return SwapResult{ .single = result };
    } else {
        const items = valid_paths.toOwnedSlice(allocator) catch return SwapError.OutOfMemory;
        return SwapResult{ .multiple = items };
    }
}

pub const SwapOptions = struct {
    /// Don't validate if result path exists
    dry_run: bool = false,
};

/// Free a SwapResult
pub fn freeResult(allocator: Allocator, result: SwapResult) void {
    switch (result) {
        .single => |path| allocator.free(path),
        .multiple => |paths| {
            for (paths) |p| allocator.free(p);
            allocator.free(paths);
        },
    }
}

// ////========================================
// ///   Tests
// //==========================================

test "findAllPositions finds single occurrence" {
    const allocator = std.testing.allocator;
    const positions = try findAllPositions(allocator, "/home/user/frontend/src", "frontend");
    defer allocator.free(positions);

    try std.testing.expectEqual(@as(usize, 1), positions.len);
    try std.testing.expectEqual(@as(usize, 11), positions[0]);
}

test "findAllPositions finds multiple occurrences" {
    const allocator = std.testing.allocator;
    const positions = try findAllPositions(allocator, "/home/src/project/src", "src");
    defer allocator.free(positions);

    try std.testing.expectEqual(@as(usize, 2), positions.len);
    try std.testing.expectEqual(@as(usize, 6), positions[0]);
    try std.testing.expectEqual(@as(usize, 18), positions[1]);
}

test "findAllPositions returns empty for no match" {
    const allocator = std.testing.allocator;
    const positions = try findAllPositions(allocator, "/home/user/project", "frontend");
    defer allocator.free(positions);

    try std.testing.expectEqual(@as(usize, 0), positions.len);
}

test "findAllPositions handles substring match" {
    const allocator = std.testing.allocator;
    const positions = try findAllPositions(allocator, "/home/user/frontend/src", "front");
    defer allocator.free(positions);

    try std.testing.expectEqual(@as(usize, 1), positions.len);
    try std.testing.expectEqual(@as(usize, 11), positions[0]);
}

test "replaceAt replaces correctly" {
    const allocator = std.testing.allocator;
    const result = try replaceAt(allocator, "/home/user/frontend/src", 11, 8, "backend");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("/home/user/backend/src", result);
}

test "replaceAt handles substring replacement" {
    const allocator = std.testing.allocator;
    const result = try replaceAt(allocator, "/home/user/frontend/src", 11, 5, "back");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("/home/user/backend/src", result);
}

test "swapPath returns NoMatchFound when old not in path" {
    const allocator = std.testing.allocator;
    const result = swapPath(allocator, std.testing.io, "/home/user/project", "frontend", "backend", .{ .dry_run = true });
    try std.testing.expectError(SwapError.NoMatchFound, result);
}

test "swapPath returns EmptySubstring for empty old" {
    const allocator = std.testing.allocator;
    const result = swapPath(allocator, std.testing.io, "/home/user/project", "", "backend", .{ .dry_run = true });
    try std.testing.expectError(SwapError.EmptySubstring, result);
}

test "swapPath with dry_run returns path without validation" {
    const allocator = std.testing.allocator;
    const result = try swapPath(allocator, std.testing.io, "/home/user/frontend/src", "frontend", "backend", .{ .dry_run = true });
    defer freeResult(allocator, result);

    switch (result) {
        .single => |path| try std.testing.expectEqualStrings("/home/user/backend/src", path),
        .multiple => try std.testing.expect(false),
    }
}

test "swapPath with substring match" {
    const allocator = std.testing.allocator;
    const result = try swapPath(allocator, std.testing.io, "/home/user/frontend/src", "front", "back", .{ .dry_run = true });
    defer freeResult(allocator, result);

    switch (result) {
        .single => |path| try std.testing.expectEqualStrings("/home/user/backend/src", path),
        .multiple => try std.testing.expect(false),
    }
}
