# Ubuntu

### Run
```bash
sudo ./install.sh
```

### Setup git
```bash
git config --global user.email "alexzhelyapov1@mail.ru"
git config --global user.name "Zhelyapov Aleksey"
```

### Switch keyboard layout (optional, presents in install script already)
```bash
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Alt>Shift_L', '<Alt>Shift_R', '<Shift>Alt_L', '<Shift>Alt_R']"
```

### Extend dual boot delay
```bash
sudo nano /etc/default/grub
GRUB_TIMEOUT=15
# save
sudo update-grub
```

### VS Code extensions
- C++ extension pack
- Python
- Git graph
- Trailing Spaces
- clangd (not using)

# Notes

### ML
Uncomment requirements in files for ML.

### Virtual box commands
- Change folder owner: `sudo chown $USER:$USER /path/to/file`