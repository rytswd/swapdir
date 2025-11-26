# Implementation Guide

## Development Environment

### Zig Configuration
- **Language**: Zig 0.16.0-dev (latest master via zig-overlay)
- **Build System**: `build.zig` (Zig's native build system)
- **Formatter**: `zig fmt` (enforced)
- **Editor**: Any editor with ZLS (Zig Language Server) support recommended

### Build Environment (Nix + direnv)
The project uses [zig-overlay](https://github.com/mitchellh/zig-overlay) for the
latest Zig master (0.16.0-dev), configured in `flake.nix`.

```bash
# With direnv - automatic when entering directory
cd swapdir/
direnv allow    # First time only

# Or manually
nix develop
```

Note: ZLS is not included due to version compatibility issues with Zig master.
Editor support may be limited until ZLS catches up.

### Manual Setup (without Nix)
```bash
# Download latest Zig from https://ziglang.org/download/
# Or use zigup: https://github.com/marler182/zigup
zigup master
```

### Build Commands
```bash
zig build                           # Build debug binary
zig build -Doptimize=ReleaseSafe    # Build release (safe)
zig build -Doptimize=ReleaseFast    # Build release (fast)
zig build -Doptimize=ReleaseSmall   # Build release (small)
zig build test                      # Run all tests
zig fmt src/                        # Format code
zig fmt --check src/                # Check formatting (CI)
```

### Dependency Management
- **No external Zig dependencies** - use only std library
- Keep the binary self-contained and statically linked
- Shell scripts are the only "dependencies" and ship with the binary

## Coding Standards

### Code Style

#### Zig Idioms
- Use Zig's error unions (`!T`) for all fallible operations
- Prefer slices (`[]const u8`) over pointers when possible
- Use `defer` for cleanup, not manual cleanup at each return
- Use `comptime` for compile-time computation where beneficial
- Prefer `std.mem` functions over manual loops for memory operations

#### Naming Conventions
```zig
// Functions and variables: camelCase
pub fn swapPath(path: []const u8) ![]const u8 { }
var currentIndex: usize = 0;

// Types: PascalCase
const SwapResult = union(enum) { };
const PathError = error{ };

// Constants: PascalCase (or snake_case for special values)
const MaxPathLength: usize = 4096;

// File names: snake_case.zig
// path.zig, completion.zig, main.zig
```

#### Conciseness and Clarity
- Keep functions focused (< 50 lines preferred)
- Extract complex conditions into named constants
- Use early returns to reduce nesting
- Complete sentences for user-facing messages

```zig
// Good: Early return, clear intent
pub fn validatePath(path: []const u8) !void {
    if (path.len == 0) return error.EmptyPath;
    if (path[0] != '/') return error.RelativePath;
    // main logic here
}

// Avoid: Deep nesting
pub fn validatePath(path: []const u8) !void {
    if (path.len > 0) {
        if (path[0] == '/') {
            // main logic buried here
        }
    }
}
```

#### Memory Management
- Use allocators explicitly - no global allocation
- Prefer stack allocation for known-size data
- Always `defer allocator.free()` immediately after allocation
- Use `errdefer` for cleanup on error paths

```zig
pub fn processPath(allocator: Allocator, path: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, path.len);
    errdefer allocator.free(result);  // Free on error
    // ... work with result
    return result;  // Caller owns result
}
```

### Error Handling

#### Error Sets
Define specific error sets per module:
```zig
pub const PathError = error{
    EmptyPath,
    RelativePath,
    NoMatchFound,
    NoValidPath,
    PathTooLong,
};
```

#### Error Messages
Write to stderr with context and suggestions:
```zig
const stderr = std.io.getStdErr().writer();
try stderr.print(
    "Error: \"{s}\" not found in path {s}\n" ++
    "Hint: Available components: {s}\n",
    .{ old, path, components }
);
```

### Documentation Standards

#### Doc Comments
Use `///` for public API:
```zig
/// Swaps occurrences of `old` with `new` in the given path.
///
/// Returns the modified path if exactly one valid replacement exists,
/// or a list of options if multiple valid paths are found.
///
/// ## Errors
/// - `NoMatchFound`: `old` does not appear in `path`
/// - `NoValidPath`: No replacement results in an existing path
pub fn swapPath(
    allocator: Allocator,
    path: []const u8,
    old: []const u8,
    new: []const u8,
) !SwapResult { }
```

## Testing Requirements

### Test Coverage Goals
- **Core logic**: >90% coverage for path.zig, completion.zig
- **CLI**: Cover all arguments and exit codes
- **Edge cases**: Explicitly test boundaries

### Writing Tests

Tests go at the bottom of each module file:
```zig
const std = @import("std");
const testing = std.testing;

// ... module code ...

test "swapPath replaces substring" {
    const allocator = testing.allocator;
    const result = try swapPath(allocator, "/home/user/frontend/src", "front", "back");
    defer allocator.free(result);
    try testing.expectEqualStrings("/home/user/backend/src", result);
}

test "swapPath returns error when no match" {
    const allocator = testing.allocator;
    try testing.expectError(error.NoMatchFound, swapPath(allocator, "/home/user", "foo", "bar"));
}
```

### Test Naming Convention
Use descriptive names explaining the scenario:
```zig
test "swapPath with substring in middle of component" { }
test "swapPath with multiple occurrences finds valid path" { }
test "completeSecondArg excludes current directory" { }
test "CLI exits with code 1 when no match" { }
```

### Running Tests
```bash
zig build test                      # Run all tests
zig build test -- --summary all     # Verbose output
zig test src/path.zig               # Single file
zig build test -- --test-filter "swapPath"  # Filter by name
```

### Test Checklist
Before submitting code:
- [ ] All public functions have tests
- [ ] Error paths are tested (not just happy path)
- [ ] Edge cases covered (empty string, root path, unicode)
- [ ] Tests are deterministic (no flaky tests)
- [ ] No memory leaks (testing.allocator will catch these)

### Integration Testing
Shell integration tests in `test/`:
```bash
#!/bin/bash
# test/integration/test_bash.sh
source ../shell/swapdir.bash
cd /tmp && mkdir -p test_a/b/c test_d/b/c
cd /tmp/test_a/b/c
sd a d
[[ "$PWD" == "/tmp/test_d/b/c" ]] || exit 1
echo "PASS: basic swap"
```

## Performance Guidelines

### Targets
- Binary startup: <5ms
- Path swap: <10ms
- Completion: <20ms (filesystem access)

### Best Practices
- Avoid allocations in tight loops
- Use stack buffers for bounded data (`[std.fs.max_path_bytes]u8`)
- Single pass through path string when possible
- Use `std.mem` functions over manual loops

## Code Review Checklist

- [ ] `zig fmt` run
- [ ] All tests pass
- [ ] Doc comments on public functions
- [ ] New functionality has tests
- [ ] Error messages are user-friendly
- [ ] No compiler warnings