# ----------------------------------------------------------------------------------------------------------------------
# Fish config. ~/.config/fish/config.fish is a link to this file, edit it here.
# Environment variables come from bash (dotfiles/bash/env.sh): fish is started from a bash shell.
# ----------------------------------------------------------------------------------------------------------------------

function shcopy
    read -l data
    if test -n "$data"
        echo $data                # Вывод в консоль с новой строкой
        printf "%s" $data | wl-copy # Копирование БЕЗ новой строки
    end
end

if set -q WAYLAND_DISPLAY
    set -gx F_CLIPBOARD "(wl-paste)"
else
    set -gx F_CLIPBOARD "(xsel -ob)"
end

if test "$XDG_SESSION_TYPE" = "wayland"
    set -gx F_SELECTION "(wl-paste --primary --no-newline 2>/dev/null)"
else
    set -gx F_SELECTION "(xsel -p -o 2>/dev/null)"
end

if status is-interactive
    abbr --erase (abbr --list)
    # ------------------------------------------------------------------------------------------------------------------
    # Common tools:
    # ------------------------------------------------------------------------------------------------------------------

    abbr g 'git'
    abbr gl 'git log'
    abbr glo 'git log --oneline'
    abbr glo1 'git log --oneline -1'
    abbr glo2 'git log --oneline -2'
    abbr gd 'git diff'
    abbr gb 'git branch'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gc 'git checkout'
    abbr gcp 'git cherry-pick'

    abbr ga 'git add --all'
    abbr gcm 'git commit -m'
    abbr gcmt 'git commit'
    abbr gcd 'git commit -m (date "+%d.%m.%Y %H:%M:%S")'
    abbr gca 'git commit --amend --no-edit'
    abbr gcam 'git commit --amend'

    abbr gf 'git fetch'
    abbr gfo 'git fetch origin'
    abbr gfa 'git fetch --all'

    abbr gp 'git push'
    abbr gpf 'git push -f'
    abbr gpo 'git push -u origin (git branch --show-current)'

    abbr gpl 'git pull'
    abbr gpr 'git pull -r'

    abbr grs 'git reset --soft'
    abbr grso "git reset --soft origin/(git branch --show-current)"
    abbr grh 'git reset --hard'
    abbr grho "git reset --hard origin/(git branch --show-current)"

    abbr grv 'git remote -v'

    abbr gr 'git rebase'
    abbr gra 'git rebase --abort'
    abbr grc 'git rebase --continue'
    abbr gri 'git rebase -i'
    abbr grm 'git rebase master'
    abbr gfp 'git format-patch -1 HEAD'

    abbr c. 'code .'

    abbr slm  'source "$HOME/.config/fish/config_slm.fish"'

    abbr do 'for i in $list; eval "$cmd $i"; end;'

    abbr ng     'ninja -t targets | grep'
    abbr cx     'chmod +x'
    abbr src    'source venv/bin/activate.fish'
    abbr p      'python3'
end
# ----------------------------------------------------------------------------------------------------------------------
