#!/bin/bash
# Xray SOCKS5 to Shadowsocks Converter - 有效期管理模块

# 导入配置
source "$(dirname "$0")/config.sh"

# 创建检查过期服务的脚本
create_expiry_check_script() {
    mkdir -p "$CONFIG_DIR"
    cat > "$EXPIRY_CHECK_SCRIPT" << 'EOF'
#!/bin/bash
# 检查服务过期脚本 - 由 setup_xray_converter.sh 创建

CONFIG_DIR="$HOME/.xray-converter"
SERVICE_DIR="$CONFIG_DIR/services"
RECYCLE_BIN_DIR="$CONFIG_DIR/recycle_bin"
LOG_FILE="$CONFIG_DIR/xray-converter.log"

# 确保目录存在
mkdir -p "$SERVICE_DIR"
mkdir -p "$RECYCLE_BIN_DIR"

# 日志函数
log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# 获取当前时间戳
current_timestamp=$(date +%s)
log "开始检查过期服务..."

# 检查所有服务
expired_count=0
for port_dir in "$SERVICE_DIR"/*; do
    if [ -d "$port_dir" ]; then
        port=$(basename "$port_dir")
        info_file="$port_dir/info"
        
        if [ -f "$info_file" ]; then
            # 读取服务信息
            source "$info_file"
            
            # 检查是否有失效时间且已过期
            if [ -n "$EXPIRES_AT" ] && [ "$current_timestamp" -gt "$EXPIRES_AT" ]; then
                log "服务 $port 已过期，正在停止并移至回收站..."
                
                # 更新状态
                sed -i "s/^STATUS=.*$/STATUS=expired/" "$info_file" 2>/dev/null || \
                sed -i '' "s/^STATUS=.*$/STATUS=expired/" "$info_file"
                
                # 停止容器
                docker stop "xray-converter-$port" > /dev/null 2>&1
                docker rm "xray-converter-$port" > /dev/null 2>&1
                
                # 移动到回收站
                mkdir -p "$RECYCLE_BIN_DIR/$port"
                cp -r "$port_dir"/* "$RECYCLE_BIN_DIR/$port/"
                
                # 更新回收站中的服务状态
                sed -i "s/^STATUS=.*$/STATUS=recycled/" "$RECYCLE_BIN_DIR/$port/info" 2>/dev/null || \
                sed -i '' "s/^STATUS=.*$/STATUS=recycled/" "$RECYCLE_BIN_DIR/$port/info"
                
                # 记录回收时间
                echo "RECYCLED_AT=$current_timestamp" >> "$RECYCLE_BIN_DIR/$port/info"
                
                expired_count=$((expired_count + 1))
            fi
        fi
    fi
done

log "检查完成，共发现 $expired_count 个过期服务并已移至回收站"
EOF

    # 添加执行权限
    chmod +x "$EXPIRY_CHECK_SCRIPT"
}

# 设置定时检查过期服务
setup_expiry_check() {
    clear_screen
    echo "--- 设置自动检查过期服务 ---"
    
    # 创建检查脚本
    create_expiry_check_script
    
    # 检查是否已设置cron任务
    if crontab -l 2>/dev/null | grep -q "$EXPIRY_CHECK_SCRIPT"; then
        echo "自动检查过期服务任务已存在。"
        crontab -l | grep "$EXPIRY_CHECK_SCRIPT"
        
        read -p "是否要修改检查频率? (y/N): " change_schedule
        if [[ ! "$change_schedule" =~ ^[yY]([eE][sS])?$ ]]; then
            press_any_key
            return
        fi
        
        # 删除现有任务
        crontab -l 2>/dev/null | grep -v "$EXPIRY_CHECK_SCRIPT" | crontab -
    fi
    
    echo "请选择检查频率:"
    echo "1) 每天 (凌晨1点)"
    echo "2) 每12小时"
    echo "3) 每小时"
    echo "4) 自定义cron表达式"
    echo "5) 禁用自动检查"
    read -p "请选择 [1-5]: " check_freq
    
    case $check_freq in
        1) cron_expr="0 1 * * *" ;;
        2) cron_expr="0 */12 * * *" ;;
        3) cron_expr="0 * * * *" ;;
        4)
            read -p "请输入cron表达式 (例如: 0 1 * * *): " cron_expr
            ;;
        5)
            echo "已禁用自动检查过期服务。"
            press_any_key
            return
            ;;
        *) 
            echo "无效的选择，使用默认值 (每天凌晨1点)。"
            cron_expr="0 1 * * *"
            ;;
    esac
    
    # 添加新的cron任务
    (crontab -l 2>/dev/null; echo "$cron_expr $EXPIRY_CHECK_SCRIPT") | crontab -
    
    echo "✅ 自动检查过期服务已设置，将在以下时间执行: $cron_expr"
    echo "   检查脚本路径: $EXPIRY_CHECK_SCRIPT"
    
    log "已设置自动检查过期服务: $cron_expr"
    press_any_key
}

