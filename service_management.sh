#!/bin/bash
# Xray SOCKS5 to Shadowsocks Converter - 服务管理模块

# 导入配置
source "$(dirname "$0")/config.sh"

# 添加一个新的转换服务
add_service() {
    clear_screen
    echo "--- 添加新的 Shadowsocks 转换服务 ---"
    
    # 获取 SS 配置
    echo "首先，请配置您的 Shadowsocks 服务端。"
    if command_exists shuf; then
        RANDOM_PORT=$(shuf -i 10000-60000 -n 1)
    else
        RANDOM_PORT=$((10000 + RANDOM % 50001))
    fi
    if command_exists openssl; then
        RANDOM_PASSWORD=$(openssl rand -base64 12)
    else
        RANDOM_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    fi

    read -p "请输入 Shadowsocks 监听端口 [默认: $RANDOM_PORT]: " SHADOWSOCKS_PORT
    SHADOWSOCKS_PORT=${SHADOWSOCKS_PORT:-$RANDOM_PORT}
    
    # 检查端口是否已被占用
    if [ -d "$SERVICE_DIR/$SHADOWSOCKS_PORT" ]; then
        echo "错误: 端口 $SHADOWSOCKS_PORT 已被占用，请选择其他端口。"
        press_any_key
        return
    fi

    read -p "请输入 Shadowsocks 密码 [默认: $RANDOM_PASSWORD]: " SHADOWSOCKS_PASSWORD
    SHADOWSOCKS_PASSWORD=${SHADOWSOCKS_PASSWORD:-$RANDOM_PASSWORD}
    SHADOWSOCKS_METHOD="aes-256-gcm"
    echo "加密方法将使用: $SHADOWSOCKS_METHOD"

    # 设置服务失效时间
    echo "---"
    echo "请设置服务失效时间:"
    echo "1) 永久有效"
    echo "2) 一个月"
    echo "3) 三个月"
    echo "4) 六个月"
    echo "5) 一年"
    echo "6) 自定义天数"
    read -p "请选择 [1-6]: " expiry_choice
    
    local expiry_timestamp=""
    case $expiry_choice in
        1) expiry_timestamp="" ;;
        2) expiry_timestamp=$(calculate_expiry_timestamp 30) ;;
        3) expiry_timestamp=$(calculate_expiry_timestamp 90) ;;
        4) expiry_timestamp=$(calculate_expiry_timestamp 180) ;;
        5) expiry_timestamp=$(calculate_expiry_timestamp 365) ;;
        6) 
            read -p "请输入有效天数: " custom_days
            if [[ "$custom_days" =~ ^[0-9]+$ ]] && [ "$custom_days" -gt 0 ]; then
                expiry_timestamp=$(calculate_expiry_timestamp "$custom_days")
            else
                echo "无效的天数，将设置为永久有效。"
                expiry_timestamp=""
            fi
            ;;
        *) 
            echo "无效的选择，将设置为永久有效。"
            expiry_timestamp=""
            ;;
    esac
    
    if [ -n "$expiry_timestamp" ]; then
        echo "服务将于 $(format_date "$expiry_timestamp") 失效"
    else
        echo "服务将永久有效"
    fi

    # 获取 SOCKS5 配置
    echo "---"
    echo "接下来，请依次输入您的 SOCKS5 代理信息。"
    declare -a SOCKS_SERVERS_ARRAY=()
    declare -a SOCKS_INFO_ARRAY=()
    local count=1
    while true; do
        echo "---"
        echo "配置第 $count 个 SOCKS5 代理:"
        read -p "请输入 SOCKS5 IP 地址: " address
        read -p "请输入 SOCKS5 端口: " port
        SOCKS_INFO_ARRAY+=("${address}:${port}")

        local user_json=""
        read -p "此代理是否需要用户名/密码认证? (y/N): " needs_auth
        if [[ "$needs_auth" =~ ^[yY]([eE][sS])?$ ]]; then
            read -p "请输入用户名: " user
            read -s -p "请输入密码: " pass
            echo ""
            user_json="\"users\": [{\"user\": \"$user\", \"pass\": \"$pass\"}]"
        fi

        local server_json="{\"address\": \"$address\", \"port\": $port"
        [ -n "$user_json" ] && server_json="$server_json, $user_json"
        server_json="$server_json}"
        SOCKS_SERVERS_ARRAY+=("$server_json")

        read -p "是否要添加另一个 SOCKS5 代理? (Y/n): " add_another
        if [[ "$add_another" =~ ^[nN][oO]?$ ]]; then break; fi
        count=$((count + 1))
    done
    SOCKS_SERVERS_JSON=$(printf ",%s" "${SOCKS_SERVERS_ARRAY[@]}")
    SOCKS_SERVERS_JSON=${SOCKS_SERVERS_JSON:1}

    # 创建服务目录和配置文件
    local current_service_dir="$SERVICE_DIR/$SHADOWSOCKS_PORT"
    mkdir -p "$current_service_dir"
    
    # 写入元数据文件，方便查看
    echo "PASSWORD=$SHADOWSOCKS_PASSWORD" > "$current_service_dir/info"
    echo "SOCKS_IPS=$(printf "%s," "${SOCKS_INFO_ARRAY[@]}")" >> "$current_service_dir/info"
    echo "CREATED_AT=$(get_current_timestamp)" >> "$current_service_dir/info"
    [ -n "$expiry_timestamp" ] && echo "EXPIRES_AT=$expiry_timestamp" >> "$current_service_dir/info"
    echo "STATUS=active" >> "$current_service_dir/info"

    # 生成 config.json
    cat > "$current_service_dir/config.json" <<EOF
{
    "inbounds": [{"port": $SHADOWSOCKS_PORT, "protocol": "shadowsocks", "settings": {"method": "$SHADOWSOCKS_METHOD", "password": "$SHADOWSOCKS_PASSWORD", "network": "tcp,udp"}, "tag": "ss-in"}],
    "outbounds": [{"protocol": "socks", "settings": {"servers": [$SOCKS_SERVERS_JSON]}, "tag": "socks-out"}],
    "routing": {"rules": [{"type": "field", "inboundTag": ["ss-in"], "outboundTag": "socks-out"}]}
}
EOF

    # 开放防火墙端口
    open_firewall_port "$SHADOWSOCKS_PORT"

    # 启动 Docker 容器
    local container_name="xray-converter-$SHADOWSOCKS_PORT"
    echo ">> 正在启动容器 '$container_name'..."
    $DOCKER_CMD run -d --name "$container_name" --network "$DOCKER_NETWORK" --restart always -v "$current_service_dir/config.json:/etc/xray/config.json" -p "$SHADOWSOCKS_PORT:$SHADOWSOCKS_PORT/tcp" -p "$SHADOWSOCKS_PORT:$SHADOWSOCKS_PORT/udp" teddysun/xray > /dev/null

    echo ">> 服务配置成功！正在生成连接信息..."
    sleep 2
    view_service_info "$SHADOWSOCKS_PORT" "true"
}

