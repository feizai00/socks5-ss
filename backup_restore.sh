#!/bin/bash
# Xray SOCKS5 to Shadowsocks Converter - 备份恢复模块

# 导入配置
source "$(dirname "$0")/config.sh"

# 创建自动备份脚本
create_auto_backup_script() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CRON_BACKUP_SCRIPT" << 'EOF'
#!/bin/bash
# 自动备份脚本 - 由 setup_xray_converter.sh 创建

CONFIG_DIR="$HOME/.xray-converter"
SERVICE_DIR="$CONFIG_DIR/services"
BACKUP_DIR="$CONFIG_DIR/backups"
LOG_FILE="$CONFIG_DIR/xray-converter.log"

# 确保备份目录存在
mkdir -p "$BACKUP_DIR"

# 生成备份文件名（使用时间戳）
timestamp=$(date "+%Y%m%d_%H%M%S")
backup_file="$BACKUP_DIR/xray_services_auto_$timestamp.tar.gz"

# 如果没有服务配置，则退出
if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
    echo "$(date): 未找到任何服务配置，跳过备份。" >> "$LOG_FILE"
    exit 0
fi

# 创建备份
tar -czf "$backup_file" -C "$(dirname "$SERVICE_DIR")" "$(basename "$SERVICE_DIR")"

# 记录日志
if [ $? -eq 0 ]; then
    size=$(du -h "$backup_file" | cut -f1)
    service_count=$(find "$SERVICE_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    echo "$(date): 自动备份成功: $backup_file ($size, $service_count 个服务)" >> "$LOG_FILE"
    
    # 保留最近10个备份，删除旧备份
    ls -t "$BACKUP_DIR"/xray_services_auto_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm
    echo "$(date): 已清理旧备份，保留最近10个备份" >> "$LOG_FILE"
else
    echo "$(date): 自动备份失败" >> "$LOG_FILE"
fi
EOF

    # 添加执行权限
    chmod +x "$CRON_BACKUP_SCRIPT"
}

# 设置定时备份任务
setup_auto_backup() {
    clear_screen
    echo "--- 设置自动备份 ---"
    
    # 创建自动备份脚本
    create_auto_backup_script
    
    # 检查是否已设置cron任务
    if crontab -l 2>/dev/null | grep -q "$CRON_BACKUP_SCRIPT"; then
        echo "自动备份任务已存在。"
        crontab -l | grep "$CRON_BACKUP_SCRIPT"
        
        read -p "是否要修改备份频率? (y/N): " change_schedule
        if [[ ! "$change_schedule" =~ ^[yY]([eE][sS])?$ ]]; then
            press_any_key
            return
        fi
        
        # 删除现有任务
        crontab -l 2>/dev/null | grep -v "$CRON_BACKUP_SCRIPT" | crontab -
    fi
    
    echo "请选择自动备份频率:"
    echo "1) 每天 (凌晨3点)"
    echo "2) 每周 (周日凌晨3点)"
    echo "3) 每月 (1日凌晨3点)"
    echo "4) 自定义cron表达式"
    echo "5) 禁用自动备份"
    read -p "请选择 [1-5]: " backup_freq
    
    case $backup_freq in
        1) cron_expr="0 3 * * *" ;;
        2) cron_expr="0 3 * * 0" ;;
        3) cron_expr="0 3 1 * *" ;;
        4)
            read -p "请输入cron表达式 (例如: 0 3 * * *): " cron_expr
            ;;
        5)
            echo "已禁用自动备份。"
            press_any_key
            return
            ;;
        *) 
            echo "无效的选择，使用默认值 (每天凌晨3点)。"
            cron_expr="0 3 * * *"
            ;;
    esac
    
    # 添加新的cron任务
    (crontab -l 2>/dev/null; echo "$cron_expr $CRON_BACKUP_SCRIPT") | crontab -
    
    echo "✅ 自动备份已设置，将在以下时间执行: $cron_expr"
    echo "   备份脚本路径: $CRON_BACKUP_SCRIPT"
    echo "   备份将保存到: $BACKUP_DIR"
    echo "   只保留最近10个自动备份"
    
    log "已设置自动备份: $cron_expr"
    press_any_key
}

