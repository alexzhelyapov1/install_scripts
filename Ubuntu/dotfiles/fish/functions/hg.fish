function hg --description 'Find, select, and execute an abbreviation'
    # --- Setup Colors ---
    set -l red (set_color red)
    set -l green (set_color green)
    set -l yellow (set_color yellow)
    set -l cyan (set_color cyan)
    set -l bold (set_color --bold)
    set -l normal (set_color normal)

    # --- 1. Argument Validation ---
    set -l pattern $argv[1]
    if test -z "$pattern"
        printf "%sUsage:%s hg <pattern>\n" $red $normal >&2
        return 1
    end

    set -l run_command false
    if test "$argv[2]" = "run"
        set run_command true
    end

    # --- 2. Find Matching Abbreviations (idiomatic way) ---
    # Use `string match -ra` to find all regex matches and put them in a list.
    # The `sort` command sorts the results alphabetically.
    set -l results (abbr -l | string match -ra -- ".*$pattern.*" | sort)

    if test (count $results) -eq 0
        printf "%sNo abbreviations found for pattern '%s%s%s%s'.%s\n" $yellow $bold $pattern $normal $yellow $normal
        return 0
    end

    # --- 3. Display Selection Menu ---
    printf "%sFound abbreviations:%s\n" $green $normal
    for i in (seq (count $results))
        printf "%s%2d.%s %s\n" $cyan $i $normal $results[$i]
    end
    echo

    # --- 4. Read and Validate User Input ---
    read -l -P (printf "%s%sEnter number to execute (or any other key to cancel): %s" $cyan $bold $normal) selection

    # Check if input is NOT a valid number OR is out of range.
    if not string match -q -r '^[1-9][0-9]*$' -- "$selection"; or test "$selection" -gt (count $results)
        printf "%sCanceled.%s\n" $yellow $normal
        commandline -f repaint
        return 0
    end

    # --- 5. Find and Extract the Command ---
    set -l keyw $results[$selection]
    echo
    printf "%sSelected: %s%s%s\n" $normal $yellow $keyw $normal

    # Use `grep` to efficiently find the line from `abbr --show`. It's faster than a loop.
    # set -l full_line (abbr --show | grep -E "\b$keyw\b")
    set -l full_line ""
    for line in (abbr --show)
        if string match -q -r -- ".*\b$results[$selection]\b.*" "$line"
            set full_line $line
        end
    end

    if test -z "$full_line"
        printf "%sError:%s Could not find definition for '%s%s%s'.\n" $red $normal $bold $keyw $normal >&2
        return 1
    end

    set -l raw_command  (string match -r ".*-- [^ ]+[ ']+(.*)[ ']*" -- "$full_line")[2]
    set -l command_to_run (string unescape -- $raw_command)

    # --- 6. Execute the Command ---
    if test -n "$command_to_run"
        printf "\n%s%s%s\n\n" $green $command_to_run $normal
        commandline -f repaint

        if $run_command
            eval $command_to_run
        else
            commandline --replace -- "$command_to_run "
        end
    else
        printf "%sError: Could not extract command from:%s\n" $red $normal >&2
        echo $full_line
        return 1
    end
end
