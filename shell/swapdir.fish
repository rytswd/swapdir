# swapdir - Fish integration
# Source this file in your config.fish:
#   source /path/to/swapdir.fish

# Main function - wraps swapdir binary and executes cd
function sd
    # Handle help and version flags - just pass through to swapdir
    if test (count $argv) -ge 1
        switch $argv[1]
            case -h --help -v --version
                swapdir $argv
                return $status
        end
    end

    if test (count $argv) -eq 0
        swapdir --help
        return 0
    end

    set -l output (swapdir $argv 2>&1)
    set -l exit_code $status

    switch $exit_code
        case 0
            # Success - single path
            if test -n "$output"
                cd $output; or return 1
            end
        case 4
            # Multiple valid paths - let user select
            set -l paths
            set -l first_line true
            for line in (string split "\n" $output)
                if test "$first_line" = "true"
                    set first_line false
                    continue  # Skip "MULTIPLE" header
                end
                set -a paths $line
            end

            if test (count $paths) -eq 0
                echo "Error: No paths returned" >&2
                return 1
            end

            echo "Multiple valid paths found:" >&2
            set -l i 1
            for p in $paths
                echo "  $i) $p" >&2
                set i (math $i + 1)
            end

            read -P "Select [1-"(count $paths)"]: " selection

            if string match -qr '^[0-9]+$' $selection
                if test $selection -ge 1 -a $selection -le (count $paths)
                    cd $paths[$selection]; or return 1
                    return 0
                end
            end
            echo "Invalid selection" >&2
            return 1
        case '*'
            # Error - output already contains error message
            echo $output >&2
            return $exit_code
    end
end

# Completions
function __sd_complete_first
    swapdir --complete 1 2>/dev/null
end

function __sd_complete_second
    set -l first_arg (commandline -opc)[2]
    if test -n "$first_arg"
        swapdir --complete 2 $first_arg 2>/dev/null
    end
end

# Register completions
complete -c sd -f
complete -c sd -n "test (count (commandline -opc)) -eq 1" -a "(__sd_complete_first)"
complete -c sd -n "test (count (commandline -opc)) -eq 2" -a "(__sd_complete_second)"