# 备份所有服务配置
backup_services() {
    clear_screen
    echo "--- 备份所有服务配置 ---"
    
    if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
        echo "未找到任何服务配置，无法进行备份。"
        press_any_key
        return
    fi
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 生成备份文件名（使用时间戳）
    local timestamp=$(date "+%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/xray_services_$timestamp.tar.gz"
    
    # 创建备份
    echo "正在备份所有服务配置..."
    tar -czf "$backup_file" -C "$(dirname "$SERVICE_DIR")" "$(basename "$SERVICE_DIR")"
    
    if [ $? -eq 0 ]; then
        echo "✅ 备份成功保存到: $backup_file"
        
        # 显示备份文件大小
        local size=$(du -h "$backup_file" | cut -f1)
        echo "备份文件大小: $size"
        
        # 计算服务数量
        local service_count=$(find "$SERVICE_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
        echo "已备份 $service_count 个服务的配置"
        
        log "已创建备份: $backup_file ($size, $service_count 个服务)"
    else
        echo "❌ 备份失败"
        log "备份失败: $backup_file"
    fi
    
    press_any_key
}

# 从备份恢复服务配置
restore_services() {
    clear_screen
    echo "--- 从备份恢复服务配置 ---"
    
    # 检查备份目录
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo "未找到任何备份文件。"
        press_any_key
        return
    fi
    
    # 列出所有备份文件
    echo "可用的备份文件:"
    local i=1
    local backup_files=()
    
    for file in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$file" ]; then
            local file_date=$(date -r "$file" "+%Y-%m-%d %H:%M:%S")
            local file_size=$(du -h "$file" | cut -f1)
            echo "[$i] $(basename "$file") ($file_date, $file_size)"
            backup_files+=("$file")
            i=$((i + 1))
        fi
    done
    
    # 选择备份文件
    read -p "请选择要恢复的备份文件编号 [1-$((i-1))]: " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
        echo "无效的选择。"
        press_any_key
        return
    fi
    
    local selected_backup="${backup_files[$((choice-1))]}"
    
    # 确认恢复操作
    echo "您选择了: $(basename "$selected_backup")"
    echo "警告: 恢复操作将覆盖当前的所有服务配置。"
    read -p "是否继续? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
        echo "操作已取消。"
        press_any_key
        return
    fi
    
    # 停止所有现有容器
    echo "正在停止所有现有服务..."
    for port_dir in "$SERVICE_DIR"/*; do
        if [ -d "$port_dir" ]; then
            local port=$(basename "$port_dir")
            local container_name="xray-converter-$port"
            $DOCKER_CMD stop "$container_name" > /dev/null 2>&1
            $DOCKER_CMD rm "$container_name" > /dev/null 2>&1
        fi
    done
    
    # 备份当前配置（以防万一）
    if [ -d "$SERVICE_DIR" ] && [ -n "$(ls -A "$SERVICE_DIR" 2>/dev/null)" ]; then
        local timestamp=$(date "+%Y%m%d_%H%M%S")
        local auto_backup="$BACKUP_DIR/auto_before_restore_$timestamp.tar.gz"
        echo "正在创建当前配置的自动备份..."
        tar -czf "$auto_backup" -C "$(dirname "$SERVICE_DIR")" "$(basename "$SERVICE_DIR")"
        echo "当前配置已备份到: $auto_backup"
    fi
    
    # 恢复备份
    echo "正在恢复备份..."
    rm -rf "$SERVICE_DIR"
    mkdir -p "$(dirname "$SERVICE_DIR")"
    tar -xzf "$selected_backup" -C "$(dirname "$SERVICE_DIR")"
    
    if [ $? -eq 0 ]; then
        echo "✅ 备份恢复成功"
        log "已从备份恢复: $(basename "$selected_backup")"
        
        # 重新创建所有容器
        echo "正在重新创建所有服务容器..."
        
        # 确保 Docker 网络存在
        if ! check_docker_network; then
            echo "创建 Docker 网络..."
            create_docker_network
        fi
        
        local success=0
        local failed=0
        
        for port_dir in "$SERVICE_DIR"/*; do
            if [ -d "$port_dir" ]; then
                local port=$(basename "$port_dir")
                echo -n "正在创建服务 (端口: $port)... "
                
                if repair_service "$port"; then
                    echo "✅ 成功"
                    success=$((success + 1))
                else
                    echo "❌ 失败"
                    failed=$((failed + 1))
                fi
            fi
        done
        
        echo ""
        echo "服务恢复完成:"
        echo "- 成功: $success 个服务"
        echo "- 失败: $failed 个服务"
        
        if [ $failed -gt 0 ]; then
            echo "部分服务恢复失败，请使用「一键修复所有服务」功能尝试修复。"
        fi
    else
        echo "❌ 备份恢复失败"
        log "备份恢复失败: $(basename "$selected_backup")"
    fi
    
    press_any_key
}

# 导出服务配置
export_services() {
    clear_screen
    echo "--- 导出服务配置 ---"
    
    if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
        echo "未找到任何服务。"
        press_any_key
        return
    fi
    
    echo "请选择导出方式:"
    echo "1) 导出所有服务"
    echo "2) 导出单个服务"
    read -p "请选择 [1-2]: " export_mode
    
    if [ "$export_mode" != "1" ] && [ "$export_mode" != "2" ]; then
        echo "无效的选择。"
        press_any_key
        return
    fi
    
    local selected_port=""
    
    if [ "$export_mode" = "2" ]; then
        # 列出所有服务
        echo "可导出的服务列表:"
        local i=1
        local ports=()
        
        for port_dir in "$SERVICE_DIR"/*; do
            if [ -d "$port_dir" ]; then
                local port=$(basename "$port_dir")
                echo "[$i] 端口: $port"
                ports+=("$port")
                i=$((i + 1))
            fi
        done
        
        read -p "请选择要导出的服务编号 [1-$((i-1))]: " choice
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
            echo "无效的选择。"
            press_any_key
            return
        fi
        
        selected_port="${ports[$((choice-1))]}"
    fi
    
    echo "请选择导出格式:"
    echo "1) 纯文本格式 (易于阅读)"
    echo "2) JSON格式 (可用于导入)"
    read -p "请选择 [1-2]: " format_choice
    
    if [ "$format_choice" != "1" ] && [ "$format_choice" != "2" ]; then
        echo "无效的选择。"
        press_any_key
        return
    fi
    
    # 生成导出文件名
    local timestamp=$(date "+%Y%m%d_%H%M%S")
    local export_file=""
    
    if [ "$export_mode" = "1" ]; then
        export_file="$CONFIG_DIR/export_all_services_$timestamp.txt"
        if [ "$format_choice" = "2" ]; then
            export_file="$CONFIG_DIR/export_all_services_$timestamp.json"
        fi
    else
        export_file="$CONFIG_DIR/export_service_${selected_port}_$timestamp.txt"
        if [ "$format_choice" = "2" ]; then
            export_file="$CONFIG_DIR/export_service_${selected_port}_$timestamp.json"
        fi
    fi
    
    # 创建导出文件
    > "$export_file"
    
    if [ "$format_choice" = "1" ]; then
        # 纯文本格式
        echo "# Xray SOCKS5 -> Shadowsocks 服务配置导出" >> "$export_file"
        echo "# 导出时间: $(date)" >> "$export_file"
        echo "# 格式: 服务端口,密码,SOCKS5代理列表" >> "$export_file"
        echo "" >> "$export_file"
        
        if [ "$export_mode" = "1" ]; then
            # 导出所有服务
            for port_dir in "$SERVICE_DIR"/*; do
                if [ -d "$port_dir" ]; then
                    local port=$(basename "$port_dir")
                    local info_file="$port_dir/info"
                    
                    if [ -f "$info_file" ]; then
                        source "$info_file"
                        echo "服务端口: $port" >> "$export_file"
                        echo "密码: $PASSWORD" >> "$export_file"
                        echo "SOCKS5代理:" >> "$export_file"
                        
                        IFS=',' read -ra SOCKS_INFO_ARRAY <<< "$SOCKS_IPS"
                        for socks_info in "${SOCKS_INFO_ARRAY[@]}"; do
                            [ -z "$socks_info" ] && continue
                            echo "  - $socks_info" >> "$export_file"
                        done
                        
                        echo "" >> "$export_file"
                    fi
                fi
            done
        else
            # 导出单个服务
            local info_file="$SERVICE_DIR/$selected_port/info"
            
            if [ -f "$info_file" ]; then
                source "$info_file"
                echo "服务端口: $selected_port" >> "$export_file"
                echo "密码: $PASSWORD" >> "$export_file"
                echo "SOCKS5代理:" >> "$export_file"
                
                IFS=',' read -ra SOCKS_INFO_ARRAY <<< "$SOCKS_IPS"
                for socks_info in "${SOCKS_INFO_ARRAY[@]}"; do
                    [ -z "$socks_info" ] && continue
                    echo "  - $socks_info" >> "$export_file"
                done
            fi
        fi
    else
        # JSON格式
        if [ "$export_mode" = "1" ]; then
            # 导出所有服务
            echo "{" >> "$export_file"
            echo "  \"services\": [" >> "$export_file"
            
            local first=true
            for port_dir in "$SERVICE_DIR"/*; do
                if [ -d "$port_dir" ]; then
                    local port=$(basename "$port_dir")
                    local info_file="$port_dir/info"
                    
                    if [ -f "$info_file" ]; then
                        source "$info_file"
                        
                        if [ "$first" = true ]; then
                            first=false
                        else
                            echo "    }," >> "$export_file"
                        fi
                        
                        echo "    {" >> "$export_file"
                        echo "      \"port\": $port," >> "$export_file"
                        echo "      \"password\": \"$PASSWORD\"," >> "$export_file"
                        echo "      \"proxies\": [" >> "$export_file"
                        
                        IFS=',' read -ra SOCKS_INFO_ARRAY <<< "$SOCKS_IPS"
                        local proxy_first=true
                        for socks_info in "${SOCKS_INFO_ARRAY[@]}"; do
                            [ -z "$socks_info" ] && continue
                            
                            if [ "$proxy_first" = true ]; then
                                proxy_first=false
                            else
                                echo "        }," >> "$export_file"
                            fi
                            
                            IFS=':' read -ra PARTS <<< "$socks_info"
                            echo "        {" >> "$export_file"
                            echo "          \"address\": \"${PARTS[0]}\"," >> "$export_file"
                            echo "          \"port\": ${PARTS[1]}" >> "$export_file"
                            
                            if [ ${#PARTS[@]} -ge 4 ]; then
                                echo "          ," >> "$export_file"
                                echo "          \"user\": \"${PARTS[2]}\"," >> "$export_file"
                                echo "          \"pass\": \"${PARTS[3]}\"" >> "$export_file"
                            fi
                        done
                        
                        if [ ${#SOCKS_INFO_ARRAY[@]} -gt 0 ]; then
                            echo "        }" >> "$export_file"
                        fi
                        
                        echo "      ]" >> "$export_file"
                    fi
                fi
            done
            
            if [ "$first" = false ]; then
                echo "    }" >> "$export_file"
            fi
            
            echo "  ]" >> "$export_file"
            echo "}" >> "$export_file"
        else
            # 导出单个服务
            local info_file="$SERVICE_DIR/$selected_port/info"
            
            if [ -f "$info_file" ]; then
                source "$info_file"
                
                echo "{" >> "$export_file"
                echo "  \"port\": $selected_port," >> "$export_file"
                echo "  \"password\": \"$PASSWORD\"," >> "$export_file"
                echo "  \"proxies\": [" >> "$export_file"
                
                IFS=',' read -ra SOCKS_INFO_ARRAY <<< "$SOCKS_IPS"
                local proxy_first=true
                for socks_info in "${SOCKS_INFO_ARRAY[@]}"; do
                    [ -z "$socks_info" ] && continue
                    
                    if [ "$proxy_first" = true ]; then
                        proxy_first=false
                    else
                        echo "    }," >> "$export_file"
                    fi
                    
                    IFS=':' read -ra PARTS <<< "$socks_info"
                    echo "    {" >> "$export_file"
                    echo "      \"address\": \"${PARTS[0]}\"," >> "$export_file"
                    echo "      \"port\": ${PARTS[1]}" >> "$export_file"
                    
                    if [ ${#PARTS[@]} -ge 4 ]; then
                        echo "      ," >> "$export_file"
                        echo "      \"user\": \"${PARTS[2]}\"," >> "$export_file"
                        echo "      \"pass\": \"${PARTS[3]}\"" >> "$export_file"
                    fi
                done
                
                if [ ${#SOCKS_INFO_ARRAY[@]} -gt 0 ]; then
                    echo "    }" >> "$export_file"
                fi
                
                echo "  ]" >> "$export_file"
                echo "}" >> "$export_file"
            fi
        fi
    fi
    
    echo "✅ 配置已导出到: $export_file"
    log "已导出服务配置到: $export_file"
    
    press_any_key
} 