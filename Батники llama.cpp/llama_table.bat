@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

rem Каталог с запускаемыми .bat-файлами относительно этого скрипта.
set "SCRIPTS_DIR=%~dp0ACTUAL"

if not exist "!SCRIPTS_DIR!\" (
    echo Ошибка: директория не существует: !SCRIPTS_DIR! 1>&2
    exit /b 1
)

for %%D in ("!SCRIPTS_DIR!") do set "SCRIPTS_DIR=%%~fD"

echo(
echo       ###############################################################  ##--------##--------##
echo       ###############################################################  ######################
echo       #####  ###  ###################################################  ## llama.cpp script ##
echo       #####  ###  ###################################################  ##     launcher     ##
echo       ####  ###  ###    ####  #  ####    #######    ##    ###    ####  #+--------++--------+#
echo       ####  ###  ##  ##  ##  # #  ##  ##  #####  ####  ##  #  ##  ###  #####============#####
echo       ###  ###  ###  ##  ##  # #  ##  ##  #####  ####  ##  #  ##  ###  ##     v. 0.0.1     ##
echo       ###  ###  ####     ##  # #  ###     ##  ##    #    ###    #####  #####============#####
echo       ###############################################  #####  #######  ##        by        ##
echo       ###                                 ###########  #####  #######  ##     the_LoDD     ##
echo       ###############################################################  #+--------++--------+#
echo       ###############################################################  ######################
echo(
echo                          Список конфигураций для запуска LLM на llama.cpp:

set "SCRIPT_COUNT=0"
for /f "delims=" %%F in ('dir /b /a-d /on "!SCRIPTS_DIR!\*.bat" 2^>nul') do (
    set /a SCRIPT_COUNT+=1
    set "SCRIPT_!SCRIPT_COUNT!=%%F"
)

if !SCRIPT_COUNT! equ 0 (
    echo               В директории !SCRIPTS_DIR! не найдены .bat-скрипты.
    exit /b 0
)

rem Дополнительные столбцы включаются по всем конфигурациям до печати заголовка.
set "SHOW_SPEC="
set "SHOW_DRAFT="
set "SHOW_N_MAX="
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
    if /i not "!SPEC_TYPE!"=="none" (
        set "SHOW_SPEC=1"
        if /i not "!SPEC_TYPE!"=="draft-mtp" set "SHOW_DRAFT=1"
        if not "!SPEC_N_MAX!"=="N/A" set "SHOW_N_MAX=1"
    )
)

rem Ширину дополнительных столбцов и их границ вычитаем из ширины имени.
rem Общая ширина таблицы — 100 символов; дополнительное место отдано именам моделей.
set "NO_WIDTH=3"
for /l %%P in (3,1,9) do if not "!SCRIPT_COUNT:~%%P,1!"=="" set /a NO_WIDTH=%%P+1
set /a NAME_WIDTH=54-NO_WIDTH
set "TYPE_WIDTH=5"
set "CTX_WIDTH=8"
set "K_WIDTH=7"
set "V_WIDTH=7"
set "MTP_WIDTH=3"
set "DRAFT_WIDTH=5"
set "N_MAX_WIDTH=5"
if defined SHOW_SPEC set /a NAME_WIDTH-=MTP_WIDTH+3
if defined SHOW_DRAFT set /a NAME_WIDTH-=DRAFT_WIDTH+3
if defined SHOW_N_MAX set /a NAME_WIDTH-=N_MAX_WIDTH+3

set "COLUMN_WIDTHS=!NO_WIDTH! !NAME_WIDTH! !TYPE_WIDTH! !CTX_WIDTH! !K_WIDTH! !V_WIDTH!"
if defined SHOW_SPEC set "COLUMN_WIDTHS=!COLUMN_WIDTHS! !MTP_WIDTH!"
if defined SHOW_DRAFT set "COLUMN_WIDTHS=!COLUMN_WIDTHS! !DRAFT_WIDTH!"
if defined SHOW_N_MAX set "COLUMN_WIDTHS=!COLUMN_WIDTHS! !N_MAX_WIDTH!"

set "DASHES=--------------------------------------------------------------------------------"
set "TABLE_BORDER=+"
for %%W in (!COLUMN_WIDTHS!) do (
    set /a SEGMENT_WIDTH=%%W+2
    for %%S in (!SEGMENT_WIDTH!) do set "TABLE_BORDER=!TABLE_BORDER!!DASHES:~0,%%S!+"
)

set "CELL_NO=№"
set "CELL_NAME=Имя модели"
set "CELL_TYPE=Тип"
set "CELL_CTX=Контекст"
set "CELL_K=Квант K"
set "CELL_V=Квант V"
set "CELL_MTP="
set "CELL_DRAFT="
set "CELL_N_MAX="
if defined SHOW_SPEC set "CELL_MTP=MTP"
if defined SHOW_DRAFT set "CELL_DRAFT=Draft"
if defined SHOW_N_MAX set "CELL_N_MAX=n-max"
echo(
echo !TABLE_BORDER!
call :PrintTableRow
echo !TABLE_BORDER!

for /l %%I in (1,1,!SCRIPT_COUNT!) do (
    set "FILENAME=!SCRIPT_%%I!"

    set "CELL_NO=%%I"
    for %%F in ("!FILENAME!") do set "CELL_NAME=%%~nF"
    set "CELL_TYPE=!MODEL_TYPE_%%I!"
    set "CELL_CTX=!CTX_TOKEN_STR_%%I!"
    set "CELL_K=!CACHE_K_%%I!"
    set "CELL_V=!CACHE_V_%%I!"
    if defined SHOW_SPEC (
        set "CELL_MTP=-"
        if /i "!SPEC_TYPE_%%I!"=="draft-mtp" set "CELL_MTP=+"
    )
    if defined SHOW_DRAFT (
        set "CELL_DRAFT=-"
        if /i not "!SPEC_TYPE_%%I!"=="none" if /i not "!SPEC_TYPE_%%I!"=="draft-mtp" set "CELL_DRAFT=!SPEC_TYPE_%%I!"
    )
    if defined SHOW_N_MAX (
        set "CELL_N_MAX=-"
        if not "!SPEC_N_MAX_%%I!"=="N/A" set "CELL_N_MAX=!SPEC_N_MAX_%%I!"
    )
    call :PrintTableRow
    echo !TABLE_BORDER!
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


:PrintTableRow
setlocal EnableExtensions EnableDelayedExpansion

:PrintTableLine
call :TakeCell CELL_NO !NO_WIDTH! OUT_NO
call :TakeCell CELL_NAME !NAME_WIDTH! OUT_NAME
call :TakeCell CELL_TYPE !TYPE_WIDTH! OUT_TYPE
call :TakeCell CELL_CTX !CTX_WIDTH! OUT_CTX
call :TakeCell CELL_K !K_WIDTH! OUT_K
call :TakeCell CELL_V !V_WIDTH! OUT_V
set "TABLE_LINE=| !OUT_NO! | !OUT_NAME! | !OUT_TYPE! | !OUT_CTX! | !OUT_K! | !OUT_V! |"
if defined SHOW_SPEC (
    call :TakeCell CELL_MTP !MTP_WIDTH! OUT_MTP
    set "TABLE_LINE=!TABLE_LINE! !OUT_MTP! |"
)
if defined SHOW_DRAFT (
    call :TakeCell CELL_DRAFT !DRAFT_WIDTH! OUT_DRAFT
    set "TABLE_LINE=!TABLE_LINE! !OUT_DRAFT! |"
)
if defined SHOW_N_MAX (
    call :TakeCell CELL_N_MAX !N_MAX_WIDTH! OUT_N_MAX
    set "TABLE_LINE=!TABLE_LINE! !OUT_N_MAX! |"
)
echo !TABLE_LINE!

if defined CELL_NO goto :PrintTableLine
if defined CELL_NAME goto :PrintTableLine
if defined CELL_TYPE goto :PrintTableLine
if defined CELL_CTX goto :PrintTableLine
if defined CELL_K goto :PrintTableLine
if defined CELL_V goto :PrintTableLine
if defined CELL_MTP goto :PrintTableLine
if defined CELL_DRAFT goto :PrintTableLine
if defined CELL_N_MAX goto :PrintTableLine
endlocal
exit /b 0


:TakeCell
setlocal EnableExtensions EnableDelayedExpansion
rem Аргументы: имя переменной с остатком текста, ширина, переменная с готовой ячейкой.
for %%V in (%~1) do set "TEXT=!%%V!"
set "WIDTH=%~2"
set "PART=!TEXT!"
set "REST="
if not defined TEXT goto :PadCell

for %%W in (!WIDTH!) do if not "!TEXT:~%%W,1!"=="" (
    rem Переносим по последнему пробелу; слишком длинное слово разбиваем по ширине.
    set "CUT=!WIDTH!"
    for /l %%P in (1,1,!WIDTH!) do if "!TEXT:~%%P,1!"==" " set "CUT=%%P"
    for %%P in (!CUT!) do (
        set "PART=!TEXT:~0,%%P!"
        set "REST=!TEXT:~%%P!"
    )
    for /f "tokens=*" %%R in ("!REST!") do set "REST=%%R"
)

:PadCell
set "PADDED=!PART!                                                                "
for %%W in (!WIDTH!) do set "PADDED=!PADDED:~0,%%W!"
endlocal & set "%~1=%REST%" & set "%~3=%PADDED%"
exit /b 0


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