# 列出现有的所有服务
list_services() {
    clear_screen
    echo "--- 当前已配置的服务列表 ---"
    if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
        echo "未找到任何服务。"
    else
        printf "%-10s %-15s %-15s %-20s %s\n" "SS 端口" "状态" "失效时间" "后端代理" "备注"
        echo "--------------------------------------------------------------------------------"
        for port_dir in "$SERVICE_DIR"/*; do
            if [ -d "$port_dir" ]; then
                local port=$(basename "$port_dir")
                local container_name="xray-converter-$port"
                local status=$(check_service_status "$port")
                local socks_ips=""
                local expiry_date="永久"
                local service_status="active"
                
                if [ -f "$port_dir/info" ]; then
                    source "$port_dir/info"
                    socks_ips=$(echo "$SOCKS_IPS" | cut -d',' -f1)
                    
                    # 检查是否有失效时间
                    if [ -n "$EXPIRES_AT" ]; then
                        expiry_date=$(format_date "$EXPIRES_AT")
                        
                        # 检查是否已过期
                        local current_time=$(get_current_timestamp)
                        if [ "$current_time" -gt "$EXPIRES_AT" ]; then
                            service_status="expired"
                        fi
                    fi
                    
                    # 如果info文件中有状态，则使用该状态
                    [ -n "$STATUS" ] && service_status="$STATUS"
                else
                    socks_ips="配置丢失"
                fi
                
                # 状态显示美化
                local status_display="$status"
                if [ "$status" = "running" ]; then
                    if [ "$service_status" = "expired" ]; then
                        status_display="已过期"
                    else
                        status_display="运行中"
                    fi
                elif [ "$status" = "stopped" ]; then
                    status_display="已停止"
                elif [ "$status" = "missing" ]; then
                    status_display="容器丢失"
                fi
                
                # 如果是回收站中的服务，标记状态
                if [ "$service_status" = "recycled" ]; then
                    status_display="回收站"
                fi
                
                printf "%-10s %-15s %-15s %-20s %s\n" "$port" "$status_display" "$expiry_date" "$socks_ips" "${REMARK:-}"
            fi
        done
        
        # 显示回收站中的服务
        if [ -d "$RECYCLE_BIN_DIR" ] && [ -n "$(ls -A $RECYCLE_BIN_DIR 2>/dev/null)" ]; then
            echo ""
            echo "--- 回收站中的服务 ---"
            printf "%-10s %-15s %-15s %-20s %s\n" "SS 端口" "状态" "失效时间" "后端代理" "备注"
            echo "--------------------------------------------------------------------------------"
            
            for port_dir in "$RECYCLE_BIN_DIR"/*; do
                if [ -d "$port_dir" ]; then
                    local port=$(basename "$port_dir")
                    local info_file="$port_dir/info"
                    local socks_ips=""
                    local expiry_date="永久"
                    
                    if [ -f "$info_file" ]; then
                        source "$info_file"
                        socks_ips=$(echo "$SOCKS_IPS" | cut -d',' -f1)
                        
                        # 检查是否有失效时间
                        if [ -n "$EXPIRES_AT" ]; then
                            expiry_date=$(format_date "$EXPIRES_AT")
                        fi
                    else
                        socks_ips="配置丢失"
                    fi
                    
                    printf "%-10s %-15s %-15s %-20s %s\n" "$port" "已回收" "$expiry_date" "$socks_ips" "${REMARK:-}"
                fi
            done
        fi
    fi
    press_any_key
}

# 查看指定服务的连接信息
view_service_info() {
    clear_screen
    local port_to_view=$1
    local no_pause=${2:-"false"}
    local from_recycle=${3:-"false"}
    
    if [ -z "$port_to_view" ]; then
        echo "--- 查看服务连接信息 ---"
        read -p "请输入要查看的服务的 SS 端口号: " port_to_view
    fi

    local info_dir="$SERVICE_DIR/$port_to_view"
    # 如果指定了从回收站查看，或者服务目录中不存在该服务
    if [ "$from_recycle" = "true" ] || [ ! -d "$info_dir" ]; then
        if [ -d "$RECYCLE_BIN_DIR/$port_to_view" ]; then
            info_dir="$RECYCLE_BIN_DIR/$port_to_view"
        fi
    fi
    
    local info_file="$info_dir/info"
    if [ ! -f "$info_file" ]; then
        echo "错误: 未找到端口为 $port_to_view 的服务。"
        [ "$no_pause" = "false" ] && press_any_key
        return
    fi
    
    source "$info_file"
    PUBLIC_IP=$(curl -s --max-time 5 http://whatismyip.akamai.com || curl -s --max-time 5 http://api.ipify.org)
    [ -z "$PUBLIC_IP" ] && PUBLIC_IP="<your_server_ip>"
    
    SS_INFO_RAW="aes-256-gcm:${PASSWORD}@${PUBLIC_IP}:${port_to_view}"
    SS_URI="ss://$(echo -n "$SS_INFO_RAW" | base64 -w 0)"

    echo ""
    echo "--- 服务端口: $port_to_view ---"
    echo "服务器地址:  $PUBLIC_IP"
    echo "服务器端口:     $port_to_view"
    echo "密码:        $PASSWORD"
    echo "加密方法:      aes-256-gcm"
    
    # 显示创建时间和失效时间
    if [ -n "$CREATED_AT" ]; then
        echo "创建时间:    $(format_date "$CREATED_AT")"
    fi
    
    if [ -n "$EXPIRES_AT" ]; then
        echo "失效时间:    $(format_date "$EXPIRES_AT")"
        
        # 检查是否已过期
        local current_time=$(get_current_timestamp)
        if [ "$current_time" -gt "$EXPIRES_AT" ]; then
            echo "状态:        已过期"
        else
            local days_left=$(( (EXPIRES_AT - current_time) / 86400 ))
            echo "剩余天数:    $days_left 天"
        fi
    else
        echo "失效时间:    永久有效"
    fi
    
    # 显示备注信息
    if [ -n "$REMARK" ]; then
        echo "备注:        $REMARK"
    fi
    
    echo "--------------------------------"
    echo "SS 链接: $SS_URI"
    echo "二维码:"
    qrencode -t ANSIUTF8 -o - "$SS_URI"
    
    # 显示服务状态
    if [ "$from_recycle" = "true" ] || [ -d "$RECYCLE_BIN_DIR/$port_to_view" ]; then
        echo "--------------------------------"
        echo "服务状态: 已回收 (在回收站中)"
    else
        local status=$(check_service_status "$port_to_view")
        echo "--------------------------------"
        echo "服务状态: $status"
    fi
    
    if [ "$no_pause" = "false" ]; then
        press_any_key
    else
        # 在 add_service 调用后也暂停，以便用户查看信息
        press_any_key
    fi
}

# 停止/启动一个服务
manage_service_state() {
    clear_screen
    local action=$1 # "stop" or "start"
    echo "--- ${action^} 一个服务 ---"
    read -p "请输入要 $action 的服务的 SS 端口号: " port
    local container_name="xray-converter-$port"

    if ! $DOCKER_CMD ps -a -f "name=$container_name" --format "{{.Names}}" | grep -q "$container_name"; then
        echo "错误: 未找到与端口 $port 对应的服务。"
    else
        echo "正在 $action 容器 '$container_name'..."
        $DOCKER_CMD "$action" "$container_name" > /dev/null
        echo "服务已 $action。"
    fi
    press_any_key
}

# 删除一个服务
delete_service() {
    clear_screen
    echo "--- 删除一个服务 ---"
    read -p "请输入要删除的服务的 SS 端口号: " port
    local container_name="xray-converter-$port"
    local service_config_dir="$SERVICE_DIR/$port"

    if [ ! -d "$service_config_dir" ]; then
        echo "错误: 未找到与端口 $port 对应的服务配置。"
    else
        read -p "是否将服务移至回收站? (Y/n): " move_to_recycle
        
        if [[ "$move_to_recycle" =~ ^[nN][oO]?$ ]]; then
            read -p "警告: 这将永久删除该服务及其配置。确定吗? (y/N): " confirm
            if [[ "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
                echo "正在停止并移除容器 '$container_name'..."
                $DOCKER_CMD stop "$container_name" > /dev/null 2>&1
                $DOCKER_CMD rm "$container_name" > /dev/null 2>&1
                echo "正在删除配置文件..."
                rm -rf "$service_config_dir"
                echo "服务 $port 已被成功删除。"
                log "已永久删除服务: $port"
            else
                echo "操作已取消。"
            fi
        else
            # 移动到回收站
            echo "正在停止容器 '$container_name'..."
            $DOCKER_CMD stop "$container_name" > /dev/null 2>&1
            $DOCKER_CMD rm "$container_name" > /dev/null 2>&1
            
            # 确保回收站目录存在
            mkdir -p "$RECYCLE_BIN_DIR/$port"
            
            # 复制配置文件到回收站
            cp -r "$service_config_dir"/* "$RECYCLE_BIN_DIR/$port/"
            
            # 更新服务状态
            local info_file="$RECYCLE_BIN_DIR/$port/info"
            if [ -f "$info_file" ]; then
                sed -i "s/^STATUS=.*$/STATUS=recycled/" "$info_file" 2>/dev/null || \
                sed -i '' "s/^STATUS=.*$/STATUS=recycled/" "$info_file"
                
                # 记录回收时间
                echo "RECYCLED_AT=$(get_current_timestamp)" >> "$info_file"
            fi
            
            # 删除原服务目录
            rm -rf "$service_config_dir"
            
            echo "服务 $port 已被移至回收站。"
            log "已将服务 $port 移至回收站"
        fi
    fi
    press_any_key
} 

# 编辑现有服务
edit_service() {
    clear_screen
    echo "--- 编辑现有服务 ---"
    
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
            local container_name="xray-converter-$port"
            local status=$(check_service_status "$port")
            
            # 读取服务信息
            local info_file="$port_dir/info"
            local password=""
            local socks_ips=""
            
            if [ -f "$info_file" ]; then
                password=$(grep "PASSWORD=" "$info_file" | cut -d'=' -f2)
                socks_ips=$(grep "SOCKS_IPS=" "$info_file" | cut -d'=' -f2 | sed 's/,$//')
            fi
            
            echo "[$i] 端口: $port, 状态: $status, 密码: $password"
            ports+=("$port")
            i=$((i + 1))
        fi
    done
    
    read -p "请选择要编辑的服务编号 [1-$((i-1))]: " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
        echo "无效的选择。"
        press_any_key
        return
    fi
    
    local selected_port="${ports[$((choice-1))]}"
    local container_name="xray-converter-$selected_port"
    local current_dir="$SERVICE_DIR/$selected_port"
    local info_file="$current_dir/info"
    local config_file="$current_dir/config.json"
    
    if [ ! -f "$info_file" ] || [ ! -f "$config_file" ]; then
        echo "错误: 服务配置文件不完整。"
        press_any_key
        return
    fi
    
    # 读取当前配置
    source "$info_file"
    local current_password="$PASSWORD"
    local current_socks_ips="$SOCKS_IPS"
    
    echo ""
    echo "当前服务配置:"
    echo "端口: $selected_port"
    echo "密码: $current_password"
    echo "后端SOCKS5代理: $current_socks_ips"
    echo ""
    
    echo "编辑选项:"
    echo "1) 修改密码"
    echo "2) 修改后端SOCKS5代理"
    echo "3) 修改端口 (将创建新服务并删除旧服务)"
    echo "4) 返回主菜单"
    read -p "请选择 [1-4]: " edit_option
    
    case $edit_option in
        1)
            read -p "请输入新密码 [默认: $current_password]: " new_password
            new_password=${new_password:-$current_password}
            
            # 更新info文件
            sed -i "s/^PASSWORD=.*$/PASSWORD=$new_password/" "$info_file" 2>/dev/null || sed -i '' "s/^PASSWORD=.*$/PASSWORD=$new_password/" "$info_file"
            
            # 更新config.json (需要用jq或手动解析)
            if command_exists jq; then
                # 使用jq更新配置
                local temp_config=$(mktemp)
                jq --arg pwd "$new_password" '.inbounds[0].settings.password = $pwd' "$config_file" > "$temp_config"
                mv "$temp_config" "$config_file"
            else
                # 手动替换密码字段
                sed -i "s/\"password\": \"[^\"]*\"/\"password\": \"$new_password\"/" "$config_file" 2>/dev/null || \
                sed -i '' "s/\"password\": \"[^\"]*\"/\"password\": \"$new_password\"/" "$config_file"
            fi
            
            echo "✅ 密码已更新。"
            log "已更新服务 $selected_port 的密码"
            
            # 重启容器以应用更改
            $DOCKER_CMD restart "$container_name" > /dev/null
            echo "✅ 服务已重启，新配置已生效。"
            ;;
            
        2)
            echo "当前后端SOCKS5代理:"
            IFS=',' read -ra SOCKS_INFO_ARRAY <<< "$current_socks_ips"
            for idx in "${!SOCKS_INFO_ARRAY[@]}"; do
                echo "[$((idx+1))] ${SOCKS_INFO_ARRAY[$idx]}"
            done
            
            echo ""
            echo "SOCKS5代理编辑选项:"
            echo "a) 添加新代理"
            echo "d) 删除代理"
            echo "r) 替换所有代理"
            echo "c) 取消"
            read -p "请选择 [a/d/r/c]: " socks_option
            
            case $socks_option in
                a|A)
                    # 添加新代理
                    declare -a new_socks_servers_array=()
                    declare -a new_socks_info_array=("${SOCKS_INFO_ARRAY[@]}")
                    
                    echo "添加新的SOCKS5代理:"
                    read -p "请输入SOCKS5 IP地址: " address
                    read -p "请输入SOCKS5端口: " port
                    
                    local user_json=""
                    local socks_info="${address}:${port}"
                    
                    read -p "此代理是否需要用户名/密码认证? (y/N): " needs_auth
                    if [[ "$needs_auth" =~ ^[yY]([eE][sS])?$ ]]; then
                        read -p "请输入用户名: " user
                        read -s -p "请输入密码: " pass
                        echo ""
                        user_json=", \"users\": [{\"user\": \"$user\", \"pass\": \"$pass\"}]"
                        socks_info="${address}:${port}:${user}:${pass}"
                    fi
                    
                    local server_json="{\"address\": \"$address\", \"port\": $port$user_json}"
                    new_socks_info_array+=("$socks_info")
                    
                    # 更新info文件
                    new_socks_ips=$(printf "%s," "${new_socks_info_array[@]}")
                    sed -i "s/^SOCKS_IPS=.*$/SOCKS_IPS=$new_socks_ips/" "$info_file" 2>/dev/null || \
                    sed -i '' "s/^SOCKS_IPS=.*$/SOCKS_IPS=$new_socks_ips/" "$info_file"
                    
                    # 更新config.json
                    if command_exists jq; then
                        # 读取当前服务器配置
                        local current_servers=$(jq '.outbounds[0].settings.servers' "$config_file")
                        # 移除最后的 ] 并添加新服务器
                        current_servers="${current_servers%]}, $server_json]"
                        # 更新配置文件
                        local temp_config=$(mktemp)
                        jq --argjson servers "$current_servers" '.outbounds[0].settings.servers = $servers' "$config_file" > "$temp_config"
                        mv "$temp_config" "$config_file"
                    else
                        # 手动更新配置文件（这种方法不太可靠，建议安装jq）
                        local config_content=$(cat "$config_file")
                        # 找到 "servers": [ 后的位置
                        local servers_pos=$(echo "$config_content" | grep -n "\"servers\":" | cut -d':' -f1)
                        if [ -n "$servers_pos" ]; then
                            # 找到第一个 ] 的位置
                            local bracket_pos=$(echo "$config_content" | tail -n +$servers_pos | grep -n "]" | head -1 | cut -d':' -f1)
                            if [ -n "$bracket_pos" ]; then
                                bracket_pos=$((servers_pos + bracket_pos - 1))
                                # 在 ] 前插入新服务器
                                local new_config="${config_content:0:$bracket_pos-1}, $server_json${config_content:$bracket_pos-1}"
                                echo "$new_config" > "$config_file"
                            fi
                        fi
                    fi
                    
                    echo "✅ 已添加新的SOCKS5代理。"
                    log "已为服务 $selected_port 添加SOCKS5代理: $socks_info"
                    ;;
                    
                d|D)
                    # 删除代理
                    if [ ${#SOCKS_INFO_ARRAY[@]} -le 1 ]; then
                        echo "❌ 至少需要保留一个SOCKS5代理。"
                    else
                        read -p "请输入要删除的代理编号 [1-${#SOCKS_INFO_ARRAY[@]}]: " del_idx
                        if [[ "$del_idx" =~ ^[0-9]+$ ]] && [ "$del_idx" -ge 1 ] && [ "$del_idx" -le ${#SOCKS_INFO_ARRAY[@]} ]; then
                            del_idx=$((del_idx - 1))
                            
                            # 更新info文件
                            unset 'SOCKS_INFO_ARRAY[$del_idx]'
                            new_socks_ips=$(printf "%s," "${SOCKS_INFO_ARRAY[@]}")
                            sed -i "s/^SOCKS_IPS=.*$/SOCKS_IPS=$new_socks_ips/" "$info_file" 2>/dev/null || \
                            sed -i '' "s/^SOCKS_IPS=.*$/SOCKS_IPS=$new_socks_ips/" "$info_file"
                            
                            # 更新config.json
                            if command_exists jq; then
                                local temp_config=$(mktemp)
                                jq "del(.outbounds[0].settings.servers[$del_idx])" "$config_file" > "$temp_config"
                                mv "$temp_config" "$config_file"
                            else
                                echo "❌ 无法删除代理，请安装jq工具。"
                                press_any_key
                                return
                            fi
                            
                            echo "✅ 已删除SOCKS5代理。"
                            log "已从服务 $selected_port 删除SOCKS5代理"
                        else
                            echo "❌ 无效的代理编号。"
                        fi
                    fi
                    ;;
                    
                r|R)
                    # 替换所有代理
                    echo "请输入新的SOCKS5代理列表，将替换所有现有代理。"
                    declare -a new_socks_servers_array=()
                    declare -a new_socks_info_array=()
                    local count=1
                    
                    while true; do
                        echo "---"
                        echo "配置第 $count 个SOCKS5代理:"
                        read -p "请输入SOCKS5 IP地址: " address
                        read -p "请输入SOCKS5端口: " port
                        
                        local user_json=""
                        local socks_info="${address}:${port}"
                        
                        read -p "此代理是否需要用户名/密码认证? (y/N): " needs_auth
                        if [[ "$needs_auth" =~ ^[yY]([eE][sS])?$ ]]; then
                            read -p "请输入用户名: " user
                            read -s -p "请输入密码: " pass
                            echo ""
                            user_json=", \"users\": [{\"user\": \"$user\", \"pass\": \"$pass\"}]"
                            socks_info="${address}:${port}:${user}:${pass}"
                        fi
                        
                        local server_json="{\"address\": \"$address\", \"port\": $port$user_json}"
                        new_socks_servers_array+=("$server_json")
                        new_socks_info_array+=("$socks_info")
                        
                        read -p "是否要添加另一个SOCKS5代理? (Y/n): " add_another
                        if [[ "$add_another" =~ ^[nN][oO]?$ ]]; then break; fi
                        count=$((count + 1))
                    done
                    
                    # 更新info文件
                    new_socks_ips=$(printf "%s," "${new_socks_info_array[@]}")
                    sed -i "s/^SOCKS_IPS=.*$/SOCKS_IPS=$new_socks_ips/" "$info_file" 2>/dev/null || \
                    sed -i '' "s/^SOCKS_IPS=.*$/SOCKS_IPS=$new_socks_ips/" "$info_file"
                    
                    # 更新config.json
                    local socks_servers_json=$(printf ",%s" "${new_socks_servers_array[@]}")
                    socks_servers_json=${socks_servers_json:1}
                    
                    # 创建新的config.json
                    cat > "$config_file" <<EOF
{
    "inbounds": [{"port": $selected_port, "protocol": "shadowsocks", "settings": {"method": "aes-256-gcm", "password": "$current_password", "network": "tcp,udp"}, "tag": "ss-in"}],
    "outbounds": [{"protocol": "socks", "settings": {"servers": [$socks_servers_json]}, "tag": "socks-out"}],
    "routing": {"rules": [{"type": "field", "inboundTag": ["ss-in"], "outboundTag": "socks-out"}]}
}
EOF
                    
                    echo "✅ 已替换所有SOCKS5代理。"
                    log "已替换服务 $selected_port 的所有SOCKS5代理"
                    ;;
                    
                c|C)
                    echo "已取消编辑。"
                    press_any_key
                    return
                    ;;
                    
                *)
                    echo "无效的选择。"
                    press_any_key
                    return
                    ;;
            esac
            
            # 重启容器以应用更改
            $DOCKER_CMD restart "$container_name" > /dev/null
            echo "✅ 服务已重启，新配置已生效。"
            ;;
            
        3)
            # 修改端口
            read -p "请输入新端口 [默认: $selected_port]: " new_port
            new_port=${new_port:-$selected_port}
            
            if [ "$new_port" = "$selected_port" ]; then
                echo "端口未变更，无需修改。"
                press_any_key
                return
            fi
            
            # 检查端口是否已被占用
            if [ -d "$SERVICE_DIR/$new_port" ]; then
                echo "❌ 错误: 端口 $new_port 已被占用，请选择其他端口。"
                press_any_key
                return
            fi
            
            # 停止并删除旧容器
            echo "正在停止旧服务..."
            $DOCKER_CMD stop "$container_name" > /dev/null
            $DOCKER_CMD rm "$container_name" > /dev/null
            
            # 创建新服务目录
            mkdir -p "$SERVICE_DIR/$new_port"
            
            # 复制并修改配置文件
            cp "$info_file" "$SERVICE_DIR/$new_port/info"
            
            # 创建新的config.json
            cat > "$SERVICE_DIR/$new_port/config.json" <<EOF
{
    "inbounds": [{"port": $new_port, "protocol": "shadowsocks", "settings": {"method": "aes-256-gcm", "password": "$current_password", "network": "tcp,udp"}, "tag": "ss-in"}],
    "outbounds": [{"protocol": "socks", "settings": {"servers": $(jq '.outbounds[0].settings.servers' "$config_file")}, "tag": "socks-out"}],
    "routing": {"rules": [{"type": "field", "inboundTag": ["ss-in"], "outboundTag": "socks-out"}]}
}
EOF
            
            # 开放防火墙端口
            open_firewall_port "$new_port"
            
            # 启动新容器
            local new_container_name="xray-converter-$new_port"
            echo "正在启动新服务 '$new_container_name'..."
            $DOCKER_CMD run -d --name "$new_container_name" --network "$DOCKER_NETWORK" --restart always \
                -v "$SERVICE_DIR/$new_port/config.json:/etc/xray/config.json" \
                -p "$new_port:$new_port/tcp" -p "$new_port:$new_port/udp" \
                teddysun/xray > /dev/null
            
            # 删除旧服务目录
            rm -rf "$current_dir"
            
            echo "✅ 服务端口已从 $selected_port 更改为 $new_port。"
            log "已将服务端口从 $selected_port 更改为 $new_port"
            ;;
            
        4)
            echo "已取消编辑。"
            ;;
            
        *)
            echo "无效的选择。"
            ;;
    esac
    
    press_any_key
} 