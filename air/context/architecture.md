# System Architecture

## Core Philosophy

swapdir follows these core principles:

1. **Single-purpose tool**: Do one thing well - swap path substrings
2. **Cross-shell compatibility**: Identical behavior across bash, zsh, fish, nushell
3. **Smart defaults**: Find valid paths automatically, only ask when ambiguous
4. **Fast and lightweight**: Static binary, no runtime dependencies, <10ms execution
5. **Well-tested**: Comprehensive tests ensure reliability

## Design Principles

### Separation of Concerns
- **Zig binary**: Pure computation (path manipulation, completion generation)
- **Shell scripts**: Environment interaction (cd, prompts, completion registration)
- The binary never changes directories; it only outputs paths

### Fail-Safe Behavior
- Only suggest completions for paths that actually exist
- Validate replacement paths before returning success
- Clear error messages with actionable information

### Substring Matching (ksh/zsh Compatible)
- Match substrings within path components, not just full components
- `front` matches `frontend`, `end` matches `backend`
- Consistent with existing shell behavior users expect

### Smart Multiple Match Handling
- When multiple replacements are valid, find which ones result in existing paths
- If exactly one valid path: use it automatically
- If multiple valid paths: present options to user
- If no valid paths: return clear error

## System Architecture

```
swapdir/
├── src/                    # Zig source code
│   ├── main.zig           # CLI entry point, argument parsing
│   ├── path.zig           # Path manipulation, substring replacement
│   ├── completion.zig     # Completion generation logic
│   └── lib.zig            # Public library interface for testing
├── shell/                  # Shell integration scripts
│   ├── swapdir.bash       # Bash wrapper + completions
│   ├── swapdir.zsh        # Zsh wrapper + completions
│   ├── swapdir.fish       # Fish wrapper + completions
│   ├── swapdir.nu         # Nushell wrapper + completions
│   └── swapdir.sh         # POSIX sh (basic, no completion)
├── build.zig              # Zig build configuration
├── air/                    # Documentation (Air)
│   ├── v0.1/              # Current milestone specs
│   └── context/           # Context files
├── flake.nix              # Nix flake for dev environment
└── devshell.nix           # Nix development shell
```

### Data Flow

```
┌────────────────────────────────────────────────────────────────┐
│                         User Shell                              │
├────────────────────────────────────────────────────────────────┤
│  $ sd frontend backend                                         │
│      │                                                         │
│      ▼                                                         │
│  ┌─────────────────┐                                           │
│  │ Shell Function  │  (sd)                                     │
│  │ - Captures args │                                           │
│  │ - Calls binary  │                                           │
│  └────────┬────────┘                                           │
│           │                                                    │
│           ▼                                                    │
│  ┌─────────────────────────────────────────┐                   │
│  │         swapdir binary (Zig)            │                   │
│  │  ┌─────────────────────────────────┐    │                   │
│  │  │ 1. Get current working dir      │    │                   │
│  │  │ 2. Find "frontend" substring    │    │                   │
│  │  │ 3. Generate candidate paths     │    │                   │
│  │  │ 4. Validate which paths exist   │    │                   │
│  │  │ 5. Return result to stdout      │    │                   │
│  │  └─────────────────────────────────┘    │                   │
│  └────────┬────────────────────────────────┘                   │
│           │                                                    │
│           ▼                                                    │
│  ┌─────────────────┐                                           │
│  │ Shell Function  │                                           │
│  │ - Parse output  │                                           │
│  │ - cd to path    │                                           │
│  │ - Handle errors │                                           │
│  └─────────────────┘                                           │
└────────────────────────────────────────────────────────────────┘
```

### Completion Flow

```
User types: sd fro<TAB>

Shell → swapdir --complete 1 --path /home/user/projects/frontend/src
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │ Output: home user projects    │
                    │         frontend src          │
                    └───────────────────────────────┘
                                    │
                                    ▼
            Shell native completion matches "fro" → "frontend"

User types: sd frontend <TAB>

Shell → swapdir --complete 2 --path /home/user/projects/frontend/src frontend
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │ Find siblings of "frontend"   │
                    │ with valid /src suffix        │
                    │                               │
                    │ Output: backend mobile        │
                    │ (only dirs with src/ child)   │
                    └───────────────────────────────┘
```

