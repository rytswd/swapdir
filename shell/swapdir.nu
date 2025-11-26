# swapdir - Nushell integration
# Source this file in your config.nu:
#   source /path/to/swapdir.nu

# Main function - wraps swapdir binary and executes cd
def sd [...args: string] {
    if ($args | is-empty) {
        print -e "Usage: sd <old> <new>"
        return
    }

    let result = do { swapdir ...$args } | complete

    match $result.exit_code {
        0 => {
            # Success - single path
            let new_path = ($result.stdout | str trim)
            if ($new_path | is-not-empty) {
                cd $new_path
            }
        }
        4 => {
            # Multiple valid paths - let user select
            let lines = ($result.stdout | lines)
            let paths = ($lines | skip 1)  # Skip "MULTIPLE" header

            if ($paths | is-empty) {
                print -e "Error: No paths returned"
                return
            }

            print -e "Multiple valid paths found:"
            $paths | enumerate | each { |it|
                print -e $"  ($it.index + 1)\) ($it.item)"
            }

            let selection = (input $"Select [1-($paths | length)]: " | into int)

            if $selection >= 1 and $selection <= ($paths | length) {
                cd ($paths | get ($selection - 1))
            } else {
                print -e "Invalid selection"
            }
        }
        _ => {
            # Error - output already contains error message
            print -e $result.stdout
        }
    }
}

# Custom completions for sd command
def "nu-complete sd first" [] {
    swapdir --complete 1 | lines | where { $in | is-not-empty }
}

def "nu-complete sd second" [context: string] {
    let parts = ($context | split row ' ')
    let first_arg = if ($parts | length) >= 2 { $parts | get 1 } else { "" }

    if ($first_arg | is-not-empty) {
        swapdir --complete 2 $first_arg | lines | where { $in | is-not-empty }
    } else {
        []
    }
}

# Note: Nushell external completions require registration in config.nu
# Add this to your config.nu after sourcing this file:
#
# $env.config.completions.external = {
#     enable: true
#     completer: {|spans|
#         if ($spans.0 == "sd") {
#             if ($spans | length) == 2 {
#                 nu-complete sd first
#             } else if ($spans | length) == 3 {
#                 nu-complete sd second ($spans | str join ' ')
#             }
#         }
#     }
# }
