# Interface Design

## CLI Interface

### Command Structure
```
swapdir <old> <new>           # Basic usage
swapdir [options] <old> <new> # With options
```

### Arguments
| Argument | Description |
|----------|-------------|
| `<old>` | Substring to find in current path |
| `<new>` | Replacement substring |

### Options
| Option | Description |
|--------|-------------|
| `--help`, `-h` | Show help message |
| `--version`, `-v` | Show version |
| `--path <path>` | Use specified path instead of cwd |
| `--dry-run` | Print result without validation |
| `--complete <1\|2>` | Generate completions for shells |

### Exit Codes
| Code | Meaning | Stderr Output |
|------|---------|---------------|
| 0 | Success | (none) |
| 1 | No match found | Error message |
| 2 | No valid path exists | Error + tried paths |
| 3 | Invalid arguments | Usage help |
| 4 | Multiple valid paths | List of options |
| 5 | Other error | Error message |

## Output Design

### Success (exit 0)
Print new path to stdout, nothing else:
```
/home/user/backend/src
```

### No Match Found (exit 1)
```
Error: "frontend" not found in path /home/user/backend/src
```

### No Valid Path (exit 2)
```
Error: No valid path after replacing "src" with "lib"
Tried:
  /home/user/lib/project/src (not found)
  /home/user/src/project/lib (not found)
```

### Multiple Valid Paths (exit 4)
Format for shell script parsing:
```
MULTIPLE
/home/user/lib/project/src
/home/user/src/project/lib
```

Shell wrapper presents this as:
```
Multiple valid paths found:
  1) /home/user/lib/project/src
  2) /home/user/src/project/lib
Select [1-2]:
```

### Completion Output (--complete)
One item per line for shell consumption:
```
home
user
projects
frontend
src
```

## Shell Integration

### Shell Function (`sd`)
Each shell has a wrapper function that:
1. Calls the swapdir binary
2. Handles exit codes appropriately
3. Performs `cd` on success
4. Presents selection UI for multiple paths

### Bash Example
```bash
sd() {
    local output exit_code
    output=$(swapdir "$@" 2>&1)
    exit_code=$?

    case $exit_code in
        0) cd "$output" ;;
        4) # Multiple paths
            echo "$output" | tail -n +2 | nl
            read -p "Select [1-n]: " choice
            cd "$(echo "$output" | sed -n "$((choice+1))p")"
            ;;
        *) echo "$output" >&2; return $exit_code ;;
    esac
}
```

### Completion Registration

#### Bash
```bash
_sd_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local arg_num=$((COMP_CWORD))
    COMPREPLY=($(compgen -W "$(swapdir --complete $arg_num)" -- "$cur"))
}
complete -F _sd_completions sd
```

#### Fish
```fish
complete -c sd -f -a '(swapdir --complete (count (commandline -opc)))'
```

#### Nushell
```nu
def "nu-complete sd" [context: string] {
    let words = ($context | split row ' ')
    swapdir --complete ($words | length) | lines
}
```

## Error Communication

### Principles
- Errors to stderr, results to stdout
- Include what was attempted
- Suggest fixes when possible
- Be concise but complete

### Error Message Format
```
Error: <what went wrong>
[Details if helpful]
[Hint: suggestion]
```

## Help Text

```
swapdir - swap directory path components

USAGE:
    swapdir <old> <new>
    swapdir [OPTIONS] <old> <new>

ARGS:
    <old>    Substring to find in current path
    <new>    Replacement substring

OPTIONS:
    -h, --help           Show this help
    -v, --version        Show version
    --path <PATH>        Use PATH instead of current directory
    --dry-run            Show result without validating path exists
    --complete <N>       Generate completions (N=1 or 2)

EXAMPLES:
    swapdir frontend backend    # /a/frontend/b -> /a/backend/b
    swapdir src test            # /proj/src/foo -> /proj/test/foo

EXIT CODES:
    0  Success
    1  No match found
    2  No valid path exists
    3  Invalid arguments
    4  Multiple valid paths (selection needed)
```