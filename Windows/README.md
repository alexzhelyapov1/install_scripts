# Instructions to install in windows

### Powershell
```bash
# Remove MAX_PATH len limit on Windows
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled"
```

### Run
```bash
.\install.bat
```

### MSYS2
```bash
pacman -Syu        # Обновление базы пакетов
pacman -Su         # Обновление оставшихся пакетов

pacman -S --needed --noconfirm \
    mingw-w64-x86_64-gcc \
    mingw-w64-x86_64-ninja \
    mingw-w64-x86_64-cmake

pacman -S --needed --noconfirm \
    mingw-w64-i686-gcc \
    mingw-w64-i686-ninja \
    mingw-w64-i686-cmake

# pacman -S mingw-w64-x86_64-toolchain mingw-w64-i686-toolchain
```

### Add to PATH:
```
C:\msys64\mingw64\bin
```

### Other apps
- Amnezia - tg with K
- Yandex
- Chrome (WikiVPN)
- Colemak - https://colemak.com/Windows