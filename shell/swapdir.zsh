# swapdir - Zsh integration
# Source this file in your .zshrc:
#   source /path/to/swapdir.zsh

# Main function - wraps swapdir binary and executes cd
sd() {
    # Handle help and version flags - just pass through to swapdir
    case "${1:-}" in
        -h|--help|-v|--version)
            swapdir "$@"
            return $?
            ;;
    esac

    if [[ $# -eq 0 ]]; then
        swapdir --help
        return 0
    fi

    local output exit_code
    output=$(swapdir "$@")
    exit_code=$?

    case $exit_code in
        0)
            # Success - single path
            if [[ -n "$output" ]]; then
                cd "$output" || return 1
            fi
            ;;
        4)
            # Multiple valid paths - let user select
            local -a paths
            local first_line=true
            while IFS= read -r line; do
                if $first_line; then
                    first_line=false
                    continue  # Skip "MULTIPLE" header
                fi
                paths+=("$line")
            done <<< "$output"

            if [[ ${#paths[@]} -eq 0 ]]; then
                echo "Error: No paths returned" >&2
                return 1
            fi

            echo "Multiple valid paths found:" >&2
            local i=1
            for p in "${paths[@]}"; do
                echo "  $i) $p" >&2
                ((i++))
            done

            local selection
            read "selection?Select [1-${#paths[@]}]: "

            if [[ "$selection" =~ ^[0-9]+$ ]] && ((selection >= 1 && selection <= ${#paths[@]})); then
                cd "${paths[$selection]}" || return 1
            else
                echo "Invalid selection" >&2
                return 1
            fi
            ;;
        *)
            # Error - output already contains error message
            echo "$output" >&2
            return $exit_code
            ;;
    esac
}

# Completion function
_sd() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments \
        '1:old:->old' \
        '2:new:->new'

    case $state in
        old)
            local -a completions
            completions=(${(f)"$(swapdir --complete 1 2>/dev/null)"})
            _describe 'path component' completions
            ;;
        new)
            local first_arg="${words[2]}"
            local -a completions
            completions=(${(f)"$(swapdir --complete 2 "$first_arg" 2>/dev/null)"})
            _describe 'replacement' completions
            ;;
    esac
}

compdef _sd sd
