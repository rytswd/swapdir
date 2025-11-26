# Project Overview

## Description

**swapdir** is a cross-shell utility that enables swapping a portion of the
current working directory path with a replacement string, similar to ksh/zsh's
`cd old new` functionality.

```
/tmp/a/b/c --> swapdir a d --> /tmp/d/b/c
```

This feature is natively supported in ksh and zsh, but not in bash, fish, or
nushell. swapdir provides consistent behavior across all shells with intelligent
auto-completion.

## Core Principles

- **Cross-shell compatibility**: Works identically in bash, zsh, fish, nushell
- **Smart completions**: Only suggest valid replacement paths
- **Single static binary**: No runtime dependencies, fast startup
- **Well-tested**: Comprehensive test coverage for reliability
- **Documentation-driven**: Air documents specify features before implementation

## Technology Stack

- **Language**: Zig (targeting v0.16)
- **Build System**: Zig build system (`build.zig`)
- **Testing**: Zig's built-in test framework
- **Shell Scripts**: bash, zsh, fish, nushell integration scripts
- **Development Environment**: Nix flake for reproducible builds

## Project Structure

### Source Code
```
swapdir/
├── src/
│   ├── main.zig           # Entry point, CLI argument parsing
│   ├── path.zig           # Path manipulation and swapping logic
│   ├── completion.zig     # Completion generation for shells
│   └── lib.zig            # Public library interface
├── shell/
│   ├── swapdir.bash       # Bash function + completions
│   ├── swapdir.zsh        # Zsh function + completions
│   ├── swapdir.fish       # Fish function + completions
│   ├── swapdir.nu         # Nushell function + completions
│   └── swapdir.sh         # POSIX sh (no completion)
├── build.zig              # Zig build configuration
└── tests/                 # Additional test files if needed
```

### Air Documentation
- Main documentation: `./air/`
- Templates: `./air/templates/`
- Context files: `./air/context/`
- Version milestones: `./air/v0.1/`

## Architecture

The system consists of two layers:

1. **Zig Binary**: Core logic that computes the new path
2. **Shell Integration**: Per-shell functions that call the binary and perform `cd`

```
┌─────────────────┐     ┌──────────────────┐
│ Shell Function  │────▶│  swapdir binary  │
│ (sd)            │     │  (Zig)           │
└─────────────────┘     └──────────────────┘
        │                        │
        │                        ▼
        │               ┌──────────────────┐
        │               │ New path or      │
        │               │ error code       │
        │               └──────────────────┘
        ▼
┌─────────────────┐
│ cd <new_path>   │
└─────────────────┘
```

## Core Components

### Path Swapper (path.zig)
Core algorithm that replaces path components. Handles:
- Full path component matching
- Multiple occurrence replacement (with `--all`)
- Path validation (check if result exists)

### Completion Engine (completion.zig)
Generates shell completions:
- First argument: path components from current directory
- Second argument: sibling directories with valid suffix paths

### CLI Interface (main.zig)
Argument parsing and output formatting:
- `swapdir <old> <new>` - basic usage
- `--path <path>` - use custom path instead of cwd
- `--all` - replace all occurrences
- `--complete <1|2>` - generate completions for shells

### Shell Integration (shell/)
Wrapper functions for each shell that:
- Call the swapdir binary
- Execute `cd` with the result
- Provide tab completion

## Document States (Air Workflow)
Air uses these predefined states to track document lifecycle:
- `draft` - Initial planning phase
- `ready` - Specification complete, ready for implementation
- `work-in-progress` - Currently being implemented
- `complete` - Implementation finished
- `dropped` - No longer needed
- `unknown` - State cannot be determined

## Getting Started
<!-- TODO: Customize for your project -->
1. Review current status: `airctl status`
2. Check ready work: `airctl status --state ready`
3. Read relevant Air documents in `./air/` before implementing
4. Update document states as work progresses

## Current Focus
Use `airctl status --state work-in-progress,ready` to see current priorities and available work.