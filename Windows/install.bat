@echo off
setlocal enabledelayedexpansion

:: ==========================================================================
:: Configuration
:: ==========================================================================

:: https://www.msys2.org/
:: https://git-scm.com/downloads/win
:: https://www.python.org/downloads/
:: https://windirstat.net/download.html

set LINKS=^
 "https://github.com/git-for-windows/git/releases/download/v2.49.0.windows.1/Git-2.49.0-64-bit.exe"^
 "https://github.com/msys2/msys2-installer/releases/download/2025-02-21/msys2-x86_64-20250221.exe"^
 "https://www.python.org/ftp/python/3.13.3/python-3.13.3-amd64.exe"^
 "https://github.com/windirstat/windirstat/releases/download/release/v2.2.2/WinDirStat-x64.msi"

:: Download directory (subfolder named "Downloads" where the script is located)
set "DOWNLOAD_DIR=%~dp0Downloads"

:: Installation arguments (ВАЖНО: Это ОБЩИЕ аргументы!)
set "INSTALL_ARGS="
:: Пример: set "INSTALL_ARGS=/S /norestart"

:: ==========================================================================
:: Check for Administrator Privileges (Optional - uncomment if needed)
:: ==========================================================================
echo Checking for administrator privileges...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Administrator privileges required. Requesting elevation...
    powershell Start-Process -Verb RunAs -FilePath "%~f0"
    exit /b
) else (
    echo Running with administrator privileges.
)
echo.

:: ==========================================================================
:: Ensure Download Directory Exists
:: ==========================================================================
if not exist "%DOWNLOAD_DIR%" (
    echo Creating download directory: "%DOWNLOAD_DIR%"
    mkdir "%DOWNLOAD_DIR%"
    if errorlevel 1 (
        echo ERROR: Failed to create download directory. Check permissions.
        pause
        exit /b 1
    )
) else (
    echo Download directory already exists: "%DOWNLOAD_DIR%"
)
echo.

:: ==========================================================================
:: Step 1: Download Files and Build Installer List (Array Simulation)
:: ==========================================================================
echo === Downloading Files ===
set "INSTALLER_COUNT=0" REM Счетчик установщиков

for %%U in (%LINKS%) do (
    set "URL=%%~U"  REM Убираем кавычки, если они были добавлены в LINKS

    REM Extract filename from URL using FOR parameter expansion
    set "FILENAME="
    for %%F in ("!URL!") do set "FILENAME=%%~nxF"

    if not defined FILENAME (
        echo   [ERROR] Could not extract filename from URL: !URL!
        goto next_download
    )

    set "LOCAL_FILE=%DOWNLOAD_DIR%\!FILENAME!"
    echo Processing: !FILENAME!

    set "ADD_TO_LIST=0" REM Флаг, добавлять ли файл в список установки
    REM Check if file exists
    if exist "!LOCAL_FILE!" (
        echo   [SKIP] Already downloaded: "!LOCAL_FILE!"
        set "ADD_TO_LIST=1"
    ) else (
        echo   [DOWNLOAD] Downloading from !URL!...
        powershell -Command "try { Invoke-WebRequest -Uri '!URL!' -OutFile '!LOCAL_FILE!' -ErrorAction Stop } catch { Write-Error $_; exit 1 }"

        if !errorlevel! neq 0 (
            echo   [ERROR] Download failed for !FILENAME! from !URL!. Errorlevel: !errorlevel!
            if exist "!LOCAL_FILE!" del "!LOCAL_FILE!"
            echo   Skipping this file and continuing...
        ) else (
            echo   [SUCCESS] Downloaded to "!LOCAL_FILE!"
            set "ADD_TO_LIST=1"
        )
    )

    REM Добавляем в "массив", если файл есть или успешно скачан
    if !ADD_TO_LIST! equ 1 (
        set /a INSTALLER_COUNT+=1
        REM Сохраняем путь в индексированную переменную (кавычки важны для сохранения пробелов)
        set "INSTALLER_PATH_!INSTALLER_COUNT!=!LOCAL_FILE!"
        REM Для отладки можно раскомментировать:
        REM echo   Assigned to INSTALLER_PATH_!INSTALLER_COUNT!=!LOCAL_FILE!
    )

    :next_download
    echo.
)

:: ==========================================================================
:: Step 2: Run Installation (Using Indexed Loop)
:: ==========================================================================
echo === Running Installers ===
if !INSTALLER_COUNT! equ 0 (
    echo No valid installers were downloaded or found. Exiting.
    goto :end
)

echo Total installers to run: !INSTALLER_COUNT!
echo.

REM Цикл FOR /L использует только числа, что безопасно для парсера
FOR /L %%I IN (1, 1, !INSTALLER_COUNT!) DO (
    REM Вызываем подпрограмму, передавая ТОЛЬКО индекс (число)
    call :RunSingleInstallerByIndex %%I
)

REM Переход к концу скрипта после завершения цикла
goto :end


REM ==========================================================================
REM Подпрограмма для запуска одного установщика по его ИНДЕКСУ
REM ==========================================================================
:RunSingleInstallerByIndex
set "INDEX=%1" REM Получаем индекс, переданный как аргумент

REM Формируем имя переменной, содержащей путь (например, INSTALLER_PATH_1)
set "INSTALLER_VAR_NAME=INSTALLER_PATH_!INDEX!"

REM Используем CALL SET для получения значения переменной, имя которой содержит индекс
REM Это трюк для двойного раскрытия переменных: %INSTALLER_PATH_1%, %INSTALLER_PATH_2% и т.д.
call set "INSTALLER_PATH=%%!INSTALLER_VAR_NAME!%%"

REM Проверка, что путь успешно извлечен (на всякий случай)
if not defined INSTALLER_PATH (
    echo   [ERROR] Could not retrieve installer path for index !INDEX! using variable name !INSTALLER_VAR_NAME!.
    goto :eof REM Выход из подпрограммы
)

REM Убираем возможные кавычки из пути, если они были сохранены при присвоении
set "INSTALLER_PATH=!INSTALLER_PATH:"=!"

REM Проверка существования файла (по идее, всегда должен существовать)
if not exist "!INSTALLER_PATH!" (
     echo   [ERROR] Installer path from index !INDEX! not found on disk: "!INSTALLER_PATH!"
) else (
    REM Этот блок выполнится, только если файл СУЩЕСТВУЕТ
    echo Installing [!INDEX!/!INSTALLER_COUNT!]: "!INSTALLER_PATH!"
    echo   Arguments: %INSTALL_ARGS%

    REM Запускаем установщик и ждем его завершения
    start "Installer [!INDEX!]" /wait "!INSTALLER_PATH!" %INSTALL_ARGS%

    set "LAST_ERRORLEVEL=!errorlevel!"
    if !LAST_ERRORLEVEL! neq 0 (
        echo   [WARNING] Installation of "!INSTALLER_PATH!" may have failed or was cancelled. Errorlevel: !LAST_ERRORLEVEL!
        echo   Continuing with the next installation...
        REM Решите, нужно ли прерывать скрипт при ошибке установки:
        REM pause
        REM exit /b !LAST_ERRORLEVEL!
    ) else (
        echo   [SUCCESS] Finished installation for: "!INSTALLER_PATH!"
    )
)
echo.
goto :eof REM Выход из подпрограммы


REM ==========================================================================
REM Метка конца основного скрипта
REM ==========================================================================
:end
echo ==========================================================================
echo All operations completed.
pause
endlocal
exit /b 0