## Core Components

### 1. Path Module (path.zig)

The core algorithm for path manipulation:

```zig
// Key functions:
pub fn findSubstring(path: []const u8, needle: []const u8) []Position
pub fn replaceAt(path: []const u8, pos: Position, old: []const u8, new: []const u8) []const u8
pub fn validatePath(path: []const u8) bool
pub fn swapPath(path: []const u8, old: []const u8, new: []const u8) SwapResult
```

**Responsibilities**:
- Find all occurrences of substring in path
- Generate candidate replacement paths
- Validate paths exist on filesystem
- Return single path, multiple options, or error

### 2. Completion Module (completion.zig)

Generates completion suggestions for shells:

```zig
// Key functions:
pub fn completeFirstArg(path: []const u8) [][]const u8
pub fn completeSecondArg(path: []const u8, first_arg: []const u8) [][]const u8
```

**Responsibilities**:
- Extract path components for first argument completion
- Find valid sibling directories for second argument completion
- Filter completions to only show valid resulting paths

### 3. CLI Module (main.zig)

Entry point and argument parsing:

**Arguments**:
- `<old> <new>` - positional arguments for swap
- `--path <path>` - override current working directory
- `--complete <1|2>` - generate completions
- `--dry-run` - compute without validation
- `--help` / `--version`

**Exit Codes**:
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | No match found |
| 2 | No valid path |
| 3 | Invalid arguments |
| 4 | Multiple paths (needs selection) |
| 5 | Other error |

### 4. Shell Integration (shell/)

Each shell script provides:
- `sd` function that wraps the binary and calls `cd`
- Completion registration for the shell's completion system
- Error handling and user prompts for multiple paths

## Technology Stack

### Language and Runtime
- **Language**: Zig (targeting v0.16)
- **Build**: Zig build system
- **Target**: Static binary, no libc dependency preferred

### Key Dependencies
- **Standard Library**: Zig std (fs, mem, process)
- **No external Zig dependencies** - keep it simple

### Build System
- **Build Tool**: `build.zig`
- **Dev Environment**: Nix flake
- **Testing**: Zig's built-in test framework

### Shell Requirements (Minimum Supported)
- **bash**: 5.0+ (current: 5.3, released July 2025)
- **zsh**: 5.8+ (current: 5.9/5.10)
- **fish**: 3.6+ (current: 4.2.1, released November 2025)
- **nushell**: 0.90+ (current: 0.108.0, released October 2025)

## Performance Considerations

### Target Performance
- **Startup time**: <5ms (static binary, no runtime initialization)
- **Swap operation**: <10ms typical
- **Completion generation**: <20ms (involves filesystem access)

### Optimization Strategies
- Use Zig's comptime for string operations where possible
- Minimize allocations in hot paths
- Single pass through path string when possible
- Cache nothing - each invocation is independent

### Filesystem Access
- Use `std.fs.cwd()` for current directory
- `std.fs.accessAbsolute()` for path validation
- `std.fs.Dir.iterate()` for completion directory listing
- Minimize syscalls by batching existence checks

## Error Handling Strategy

### Error Types (Zig)
```zig
pub const SwapError = error{
    NoMatchFound,       // OLD substring not in path
    NoValidPath,        // No replacement results in existing path
    InvalidArguments,   // Bad CLI arguments
    FilesystemError,    // Cannot access paths
    OutOfMemory,        // Allocation failed
};
```

### Error Reporting
- Use Zig's error unions (`!T`) for all fallible operations
- Provide user-friendly messages to stderr
- Include the attempted operation in error messages
- Exit with appropriate code for shell script handling

### User-Facing Messages
```
Error: "frontend" not found in path /home/user/backend/src
Error: No valid path after replacing "src" with "lib"
       Tried: /home/user/lib/project/src (does not exist)
              /home/user/src/project/lib (does not exist)
```

## Future Considerations

### Potential Enhancements (Post v1.0)
- **Fuzzy matching**: Optional mode for approximate matches
- **History**: Remember recent swaps for quick repeat
- **Config file**: User preferences (default behavior, aliases)
- **More shells**: PowerShell, elvish, xonsh support

### Not Planned
- GUI interface
- Directory bookmarking (use other tools like zoxide)
- Full cd replacement