# 手动检查过期服务
check_expired_services() {
    clear_screen
    echo "--- 检查过期服务 ---"
    
    # 确保脚本存在
    create_expiry_check_script
    
    echo "正在检查过期服务..."
    bash "$EXPIRY_CHECK_SCRIPT"
    
    echo "✅ 检查完成，过期服务已被停止并移至回收站"
    echo "   详细信息请查看日志: $LOG_FILE"
    
    press_any_key
}

# 管理回收站
manage_recycle_bin() {
    while true; do
        clear_screen
        echo "--- 回收站管理 ---"
        
        # 检查回收站是否为空
        if [ ! -d "$RECYCLE_BIN_DIR" ] || [ -z "$(ls -A $RECYCLE_BIN_DIR 2>/dev/null)" ]; then
            echo "回收站为空。"
            press_any_key
            return
        fi
        
        echo "回收站中的服务:"
        local i=1
        local ports=()
        
        for port_dir in "$RECYCLE_BIN_DIR"/*; do
            if [ -d "$port_dir" ]; then
                local port=$(basename "$port_dir")
                local info_file="$port_dir/info"
                local expiry_date="永久"
                local recycled_date="未知"
                
                if [ -f "$info_file" ]; then
                    source "$info_file"
                    [ -n "$EXPIRES_AT" ] && expiry_date=$(format_date "$EXPIRES_AT")
                    [ -n "$RECYCLED_AT" ] && recycled_date=$(format_date "$RECYCLED_AT")
                fi
                
                echo "[$i] 端口: $port, 失效时间: $expiry_date, 回收时间: $recycled_date"
                ports+=("$port")
                i=$((i + 1))
            fi
        done
        
        echo ""
        echo "选项:"
        echo "1) 查看服务详情"
        echo "2) 恢复服务"
        echo "3) 延长服务有效期并恢复"
        echo "4) 永久删除服务"
        echo "5) 清空回收站"
        echo "6) 返回主菜单"
        read -p "请选择 [1-6]: " recycle_option
        
        case $recycle_option in
            1)
                if [ ${#ports[@]} -eq 0 ]; then
                    echo "回收站为空。"
                    press_any_key
                    continue
                fi
                
                read -p "请选择要查看的服务编号 [1-$((i-1))]: " choice
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
                    echo "无效的选择。"
                    press_any_key
                    continue
                fi
                
                # 调用service_management.sh中的view_service_info函数
                view_service_info "${ports[$((choice-1))]}" "false" "true"
                ;;
                
            2)
                if [ ${#ports[@]} -eq 0 ]; then
                    echo "回收站为空。"
                    press_any_key
                    continue
                fi
                
                read -p "请选择要恢复的服务编号 [1-$((i-1))]: " choice
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
                    echo "无效的选择。"
                    press_any_key
                    continue
                fi
                
                restore_service "${ports[$((choice-1))]}" "false"
                ;;
                
            3)
                if [ ${#ports[@]} -eq 0 ]; then
                    echo "回收站为空。"
                    press_any_key
                    continue
                fi
                
                read -p "请选择要延长有效期并恢复的服务编号 [1-$((i-1))]: " choice
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
                    echo "无效的选择。"
                    press_any_key
                    continue
                fi
                
                restore_service "${ports[$((choice-1))]}" "true"
                ;;
                
            4)
                if [ ${#ports[@]} -eq 0 ]; then
                    echo "回收站为空。"
                    press_any_key
                    continue
                fi
                
                read -p "请选择要永久删除的服务编号 [1-$((i-1))]: " choice
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
                    echo "无效的选择。"
                    press_any_key
                    continue
                fi
                
                local port_to_delete="${ports[$((choice-1))]}"
                read -p "警告: 这将永久删除该服务及其配置。确定吗? (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
                    rm -rf "$RECYCLE_BIN_DIR/$port_to_delete"
                    echo "✅ 服务 $port_to_delete 已被永久删除。"
                    log "已永久删除回收站中的服务: $port_to_delete"
                    press_any_key
                fi
                ;;
                
            5)
                read -p "警告: 这将永久删除回收站中的所有服务。确定吗? (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
                    rm -rf "$RECYCLE_BIN_DIR"/*
                    mkdir -p "$RECYCLE_BIN_DIR"
                    echo "✅ 回收站已清空。"
                    log "已清空回收站"
                    press_any_key
                    return
                fi
                ;;
                
            6)
                return
                ;;
                
            *)
                echo "无效的选择。"
                press_any_key
                ;;
        esac
    done
}

# 恢复回收站中的服务
restore_service() {
    local port_to_restore=$1
    local extend_expiry=$2
    
    if [ ! -d "$RECYCLE_BIN_DIR/$port_to_restore" ]; then
        echo "错误: 未找到端口为 $port_to_restore 的回收服务。"
        press_any_key
        return
    fi
    
    # 如果需要延长有效期
    if [ "$extend_expiry" = "true" ]; then
        local info_file="$RECYCLE_BIN_DIR/$port_to_restore/info"
        if [ -f "$info_file" ]; then
            source "$info_file"
            
            echo "当前服务信息:"
            if [ -n "$EXPIRES_AT" ]; then
                echo "失效时间: $(format_date "$EXPIRES_AT")"
            else
                echo "失效时间: 永久有效"
            fi
            
            echo "---"
            echo "请选择新的有效期:"
            echo "1) 永久有效"
            echo "2) 一个月"
            echo "3) 三个月"
            echo "4) 六个月"
            echo "5) 一年"
            echo "6) 自定义天数"
            read -p "请选择 [1-6]: " expiry_choice
            
            local new_expiry_timestamp=""
            case $expiry_choice in
                1) new_expiry_timestamp="" ;;
                2) new_expiry_timestamp=$(calculate_expiry_timestamp 30) ;;
                3) new_expiry_timestamp=$(calculate_expiry_timestamp 90) ;;
                4) new_expiry_timestamp=$(calculate_expiry_timestamp 180) ;;
                5) new_expiry_timestamp=$(calculate_expiry_timestamp 365) ;;
                6) 
                    read -p "请输入有效天数: " custom_days
                    if [[ "$custom_days" =~ ^[0-9]+$ ]] && [ "$custom_days" -gt 0 ]; then
                        new_expiry_timestamp=$(calculate_expiry_timestamp "$custom_days")
                    else
                        echo "无效的天数，将设置为永久有效。"
                        new_expiry_timestamp=""
                    fi
                    ;;
                *) 
                    echo "无效的选择，将保持原有设置。"
                    new_expiry_timestamp="$EXPIRES_AT"
                    ;;
            esac
            
            # 更新失效时间
            if [ -n "$new_expiry_timestamp" ]; then
                sed -i "s/^EXPIRES_AT=.*$/EXPIRES_AT=$new_expiry_timestamp/" "$info_file" 2>/dev/null || \
                sed -i '' "s/^EXPIRES_AT=.*$/EXPIRES_AT=$new_expiry_timestamp/" "$info_file"
                echo "服务有效期已更新至: $(format_date "$new_expiry_timestamp")"
            else
                sed -i "/^EXPIRES_AT=/d" "$info_file" 2>/dev/null || \
                sed -i '' "/^EXPIRES_AT=/d" "$info_file"
                echo "服务已设置为永久有效"
            fi
        fi
    fi
    
    # 恢复服务
    echo "正在恢复服务..."
    
    # 确保服务目录存在
    mkdir -p "$SERVICE_DIR/$port_to_restore"
    
    # 复制配置文件
    cp -r "$RECYCLE_BIN_DIR/$port_to_restore"/* "$SERVICE_DIR/$port_to_restore/"
    
    # 更新服务状态
    local info_file="$SERVICE_DIR/$port_to_restore/info"
    sed -i "s/^STATUS=.*$/STATUS=active/" "$info_file" 2>/dev/null || \
    sed -i '' "s/^STATUS=.*$/STATUS=active/" "$info_file"
    
    # 启动容器
    local container_name="xray-converter-$port_to_restore"
    local config_path="$SERVICE_DIR/$port_to_restore/config.json"
    
    $DOCKER_CMD run -d --name "$container_name" --network "$DOCKER_NETWORK" --restart always \
        -v "$config_path:/etc/xray/config.json" \
        -p "$port_to_restore:$port_to_restore/tcp" -p "$port_to_restore:$port_to_restore/udp" \
        teddysun/xray > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ 服务 $port_to_restore 已成功恢复并启动"
        log "已从回收站恢复服务: $port_to_restore"
        
        # 删除回收站中的服务
        rm -rf "$RECYCLE_BIN_DIR/$port_to_restore"
    else
        echo "❌ 服务恢复失败，请检查日志"
        log "恢复服务失败: $port_to_restore"
    fi
    
    press_any_key
}

# 修改服务有效期
modify_service_expiry() {
    clear_screen
    echo "--- 修改服务有效期 ---"
    
    if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
        echo "未找到任何服务。"
        press_any_key
        return
    fi
    
    # 列出所有服务
    echo "可编辑的服务列表:"
    local i=1
    local ports=()
    
    for port_dir in "$SERVICE_DIR"/*; do
        if [ -d "$port_dir" ]; then
            local port=$(basename "$port_dir")
            local info_file="$port_dir/info"
            local expiry_date="永久"
            
            if [ -f "$info_file" ]; then
                source "$info_file"
                [ -n "$EXPIRES_AT" ] && expiry_date=$(format_date "$EXPIRES_AT")
            fi
            
            echo "[$i] 端口: $port, 当前有效期至: $expiry_date"
            ports+=("$port")
            i=$((i + 1))
        fi
    done
    
    read -p "请选择要修改的服务编号 [1-$((i-1))]: " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
        echo "无效的选择。"
        press_any_key
        return
    fi
    
    local selected_port="${ports[$((choice-1))]}"
    local info_file="$SERVICE_DIR/$selected_port/info"
    
    if [ ! -f "$info_file" ]; then
        echo "错误: 服务配置文件不完整。"
        press_any_key
        return
    fi
    
    # 读取当前配置
    source "$info_file"
    
    echo "---"
    echo "请选择新的有效期:"
    echo "1) 永久有效"
    echo "2) 一个月"
    echo "3) 三个月"
    echo "4) 六个月"
    echo "5) 一年"
    echo "6) 自定义天数"
    read -p "请选择 [1-6]: " expiry_choice
    
    local new_expiry_timestamp=""
    case $expiry_choice in
        1) new_expiry_timestamp="" ;;
        2) new_expiry_timestamp=$(calculate_expiry_timestamp 30) ;;
        3) new_expiry_timestamp=$(calculate_expiry_timestamp 90) ;;
        4) new_expiry_timestamp=$(calculate_expiry_timestamp 180) ;;
        5) new_expiry_timestamp=$(calculate_expiry_timestamp 365) ;;
        6) 
            read -p "请输入有效天数: " custom_days
            if [[ "$custom_days" =~ ^[0-9]+$ ]] && [ "$custom_days" -gt 0 ]; then
                new_expiry_timestamp=$(calculate_expiry_timestamp "$custom_days")
            else
                echo "无效的天数，将设置为永久有效。"
                new_expiry_timestamp=""
            fi
            ;;
        *) 
            echo "无效的选择，将保持原有设置。"
            if [ -n "$EXPIRES_AT" ]; then
                new_expiry_timestamp="$EXPIRES_AT"
            else
                new_expiry_timestamp=""
            fi
            ;;
    esac
    
    # 更新失效时间
    if [ -n "$new_expiry_timestamp" ]; then
        if grep -q "^EXPIRES_AT=" "$info_file"; then
            sed -i "s/^EXPIRES_AT=.*$/EXPIRES_AT=$new_expiry_timestamp/" "$info_file" 2>/dev/null || \
            sed -i '' "s/^EXPIRES_AT=.*$/EXPIRES_AT=$new_expiry_timestamp/" "$info_file"
        else
            echo "EXPIRES_AT=$new_expiry_timestamp" >> "$info_file"
        fi
        echo "✅ 服务有效期已更新至: $(format_date "$new_expiry_timestamp")"
    else
        sed -i "/^EXPIRES_AT=/d" "$info_file" 2>/dev/null || \
        sed -i '' "/^EXPIRES_AT=/d" "$info_file"
        echo "✅ 服务已设置为永久有效"
    fi
    
    log "已修改服务 $selected_port 的有效期"
    press_any_key
}

# 添加/修改服务备注
add_service_remark() {
    clear_screen
    echo "--- 添加/修改服务备注 ---"
    
    if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
        echo "未找到任何服务。"
        press_any_key
        return
    fi
    
    # 列出所有服务
    echo "可编辑的服务列表:"
    local i=1
    local ports=()
    
    for port_dir in "$SERVICE_DIR"/*; do
        if [ -d "$port_dir" ]; then
            local port=$(basename "$port_dir")
            local info_file="$port_dir/info"
            local remark=""
            
            if [ -f "$info_file" ]; then
                source "$info_file"
                remark="${REMARK:-无}"
            fi
            
            echo "[$i] 端口: $port, 当前备注: $remark"
            ports+=("$port")
            i=$((i + 1))
        fi
    done
    
    read -p "请选择要添加/修改备注的服务编号 [1-$((i-1))]: " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
        echo "无效的选择。"
        press_any_key
        return
    fi
    
    local selected_port="${ports[$((choice-1))]}"
    local info_file="$SERVICE_DIR/$selected_port/info"
    
    if [ ! -f "$info_file" ]; then
        echo "错误: 服务配置文件不完整。"
        press_any_key
        return
    fi
    
    # 读取当前配置
    source "$info_file"
    
    read -p "请输入新的备注 (留空删除备注): " new_remark
    
    # 更新备注
    if [ -n "$new_remark" ]; then
        if grep -q "^REMARK=" "$info_file"; then
            sed -i "s/^REMARK=.*$/REMARK=\"$new_remark\"/" "$info_file" 2>/dev/null || \
            sed -i '' "s/^REMARK=.*$/REMARK=\"$new_remark\"/" "$info_file"
        else
            echo "REMARK=\"$new_remark\"" >> "$info_file"
        fi
        echo "✅ 服务备注已更新为: $new_remark"
    else
        sed -i "/^REMARK=/d" "$info_file" 2>/dev/null || \
        sed -i '' "/^REMARK=/d" "$info_file"
        echo "✅ 服务备注已删除"
    fi
    
    log "已修改服务 $selected_port 的备注"
    press_any_key
} 