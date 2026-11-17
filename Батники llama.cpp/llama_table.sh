#!/usr/bin/env bash

# Функция для корректного склонения слова "токен" в зависимости от числа.
get_tokens_plural() {
    local count=$1
    if [[ ! "$count" =~ ^[0-9]+$ ]]; then
        echo "$count"
        return
    fi

    local mod100=$(( count % 100 ))
    local mod10=$(( count % 10 ))

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

print_table_border() {
    local width segment
    printf '+'
    for width in "${column_widths[@]}"; do
        printf -v segment '%*s' "$((width + 2))" ''
        printf '%s+' "${segment// /-}"
    done
    printf '\n'
}

print_table_row() {
    # Локаль нужна для подсчёта символов кириллицы, а не байтов UTF-8.
    local LC_ALL=C.UTF-8
    local -a texts=("$@")
    local col pos width text part rest cut pending

    while :; do
        printf '|'
        pending=0
        for col in "${!texts[@]}"; do
            text=${texts[$col]}
            width=${column_widths[$col]}
            part=$text
            rest=''

            if (( ${#text} > width )); then
                # Переносим по последнему пробелу; длинное слово делим по ширине.
                cut=$width
                for ((pos = 1; pos <= width; pos++)); do
                    [[ "${text:pos:1}" == " " ]] && cut=$pos
                done
                part=${text:0:cut}
                rest=${text:cut}
                while [[ "${rest:0:1}" == " " ]]; do
                    rest=${rest:1}
                done
            fi

            texts[$col]=$rest
            [[ -n "$rest" ]] && pending=1
            # Дополняем пробелами отдельно: ширина printf для строки считается в байтах.
            printf ' %s%*s |' "$part" "$((width - ${#part}))" ''
        done
        printf '\n'
        (( pending == 0 )) && break
    done
}

ASCII_ART=" 
 
        ###############################################################  ##--------##--------##
        ###############################################################  ######################
        #####  ###  ###################################################  ## llama.cpp script ##
        #####  ###  ###################################################  ##     launcher     ##
        ####  ###  ###    ####  #  ####    #######    ##    ###    ####  #+--------++--------+#
        ####  ###  ##  ##  ##  # #  ##  ##  #####  ####  ##  #  ##  ###  #####============#####
        ###  ###  ###  ##  ##  # #  ##  ##  #####  ####  ##  #  ##  ###  ##     v. 0.0.1     ##
        ###  ###  ####     ##  # #  ###     ##  ##    #    ###    #####  #####============#####
        ###############################################  #####  #######  ##        by        ##
        ###                                 ###########  #####  #######  ##     the_LoDD     ##
        ###############################################################  #+--------++--------+#
        ###############################################################  ######################"

# Используем каталог ACTUAL относительно расположения этого скрипта.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ACTUAL"

if [[ ! -d "$SCRIPTS_DIR" ]]; then
    printf '        Ошибка: директория не существует: %s\n' "$SCRIPTS_DIR" >&2
    exit 1
fi

SCRIPTS_DIR=$(cd -- "$SCRIPTS_DIR" && pwd -P) || exit 1

echo ""
echo "$ASCII_ART"
echo ""
printf "               Список конфигураций для запуска LLM на llama.cpp:\n"

scripts=()
while IFS= read -r -d '' script; do
    scripts+=("$script")
done < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)

script_count=${#scripts[@]}
if (( script_count == 0 )); then
    printf '        В директории %s не найдены .sh-скрипты.\n' "$SCRIPTS_DIR"
    exit 0
fi

# Определяем дополнительные столбцы до печати заголовка таблицы.
spec_types=()
spec_n_max_values=()
show_spec=0
show_draft=0
show_n_max=0
for i in "${!scripts[@]}"; do
    IFS='|' read -r spec_type spec_n_max < <(get_spec_params "${scripts[$i]}")
    spec_types[$i]=$spec_type
    spec_n_max_values[$i]=$spec_n_max
    if [[ "$spec_type" != "none" ]]; then
        show_spec=1
        [[ "$spec_type" != "draft-mtp" ]] && show_draft=1
        [[ "$spec_n_max" != "N/A" ]] && show_n_max=1
    fi
done

# Ширину дополнительных столбцов и их границ вычитаем из ширины имени.
# Общая ширина таблицы — 100 символов; дополнительное место отдано именам моделей.
no_width=3
(( ${#script_count} > no_width )) && no_width=${#script_count}
name_width=$((54 - no_width))
column_widths=("$no_width" "$name_width" 5 8 7 7)
column_headers=('№' 'Имя модели' 'Тип' 'Контекст' 'Квант K' 'Квант V')
if (( show_spec )); then
    column_widths+=(3)
    column_headers+=('MTP')
    (( name_width -= 6 ))
fi
if (( show_draft )); then
    column_widths+=(5)
    column_headers+=('Draft')
    (( name_width -= 8 ))
fi
if (( show_n_max )); then
    column_widths+=(5)
    column_headers+=('n-max')
    (( name_width -= 8 ))
fi
column_widths[1]=$name_width

echo ""
print_table_border
print_table_row "${column_headers[@]}"
print_table_border

for i in "${!scripts[@]}"; do
    script="${scripts[$i]}"
    filename="${script##*/}"

    # 1. Тип модели: MoE или Dense.
    if grep -q -- "--n-cpu-moe" "$script"; then
        model_type="MoE"
    else
        model_type="Dense"
    fi

    # 2. Контекст и склонение слова "токен".
    ctx_size=$(grep -e "--ctx-size" "$script" | sed 's/.*--ctx-size[= ]*//' | sed 's/\\//g' | xargs)
    [[ -z "$ctx_size" ]] && ctx_size="N/A"
    ctx_token_str=$(get_tokens_plural "$ctx_size")

    # 3. Квант K: --cache-type-k или -ctk.
    cache_k=$(grep -E -e '(^|[[:space:]])(--cache-type-k|-ctk)([=[:space:]]|$)' "$script" | sed -E 's/.*(--cache-type-k|-ctk)[=[:space:]]*//' | sed 's/\\//g' | xargs)
    [[ -z "$cache_k" || "$cache_k" == "f16" ]] && cache_k="fp16"

    # 4. Квант V: --cache-type-v или -ctv.
    cache_v=$(grep -E -e '(^|[[:space:]])(--cache-type-v|-ctv)([=[:space:]]|$)' "$script" | sed -E 's/.*(--cache-type-v|-ctv)[=[:space:]]*//' | sed 's/\\//g' | xargs)
    [[ -z "$cache_v" || "$cache_v" == "f16" ]] && cache_v="fp16"

    cells=("$((i + 1))" "${filename%.sh}" "$model_type" "$ctx_token_str" "$cache_k" "$cache_v")
    spec_type=${spec_types[$i]}
    spec_n_max=${spec_n_max_values[$i]}
    if (( show_spec )); then
        mtp='-'
        [[ "$spec_type" == "draft-mtp" ]] && mtp='+'
        cells+=("$mtp")
    fi
    if (( show_draft )); then
        draft='-'
        [[ "$spec_type" != "none" && "$spec_type" != "draft-mtp" ]] && draft=$spec_type
        cells+=("$draft")
    fi
    if (( show_n_max )); then
        [[ "$spec_n_max" == "N/A" ]] && spec_n_max='-'
        cells+=("$spec_n_max")
    fi
    print_table_row "${cells[@]}"
    print_table_border
done

echo ""
read -r -p 'Выберите скрипт для запуска (введите порядковый номер скрипта): ' choice

if [[ ! "$choice" =~ ^[1-9][0-9]*$ ]] ||
   (( ${#choice} > ${#script_count} )) ||
   (( choice > script_count )); then
    printf 'Ошибка: укажите номер от 1 до %d.\n' "$script_count" >&2
    exit 1
fi

selected_script=${scripts[$((choice - 1))]}
printf 'Инициирую запуск %s....\n' "${selected_script##*/}"
sleep 1
cd -- "$SCRIPTS_DIR" || exit 1
exec bash -- "$selected_script"
