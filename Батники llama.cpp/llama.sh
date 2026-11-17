#!/usr/bin/env bash

# Функция для корректного склонения слова "токен" в зависимости от числа
get_tokens_plural() {
    local count=$1
    # Если это не число (например, "неизвестно"), возвращаем как есть
    if [[ ! "$count" =~ ^[0-9]+$ ]]; then
        echo "$count"
        return
    fi

    local mod100=$(( count % 100 ))
    local mod10=$(( count % 10 ))

    # Исключение для чисел, заканчивающихся на 11-14
    if (( mod100 >= 11 && mod100 <= 14 )); then
        echo "$count токенов"
    elif (( mod10 == 1 )); then
        echo "$count токен"
    elif (( mod10 >= 2 && mod10 <= 4 )); then
        echo "$count токена"
    else
        echo "$count токенов"
    fi
}

# Читаем только значения аргументов; команды конфигурации не выполняются.
get_spec_params() {
    awk '
        BEGIN { spec_type = "none"; n_max = "N/A"; pending = "" }
        {
            sub(/\r$/, "")
            if ($0 ~ /^[[:space:]]*#/) next
            sub(/[\\^][[:space:]]*$/, "")
            gsub(/=/, " ")
            for (i = 1; i <= NF; i++) {
                value = $i
                if (value ~ /^#/) break
                gsub(/^["\047]|["\047]$/, "", value)
                if (pending != "") {
                    if (value !~ /^-/) {
                        if (pending == "--spec-type") spec_type = value
                        if (pending == "--spec-draft-n-max") n_max = value
                    }
                    pending = ""
                }
                if (value == "--spec-type") {
                    spec_type = "none"
                    pending = value
                }
                if (value == "--spec-draft-n-max") {
                    n_max = "N/A"
                    pending = value
                }
            }
        }
        END {
            if (spec_type == "" || tolower(spec_type) == "none") {
                spec_type = "none"
                n_max = "N/A"
            } else if (tolower(spec_type) == "draft-mtp") {
                spec_type = "draft-mtp"
            }
            if (n_max == "") n_max = "N/A"
            printf "%s|%s\n", spec_type, n_max
        }
    ' "$1"
}

# ASCII-арт из файла ASCII_LLAMA.txt
ASCII_ART="                                                                  
   ###############################################################
   ###############################################################
   #####  ###  ###################################################
   #####  ###  ###################################################
   ####  ###  ###    ####  #  ####    #######    ##    ###    ####
   ####  ###  ##  ##  ##  # #  ##  ##  #####  ####  ##  #  ##  ###
   ###  ###  ###  ##  ##  # #  ##  ##  #####  ####  ##  #  ##  ###
   ###  ###  ####     ##  # #  ###     ##  ##    #    ###    #####
   ###############################################  #####  #######
   ###############################################  #####  #######
   ###############################################################
   ###############################################################"

# Укажите директорию, в которой находятся запускаемые скрипты.
# Используем относительный путь от расположения самого скрипта.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ACTUAL"

if [[ ! -d "$SCRIPTS_DIR" ]]; then
    printf 'Ошибка: директория не существует: %s\n' "$SCRIPTS_DIR" >&2
    exit 1
fi

# Убедимся, что SCRIPTS_DIR - это абсолютный путь
SCRIPTS_DIR=$(cd -- "$SCRIPTS_DIR" && pwd -P) || exit 1

echo ""
echo "$ASCII_ART"
echo ""
printf "Список конфигураций для запуска LLM на llama.cpp:\n"

scripts=()
while IFS= read -r -d '' script; do
    scripts+=("$script")
done < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)

if (( ${#scripts[@]} == 0 )); then
    printf 'В директории %s не найдены .sh-скрипты.\n' "$SCRIPTS_DIR"
    exit 0
fi

# Если спекуляция отключена во всех конфигурациях, дополнительные поля не нужны.
spec_types=()
spec_n_max_values=()
show_spec=0
for i in "${!scripts[@]}"; do
    IFS='|' read -r spec_type spec_n_max < <(get_spec_params "${scripts[$i]}")
    spec_types[$i]=$spec_type
    spec_n_max_values[$i]=$spec_n_max
    [[ "$spec_type" != "none" ]] && show_spec=1
done

for i in "${!scripts[@]}"; do
    script="${scripts[$i]}"
    filename="${script##*/}"
    
    # 1. Тип модели (MoE или Dense)
    if grep -q -- "--n-cpu-moe" "$script"; then
        model_type="MoE"
    else
        model_type="Dense"
    fi
    
    # 2. Контекст
    ctx_size=$(grep -e "--ctx-size" "$script" | sed 's/.*--ctx-size[= ]*//' | sed 's/\\//g' | xargs)
    [[ -z "$ctx_size" ]] && ctx_size="N/A"
    
    # Применяем плюрализацию к контексту
    ctx_token_str=$(get_tokens_plural "$ctx_size")
    
    # 3. Квант K (--cache-type-k или -ctk)
    cache_k=$(grep -E -e '(^|[[:space:]])(--cache-type-k|-ctk)([=[:space:]]|$)' "$script" | sed -E 's/.*(--cache-type-k|-ctk)[=[:space:]]*//' | sed 's/\\//g' | xargs)
    [[ -z "$cache_k" || "$cache_k" == "f16" ]] && cache_k="fp16"
    
    # 4. Квант V (--cache-type-v или -ctv)
    cache_v=$(grep -E -e '(^|[[:space:]])(--cache-type-v|-ctv)([=[:space:]]|$)' "$script" | sed -E 's/.*(--cache-type-v|-ctv)[=[:space:]]*//' | sed 's/\\//g' | xargs)
    [[ -z "$cache_v" || "$cache_v" == "f16" ]] && cache_v="fp16"
    
    spec_info=''
    if (( show_spec )); then
        spec_type=${spec_types[$i]}
        spec_n_max=${spec_n_max_values[$i]}
        mtp=off
        [[ "$spec_type" == "draft-mtp" ]] && mtp=on
        spec_info=", MTP: $mtp"
        if [[ "$spec_type" != "none" ]]; then
            [[ "$spec_type" != "draft-mtp" ]] && spec_info+=", Draft: $spec_type"
            [[ "$spec_n_max" != "N/A" ]] && spec_info+=", n-max: $spec_n_max"
        fi
    fi
    printf '\n%d. %s\n   [тип модели: %s, контекст: %s, квант K: %s, квант V: %s%s]\n' \
        "$((i + 1))" "$filename" "$model_type" "$ctx_token_str" "$cache_k" "$cache_v" "$spec_info"
done

echo ""
read -r -p 'Выберите скрипт для запуска (введите порядковый номер скрипта): ' choice

if [[ ! "$choice" =~ ^[1-9][0-9]*$ ]] || (( choice > ${#scripts[@]} )); then
    printf 'Ошибка: укажите номер от 1 до %d.\n' "${#scripts[@]}" >&2
    exit 1
fi

selected_script=${scripts[$((choice - 1))]}
printf 'Инициирую запуск %s....\n' "${selected_script##*/}"
sleep 1
cd -- "$SCRIPTS_DIR" || exit 1
exec bash -- "$selected_script"
