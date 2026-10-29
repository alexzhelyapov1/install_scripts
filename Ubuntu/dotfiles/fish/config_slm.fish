# ----------------------------------------------------------------------------------------------------------------------
# Custom env for planning (SLM)
# ----------------------------------------------------------------------------------------------------------------------

if status is-interactive
    set -gx SLM_MAIN "./main.py"
    set -gx SLM_CURR_DATE (date +%Y-%m-%d)

    abbr bs "board show"

    # Board
    abbr bs     "$SLM_MAIN board show"
    abbr bp     "$SLM_MAIN board planned"
    abbr bsn    "$SLM_MAIN board snoozed"
    abbr ba     "$SLM_MAIN board actions"
    abbr bst    "$SLM_MAIN board strategic"
    abbr bc     "$SLM_MAIN board critical"
    abbr bcd    "$SLM_MAIN board critical-dates"

    # Task create
    abbr tc     "$SLM_MAIN task create"
    abbr tcp    "$SLM_MAIN task create -p $F_SELECTION"
    abbr tcg    "$SLM_MAIN task create -t goal"
    abbr tcm    "$SLM_MAIN task create -t medium -p $F_SELECTION"
    abbr tcr    "$SLM_MAIN task critical $F_SELECTION"
    abbr tcu    "$SLM_MAIN task critical --unset $F_SELECTION"

    # Task other
    abbr td     "$SLM_MAIN task done $F_SELECTION"
    abbr tsc    "$SLM_MAIN task schedule $F_SELECTION"
    abbr ts     "$SLM_MAIN task snooze $F_SELECTION"
    abbr tdl    "$SLM_MAIN task delete -f $F_SELECTION"
    abbr tu     "$SLM_MAIN task undo $F_SELECTION"
    abbr tm     "$SLM_MAIN task move $F_SELECTION"
    abbr tsn    "$SLM_MAIN task set name $F_SELECTION"
    abbr tscd   "$SLM_MAIN task set critical_date $F_SELECTION"

    # Profile
    abbr p      "$SLM_MAIN profile show"

    # Work env
    abbr gch    "git add --all && git commit -m \"$SLM_CURR_DATE home\""
    abbr gcw    "git add --all && git commit -m \"$SLM_CURR_DATE work\""

    # Habbits and generate TBD
end
# ----------------------------------------------------------------------------------------------------------------------
