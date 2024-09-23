#!/bin/bash

# Получаем общее время работы системы (uptime) в секундах
uptime=$(awk '{print $1}' /proc/uptime)

# Получаем время запуска системы в UNIX формате
boot_time=$(awk '/btime/ {print $2}' /proc/stat)

# Выводим заголовок с форматированием столбцов
printf "%-10s %-25s %-10s %-10s %-10s %-10s %-20s %-s\n" "PID" "COMMAND" "STATE" "CPU%" "VIRT(MB)" "RSS(MB)" "LIFETIME" "CMD_PATH"

# Перебираем все директории в /proc, которые соответствуют PID (числовые)
for pid in /proc/[0-9]*; do
    pid=$(basename "$pid")
    
    # Проверяем, существует ли файл с информацией о процессе
    if [ -r "/proc/$pid/stat" ]; then
        stat_info=$(cat /proc/$pid/stat 2>/dev/null)
        comm=$(echo "$stat_info" | awk '{print $2}' | tr -d '()')
        state=$(echo "$stat_info" | awk '{print $3}')
        utime=$(echo "$stat_info" | awk '{print $14}') # Время процесса в тиках (user mode)
        stime=$(echo "$stat_info" | awk '{print $15}') # Время процесса в тиках (kernel mode)
        start_time_ticks=$(echo "$stat_info" | awk '{print $22}') # Время старта процесса в тиках

        hz=$(getconf CLK_TCK)  # Получаем количество тиков в секунду
        total_time=$((utime + stime))  # Общее время, проведённое процессом
        cpu_usage=$(echo "scale=2; ($total_time / $hz) / $uptime * 100" | bc -l 2>/dev/null || echo "0.00")  # Процент использования CPU

        # Получаем информацию о виртуальной и физической памяти из /proc/[PID]/statm
        if [ -r "/proc/$pid/statm" ]; then
            mem_info=$(cat /proc/$pid/statm 2>/dev/null)
            virt_pages=$(echo "$mem_info" | awk '{print $1}')   # Виртуальная память в страницах
            rss_pages=$(echo "$mem_info" | awk '{print $2}')    # Физическая память в страницах
            
            page_size=$(getconf PAGESIZE)  # Размер страницы в байтах
            virt_mb=$(echo "scale=2; $virt_pages * $page_size / 1024 / 1024" | bc -l 2>/dev/null || echo "0.00")  # Виртуальная память в МБ
            rss_mb=$(echo "scale=2; $rss_pages * $page_size / 1024 / 1024" | bc -l 2>/dev/null || echo "0.00")    # Физическая память в МБ
        else
            virt_mb=0
            rss_mb=0
        fi

        # Получаем путь до исполняемого файла
        if [ -L "/proc/$pid/exe" ]; then
            cmd_path=$(readlink -f "/proc/$pid/exe")
        else
            cmd_path="N/A"
        fi

        # Рассчитываем время жизни процесса
        process_start_time=$(echo "scale=0; $boot_time + ($start_time_ticks / $hz)" | bc -l 2>/dev/null || echo "0")  # Время старта процесса в секундах с момента UNIX Epoch
        current_time=$(date +%s)  # Текущее время в секундах UNIX
        lifetime_seconds=$(echo "$current_time - $process_start_time" | bc -l 2>/dev/null || echo "0")  # Время жизни процесса в секундах

        # Преобразуем время жизни в годы, дни, часы, минуты, секунды
        years=$((lifetime_seconds / 31536000))
        days=$(( (lifetime_seconds % 31536000) / 86400))
        hours=$(( (lifetime_seconds % 86400) / 3600))
        minutes=$(( (lifetime_seconds % 3600) / 60))
        seconds=$((lifetime_seconds % 60))
        lifetime=$(printf "%dY %dD %02d:%02d:%02d" "$years" "$days" "$hours" "$minutes" "$seconds")

        # Выводим информацию с форматированием
        printf "%-10s %-25s %-10s %-10s %-10s %-10s %-20s %-s\n" "$pid" "$comm" "$state" "$cpu_usage" "$virt_mb" "$rss_mb" "$lifetime" "$cmd_path"
    fi
done
