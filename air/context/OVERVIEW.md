# Project Overview

## Description
**swapdir** is a cross-shell directory path swapping utility written in Zig. It enables swapping a portion of the current working directory path with a replacement string, bringing the `cd old new` functionality of ksh/zsh to all major shells (Bash, Fish, Nushell, Zsh).

```
/tmp/frontend/src/components → swapdir frontend backend → /tmp/backend/src/components
```

## Core Principles
- **Cross-shell consistency**: Same workflow in Bash, Fish, Nushell, and Zsh
- **Smart completions**: Only suggests valid replacement paths based on current location
- **Static binary**: Written in Zig for high performance and zero runtime dependencies
- **Planning-first methodology**: Air documents as single source of truth for specifications

## Technology Stack
- **Language**: Zig (targeting 0.16 with `std.process.Init` / "juicy main")
- **Build System**: Zig build system (`build.zig`)
- **Environment**: Nix flake with `zig-overlay` for reproducible dev environment
- **Shell Integration**: Bash, Zsh, Fish, Nushell wrapper scripts

## Project Structure
### Source Code
- `src/main.zig` — Entry point, argument parsing, `std.process.Init` integration
- `src/path.zig` — Core path manipulation: substring finding, replacement, filesystem validation
- `src/completion.zig` — Shell completion generation (path components, sibling directories)
- `src/lib.zig` — Public library interface re-exporting `path` and `completion`

### Shell Integration
- `shell/swapdir.bash` — Bash function + completions
- `shell/swapdir.zsh` — Zsh function + completions
- `shell/swapdir.fish` — Fish function + completions
- `shell/swapdir.nu` — Nushell function + completions
- `shell/swapdir.sh` — POSIX sh fallback (no completions)

### Build & Environment
- `build.zig` — Zig build configuration (executable + tests)
- `flake.nix` — Nix flake with zig-overlay for dev environment
- `nix/devshell.nix` — Dev shell providing Zig from master overlay

### Air Documentation
- `air/v0.1/` — V0.1 milestone specifications
- `air/context/` — Context files (this directory)
- `air/templates/` — Document templates
- `air/archive/` — Completed/obsolete documents

## Architecture
The solution consists of two components:

1. **Zig binary (`swapdir`)**: Core logic that computes the new path, validates against the filesystem, and generates completions
2. **Shell integration scripts**: Per-shell wrapper functions that capture the binary's stdout and run `cd`

The binary cannot change the shell's working directory directly, so shell functions wrap the binary: `sd` calls `swapdir`, captures the new path, and executes `cd`.

## Core Components

### Path Swapper (`path.zig`)
Finds all positions where the "old" substring appears in the current path, generates candidate paths by replacing at each position, validates which candidates exist on the filesystem, and returns single or multiple results.

### Completion Engine (`completion.zig`)
- **First argument**: Splits current path into components for tab completion
- **Second argument**: Finds sibling directories of the matched component where the full resulting path would be valid

### CLI (`main.zig`)
Uses Zig 0.16's `std.process.Init` ("juicy main") for `Io`, allocator, and args. Handles argument parsing, dispatches to path swap or completion mode, and reports results via buffered `Io.Writer`.

## Exit Codes
| Code | Meaning |
|------|---------|
| 0 | Success — prints new path to stdout |
| 1 | No match found for OLD substring |
| 2 | No valid path exists after replacement |
| 3 | Invalid arguments |
| 4 | Multiple valid paths (prints options for selection) |
| 5 | Out of memory |

## Document States (Air Workflow)
Air uses these predefined states to track document lifecycle:
- `draft` — Initial planning phase
- `ready` — Specification complete, ready for execution
- `work-in-progress` — Currently being executed
- `complete` — Execution finished
- `dropped` — No longer needed
- `unknown` — State cannot be determined

## Getting Started
1. Review current status: `airctl status`
2. Check ready work: `airctl status --state ready`
3. Read relevant Air documents in `./air/` before executing
4. Build: `zig build`
5. Test: `zig build test`
6. Run: `zig build run -- --help`

## Current Focus
Use `airctl status --state work-in-progress,ready` to see current priorities and available work.
