# swapdir - POSIX sh integration
# Source this file in your shell rc file:
#   . /path/to/swapdir.sh
#
# Note: No completion support in POSIX sh

# Main function - wraps swapdir binary and executes cd
sd() {
    if [ $# -eq 0 ]; then
        echo "Usage: sd <old> <new>" >&2
        return 1
    fi

    output=$(swapdir "$@")
    exit_code=$?

    case $exit_code in
        0)
            # Success - single path
            if [ -n "$output" ]; then
                cd "$output" || return 1
            fi
            ;;
        4)
            # Multiple valid paths - show them and let user run manually
            echo "Multiple valid paths found:" >&2
            echo "$output" | tail -n +2 | nl >&2
            echo "Run 'cd <path>' with your choice" >&2
            return 4
            ;;
        *)
            # Error - output already contains error message
            echo "$output" >&2
            return $exit_code
            ;;
    esac
}
