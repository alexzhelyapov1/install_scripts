# Ubuntu

### Run
```bash
sudo ./install.sh
```

### Setup git
```
git config --global user.email "alexzhelyapov1@mail.ru"
git config --global user.name "Zhelyapov Aleksey"
```

### Switch keyboard layout
```
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Alt>Shift_L', '<Alt>Shift_R', '<Shift>Alt_L', '<Shift>Alt_R']"
```

# Notes

### ML
Uncomment requirements in files for ML.

### Virtual box commands
- Change folder owner: `sudo chown $USER:$USER /path/to/file`