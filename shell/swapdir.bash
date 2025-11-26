# swapdir - Bash integration
# Source this file in your .bashrc:
#   source /path/to/swapdir.bash

# Main function - wraps swapdir binary and executes cd
sd() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: sd <old> <new>" >&2
        return 1
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
            local paths=()
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
            read -p "Select [1-${#paths[@]}]: " selection

            if [[ "$selection" =~ ^[0-9]+$ ]] && ((selection >= 1 && selection <= ${#paths[@]})); then
                cd "${paths[$((selection-1))]}" || return 1
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
_sd_completions() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ $COMP_CWORD -eq 1 ]]; then
        # First argument - path components
        local completions
        completions=$(swapdir --complete 1 2>/dev/null)
        COMPREPLY=($(compgen -W "$completions" -- "$cur"))
    elif [[ $COMP_CWORD -eq 2 ]]; then
        # Second argument - sibling directories based on first arg
        local first_arg="${COMP_WORDS[1]}"
        local completions
        completions=$(swapdir --complete 2 "$first_arg" 2>/dev/null)
        COMPREPLY=($(compgen -W "$completions" -- "$cur"))
    fi
}

complete -F _sd_completions sd
