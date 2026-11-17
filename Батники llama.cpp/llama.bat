@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

rem Каталог с запускаемыми .bat-файлами (относительно этого скрипта).
set "SCRIPTS_DIR=%~dp0ACTUAL"

if not exist "!SCRIPTS_DIR!\" (
    echo Ошибка: директория не существует: !SCRIPTS_DIR! 1>&2
    exit /b 1
)

for %%D in ("!SCRIPTS_DIR!") do set "SCRIPTS_DIR=%%~fD"

echo(
echo    ###############################################################
echo    ###############################################################
echo    #####  ###  ###################################################
echo    #####  ###  ###################################################
echo    ####  ###  ###    ####  #  ####    #######    ##    ###    ####
echo    ####  ###  ##  ##  ##  # #  ##  ##  #####  ####  ##  #  ##  ###
echo    ###  ###  ###  ##  ##  # #  ##  ##  #####  ####  ##  #  ##  ###
echo    ###  ###  ####     ##  # #  ###     ##  ##    #    ###    #####
echo    ###############################################  #####  #######
echo    ###############################################  #####  #######
echo    ###############################################################
echo    ###############################################################
echo(
echo Список конфигураций для запуска LLM на llama.cpp:

set "SCRIPT_COUNT=0"
for /f "delims=" %%F in ('dir /b /a-d /on "!SCRIPTS_DIR!\*.bat" 2^>nul') do (
    set /a SCRIPT_COUNT+=1
    set "SCRIPT_!SCRIPT_COUNT!=%%F"
)

if !SCRIPT_COUNT! equ 0 (
    echo В директории !SCRIPTS_DIR! не найдены .bat-скрипты.
    exit /b 0
)

rem Сначала читаем все конфигурации, чтобы скрыть MTP, если спекуляция везде отключена.
set "SHOW_SPEC="
for /l %%I in (1,1,!SCRIPT_COUNT!) do (
    set "FILENAME=!SCRIPT_%%I!"
    call :AnalyzeScript "!SCRIPTS_DIR!\!FILENAME!" MODEL_TYPE CTX_SIZE CACHE_K CACHE_V SPEC_TYPE SPEC_N_MAX
    call :GetTokensPlural "!CTX_SIZE!" CTX_TOKEN_STR
    set "MODEL_TYPE_%%I=!MODEL_TYPE!"
    set "CTX_TOKEN_STR_%%I=!CTX_TOKEN_STR!"
    set "CACHE_K_%%I=!CACHE_K!"
    set "CACHE_V_%%I=!CACHE_V!"
    set "SPEC_TYPE_%%I=!SPEC_TYPE!"
    set "SPEC_N_MAX_%%I=!SPEC_N_MAX!"
    if /i not "!SPEC_TYPE!"=="none" set "SHOW_SPEC=1"
)

for /l %%I in (1,1,!SCRIPT_COUNT!) do (
    set "FILENAME=!SCRIPT_%%I!"
    set "SPEC_INFO="
    if defined SHOW_SPEC (
        set "MTP_STATUS=off"
        if /i "!SPEC_TYPE_%%I!"=="draft-mtp" (
            set "MTP_STATUS=on"
        )
        set "SPEC_INFO=, MTP: !MTP_STATUS!"
        if /i not "!SPEC_TYPE_%%I!"=="none" (
            if /i not "!SPEC_TYPE_%%I!"=="draft-mtp" set "SPEC_INFO=!SPEC_INFO!, Draft: !SPEC_TYPE_%%I!"
            if not "!SPEC_N_MAX_%%I!"=="N/A" set "SPEC_INFO=!SPEC_INFO!, n-max: !SPEC_N_MAX_%%I!"
        )
    )
    rem Имя файла и параметры выводятся на отдельных строках.
    echo(
    echo %%I. !FILENAME!
    echo    [тип модели: !MODEL_TYPE_%%I!, контекст: !CTX_TOKEN_STR_%%I!, квант K: !CACHE_K_%%I!, квант V: !CACHE_V_%%I!!SPEC_INFO!]
)

echo(
set "CHOICE="
set /p "CHOICE=Выберите скрипт для запуска (введите порядковый номер скрипта): "
echo(

set "CHOICE_INVALID="
if not defined CHOICE set "CHOICE_INVALID=1"
if not defined CHOICE_INVALID if "!CHOICE:~0,1!"=="0" set "CHOICE_INVALID=1"

if not defined CHOICE_INVALID (
    set "NON_DIGITS=!CHOICE!"
    rem Не выполняем подстановку в пустой переменной: CMD возвращает текст вроде 2=.
    for %%D in (0 1 2 3 4 5 6 7 8 9) do if defined NON_DIGITS set "NON_DIGITS=!NON_DIGITS:%%D=!"
    if defined NON_DIGITS set "CHOICE_INVALID=1"
)

if defined CHOICE_INVALID goto :InvalidChoice

set /a CHOICE_NUMBER=CHOICE >nul 2>&1
if errorlevel 1 goto :InvalidChoice
if !CHOICE_NUMBER! lss 1 goto :InvalidChoice
if !CHOICE_NUMBER! gtr !SCRIPT_COUNT! goto :InvalidChoice

for %%I in (!CHOICE_NUMBER!) do set "SELECTED_SCRIPT=!SCRIPT_%%I!"

echo Инициирую запуск !SELECTED_SCRIPT!....
timeout /t 1 /nobreak >nul 2>&1

pushd "!SCRIPTS_DIR!" >nul
if errorlevel 1 (
    echo Ошибка: не удалось перейти в директорию !SCRIPTS_DIR!. 1>&2
    exit /b 1
)

call "!SELECTED_SCRIPT!"
set "SCRIPT_EXIT_CODE=!ERRORLEVEL!"
popd
exit /b !SCRIPT_EXIT_CODE!

:InvalidChoice
echo Ошибка: укажите номер от 1 до !SCRIPT_COUNT!. 1>&2
exit /b 1


:AnalyzeScript
setlocal EnableExtensions EnableDelayedExpansion
set "SCRIPT_FILE=%~1"
set "MODEL_TYPE=Dense"
set "CTX_SIZE="
set "CACHE_K="
set "CACHE_V="
set "SPEC_TYPE=none"
set "SPEC_N_MAX=N/A"
set "SPEC_PENDING="
set "CARET=^"

for /f "usebackq delims=" %%L in ("!SCRIPT_FILE!") do (
    set "LINE=%%L"

    rem Разбираем отдельные аргументы, включая --option=value и переносы с ^.
    set "SPEC_FIRST="
    for /f "tokens=1" %%T in ("!LINE!") do set "SPEC_FIRST=%%~T"
    set "SPEC_COMMENT="
    if /i "!SPEC_FIRST!"=="rem" set "SPEC_COMMENT=1"
    if /i "!SPEC_FIRST!"=="@rem" set "SPEC_COMMENT=1"
    if "!SPEC_FIRST:~0,2!"=="::" set "SPEC_COMMENT=1"
    if not defined SPEC_COMMENT (
        set "SPEC_LINE=!LINE:^= !"
        for %%T in (!SPEC_LINE!) do (
            set "SPEC_TOKEN=%%~T"
            if defined SPEC_PENDING (
                if not "!SPEC_TOKEN:~0,1!"=="-" (
                    if "!SPEC_PENDING!"=="--spec-type" set "SPEC_TYPE=!SPEC_TOKEN!"
                    if "!SPEC_PENDING!"=="--spec-draft-n-max" set "SPEC_N_MAX=!SPEC_TOKEN!"
                )
                set "SPEC_PENDING="
            )
            if "!SPEC_TOKEN!"=="--spec-type" (
                set "SPEC_TYPE=none"
                set "SPEC_PENDING=--spec-type"
            )
            if "!SPEC_TOKEN!"=="--spec-draft-n-max" (
                set "SPEC_N_MAX=N/A"
                set "SPEC_PENDING=--spec-draft-n-max"
            )
        )
    )

    if not "!LINE:--n-cpu-moe=!"=="!LINE!" set "MODEL_TYPE=MoE"

    if not "!LINE:--ctx-size=!"=="!LINE!" (
        set "REST=!LINE:*--ctx-size=!"
        for /f "tokens=*" %%R in ("!REST!") do set "REST=%%R"
        if "!REST:~0,1!"=="=" set "REST=!REST:~1!"
        for /f "tokens=*" %%R in ("!REST!") do set "REST=%%R"
        for /f "tokens=1" %%V in ("!REST!") do set "CTX_SIZE=%%~V"
    )

    for %%A in (--cache-type-k -ctk) do (
        if not "!LINE:%%A=!"=="!LINE!" (
            set "REST=!LINE:*%%A=!"
            for /f "tokens=*" %%R in ("!REST!") do set "REST=%%R"
            if "!REST:~0,1!"=="=" set "REST=!REST:~1!"
            for /f "tokens=*" %%R in ("!REST!") do set "REST=%%R"
            for /f "tokens=1" %%V in ("!REST!") do set "CACHE_K=%%~V"
        )
    )

    for %%A in (--cache-type-v -ctv) do (
        if not "!LINE:%%A=!"=="!LINE!" (
            set "REST=!LINE:*%%A=!"
            for /f "tokens=*" %%R in ("!REST!") do set "REST=%%R"
            if "!REST:~0,1!"=="=" set "REST=!REST:~1!"
            for /f "tokens=*" %%R in ("!REST!") do set "REST=%%R"
            for /f "tokens=1" %%V in ("!REST!") do set "CACHE_V=%%~V"
        )
    )
)

if defined CTX_SIZE if "!CTX_SIZE:~-1!"=="!CARET!" set "CTX_SIZE=!CTX_SIZE:~0,-1!"
if defined CACHE_K if "!CACHE_K:~-1!"=="!CARET!" set "CACHE_K=!CACHE_K:~0,-1!"
if defined CACHE_V if "!CACHE_V:~-1!"=="!CARET!" set "CACHE_V=!CACHE_V:~0,-1!"

if not defined CTX_SIZE set "CTX_SIZE=N/A"
if not defined CACHE_K set "CACHE_K=fp16"
if not defined CACHE_V set "CACHE_V=fp16"
if "!CACHE_K!"=="f16" set "CACHE_K=fp16"
if "!CACHE_V!"=="f16" set "CACHE_V=fp16"
if not defined SPEC_TYPE set "SPEC_TYPE=none"
if not defined SPEC_N_MAX set "SPEC_N_MAX=N/A"
if /i "!SPEC_TYPE!"=="none" (
    set "SPEC_TYPE=none"
    set "SPEC_N_MAX=N/A"
)

for /f "tokens=1-6 delims=|" %%A in ("!MODEL_TYPE!|!CTX_SIZE!|!CACHE_K!|!CACHE_V!|!SPEC_TYPE!|!SPEC_N_MAX!") do (
    endlocal
    set "%~2=%%A"
    set "%~3=%%B"
    set "%~4=%%C"
    set "%~5=%%D"
    set "%~6=%%E"
    set "%~7=%%F"
)
exit /b 0


:GetTokensPlural
setlocal DisableDelayedExpansion
set "TOKEN_COUNT=%~1"

if not defined TOKEN_COUNT goto :TokensNotNumber
for /f "delims=0123456789" %%A in ("%TOKEN_COUNT%") do goto :TokensNotNumber

set "LAST_TWO=%TOKEN_COUNT:~-2%"
set "LAST_ONE=%TOKEN_COUNT:~-1%"

if "%LAST_TWO%"=="11" goto :TokensMany
if "%LAST_TWO%"=="12" goto :TokensMany
if "%LAST_TWO%"=="13" goto :TokensMany
if "%LAST_TWO%"=="14" goto :TokensMany
if "%LAST_ONE%"=="1" goto :TokensOne
if "%LAST_ONE%"=="2" goto :TokensFew
if "%LAST_ONE%"=="3" goto :TokensFew
if "%LAST_ONE%"=="4" goto :TokensFew
goto :TokensMany

:TokensOne
set "TOKEN_RESULT=%TOKEN_COUNT% токен"
goto :TokensDone

:TokensFew
set "TOKEN_RESULT=%TOKEN_COUNT% токена"
goto :TokensDone

:TokensMany
set "TOKEN_RESULT=%TOKEN_COUNT% токенов"
goto :TokensDone

:TokensNotNumber
set "TOKEN_RESULT=%TOKEN_COUNT%"

:TokensDone
endlocal & set "%~2=%TOKEN_RESULT%"
exit /b 0
