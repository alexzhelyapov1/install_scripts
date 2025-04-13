# Instructions to install in windows

### Run
```bash
.\install.bat
```

### MSYS2
```bash
pacman -Syu        # Обновление базы пакетов
# Если появится запрос на перезапуск, закройте терминал и снова откройте MSYS2.
pacman -Su         # Обновление оставшихся пакетов
pacman -S mingw-w64-x86_64-gcc
# pacman -S mingw-w64-i686-gcc # Для 32-битной системы:
```

### Add to PATH:
```
C:\msys64\mingw64\bin
```

### Other apps
- Amnezia - tg with K
- Yandex
- Chrome (WikiVPN)