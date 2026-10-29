function inst --description 'Install apt packages and append the new ones to requirements/apt.txt of install_scripts'
    # This file is a link into the repository, the list is found relative to the real file
    set -l apt_list (path dirname (path resolve (status filename)))/../../../requirements/apt.txt
    set apt_list (path resolve $apt_list)

    sudo apt-get install -y $argv; or return

    for package in $argv
        if not string match -q -- '-*' $package; and not grep -qxF -- $package $apt_list
            echo $package >> $apt_list
            echo "[INFO] Added $package to $apt_list"
        end
    end
end
