const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;
const path_mod = @import("path.zig");

/// Split a path into its components.
/// Used for first argument completion.
/// Caller must free each component and the slice.
pub fn getPathComponents(allocator: Allocator, path: []const u8) ![][]const u8 {
    var components: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer {
        for (components.items) |c| allocator.free(c);
        components.deinit(allocator);
    }

    var iter = mem.splitScalar(u8, path, '/');
    while (iter.next()) |component| {
        if (component.len > 0) {
            const copy = try allocator.dupe(u8, component);
            try components.append(allocator, copy);
        }
    }

    return try components.toOwnedSlice(allocator);
}

/// Find the position and component that contains the given substring
fn findMatchingComponent(path: []const u8, needle: []const u8) ?struct { start: usize, end: usize } {
    var iter = mem.splitScalar(u8, path, '/');

    while (iter.next()) |component| {
        if (component.len > 0) {
            const component_start = @intFromPtr(component.ptr) - @intFromPtr(path.ptr);
            if (mem.indexOf(u8, component, needle)) |_| {
                return .{
                    .start = component_start,
                    .end = component_start + component.len,
                };
            }
        }
    }
    return null;
}

/// Generate completions for the second argument.
/// Finds siblings of the matched component that would result in valid paths.
/// Caller must free each completion and the slice.
pub fn getSiblingCompletions(
    allocator: Allocator,
    current_path: []const u8,
    first_arg: []const u8,
) ![][]const u8 {
    var completions: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer {
        for (completions.items) |c| allocator.free(c);
        completions.deinit(allocator);
    }

    const match = findMatchingComponent(current_path, first_arg) orelse return try completions.toOwnedSlice(allocator);

    // Parent directory (everything before the matched component)
    var parent_end = match.start;
    if (parent_end > 0 and current_path[parent_end - 1] == '/') {
        parent_end -= 1;
    }
    const parent_path = if (parent_end == 0) "/" else current_path[0..parent_end];

    // Suffix (everything after the matched component)
    const suffix = current_path[match.end..];

    var dir = fs.openDirAbsolute(parent_path, .{ .iterate = true }) catch return try completions.toOwnedSlice(allocator);
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .directory) continue;

        // Skip the current component
        const matched_component = current_path[match.start..match.end];
        if (mem.eql(u8, entry.name, matched_component)) continue;

        // Check if sibling + suffix exists
        const candidate_len = parent_path.len + 1 + entry.name.len + suffix.len;
        const candidate = allocator.alloc(u8, candidate_len) catch continue;
        defer allocator.free(candidate);

        var pos: usize = 0;
        @memcpy(candidate[pos..][0..parent_path.len], parent_path);
        pos += parent_path.len;
        candidate[pos] = '/';
        pos += 1;
        @memcpy(candidate[pos..][0..entry.name.len], entry.name);
        pos += entry.name.len;
        @memcpy(candidate[pos..][0..suffix.len], suffix);

        if (path_mod.pathExists(candidate)) {
            const name_copy = allocator.dupe(u8, entry.name) catch continue;
            completions.append(allocator, name_copy) catch {
                allocator.free(name_copy);
                continue;
            };
        }
    }

    return try completions.toOwnedSlice(allocator);
}

// Tests

test "getPathComponents splits correctly" {
    const allocator = std.testing.allocator;
    const components = try getPathComponents(allocator, "/home/user/projects/frontend/src");
    defer {
        for (components) |c| allocator.free(c);
        allocator.free(components);
    }

    try std.testing.expectEqual(@as(usize, 5), components.len);
    try std.testing.expectEqualStrings("home", components[0]);
    try std.testing.expectEqualStrings("user", components[1]);
    try std.testing.expectEqualStrings("projects", components[2]);
    try std.testing.expectEqualStrings("frontend", components[3]);
    try std.testing.expectEqualStrings("src", components[4]);
}

test "getPathComponents handles root" {
    const allocator = std.testing.allocator;
    const components = try getPathComponents(allocator, "/");
    defer allocator.free(components);

    try std.testing.expectEqual(@as(usize, 0), components.len);
}

test "getPathComponents handles trailing slash" {
    const allocator = std.testing.allocator;
    const components = try getPathComponents(allocator, "/home/user/");
    defer {
        for (components) |c| allocator.free(c);
        allocator.free(components);
    }

    try std.testing.expectEqual(@as(usize, 2), components.len);
    try std.testing.expectEqualStrings("home", components[0]);
    try std.testing.expectEqualStrings("user", components[1]);
}

test "findMatchingComponent finds component with substring" {
    const result = findMatchingComponent("/home/user/frontend/src", "front");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 11), result.?.start);
    try std.testing.expectEqual(@as(usize, 19), result.?.end);
}

test "findMatchingComponent returns null for no match" {
    const result = findMatchingComponent("/home/user/backend/src", "front");
    try std.testing.expect(result == null);
}
