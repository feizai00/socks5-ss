#!/bin/bash
# Xray SOCKS5 to Shadowsocks Converter - 安全管理模块

# 导入配置
source "$(dirname "$0")/config.sh"

# 管理IP白名单
manage_ip_whitelist() {
    clear_screen
    echo "--- 管理IP白名单 ---"
    
    # 确保白名单文件存在
    mkdir -p "$CONFIG_DIR"
    touch "$ALLOWED_IPS_FILE"
    
    # 显示当前白名单
    echo "当前允许访问的IP地址:"
    if [ -s "$ALLOWED_IPS_FILE" ]; then
        cat "$ALLOWED_IPS_FILE" | nl
    else
        echo "   (空白名单，允许所有IP访问)"
    fi
    
    echo ""
    echo "选项:"
    echo "1) 添加IP地址"
    echo "2) 删除IP地址"
    echo "3) 清空白名单 (允许所有IP)"
    echo "4) 添加当前IP"
    echo "5) 返回主菜单"
    read -p "请选择 [1-5]: " ip_option
    
    case $ip_option in
        1)
            read -p "请输入要添加的IP地址或CIDR (例如: 192.168.1.1 或 192.168.1.0/24): " new_ip
            if [[ -n "$new_ip" ]]; then
                if ! grep -q "^$new_ip$" "$ALLOWED_IPS_FILE"; then
                    echo "$new_ip" >> "$ALLOWED_IPS_FILE"
                    echo "✅ 已添加IP: $new_ip"
                    log "已添加IP白名单: $new_ip"
                else
                    echo "IP已存在于白名单中。"
                fi
            fi
            ;;
        2)
            if [ -s "$ALLOWED_IPS_FILE" ]; then
                read -p "请输入要删除的IP编号: " ip_num
                if [[ "$ip_num" =~ ^[0-9]+$ ]]; then
                    ip_to_delete=$(sed -n "${ip_num}p" "$ALLOWED_IPS_FILE")
                    if [ -n "$ip_to_delete" ]; then
                        sed -i "${ip_num}d" "$ALLOWED_IPS_FILE" 2>/dev/null || sed -i '' "${ip_num}d" "$ALLOWED_IPS_FILE"
                        echo "✅ 已删除IP: $ip_to_delete"
                        log "已从白名单删除IP: $ip_to_delete"
                    else
                        echo "无效的编号。"
                    fi
                else
                    echo "请输入有效的数字。"
                fi
            else
                echo "白名单为空。"
            fi
            ;;
        3)
            read -p "确定要清空白名单吗? 这将允许所有IP访问 (y/N): " confirm
            if [[ "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
                > "$ALLOWED_IPS_FILE"
                echo "✅ 已清空白名单，现在允许所有IP访问。"
                log "已清空IP白名单"
            fi
            ;;
        4)
            current_ip=$(curl -s --max-time 5 http://whatismyip.akamai.com || curl -s --max-time 5 http://api.ipify.org)
            if [ -n "$current_ip" ]; then
                if ! grep -q "^$current_ip$" "$ALLOWED_IPS_FILE"; then
                    echo "$current_ip" >> "$ALLOWED_IPS_FILE"
                    echo "✅ 已添加当前IP: $current_ip"
                    log "已添加当前IP到白名单: $current_ip"
                else
                    echo "当前IP已存在于白名单中。"
                fi
            else
                echo "❌ 无法获取当前IP地址。"
            fi
            ;;
        5)
            return
            ;;
        *)
            echo "无效的选择。"
            ;;
    esac
    
    # 如果有IP白名单，配置防火墙
    if [ -s "$ALLOWED_IPS_FILE" ]; then
        echo ""
        echo "IP白名单已更新。请确保手动配置防火墙规则。"
        echo "建议配置方法:"
        echo "1. 对于 SSH 端口 (通常是22):"
        echo "   sudo ufw allow from <IP地址> to any port 22"
        echo ""
        echo "2. 对于其他管理端口 (如Web管理界面):"
        echo "   sudo ufw allow from <IP地址> to any port <端口号>"
        echo ""
        echo "3. 应用防火墙规则:"
        echo "   sudo ufw enable"
        echo "   sudo ufw reload"
    fi
    
    press_any_key
}

# 批量导入SOCKS5代理
batch_import_proxies() {
    clear_screen
    echo "--- 批量导入SOCKS5代理 ---"
    
    echo "请选择导入模式:"
    echo "1) 创建新服务"
    echo "2) 更新现有服务"
    read -p "请选择 [1-2]: " import_mode
    
    if [ "$import_mode" != "1" ] && [ "$import_mode" != "2" ]; then
        echo "无效的选择。"
        press_any_key
        return
    fi
    
    if [ "$import_mode" = "2" ]; then
        # 列出所有服务
        if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
            echo "未找到任何服务。"
            press_any_key
            return
        fi
        
        echo "可更新的服务列表:"
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
        
        read -p "请选择要更新的服务编号 [1-$((i-1))]: " choice
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((i-1)) ]; then
            echo "无效的选择。"
            press_any_key
            return
        fi
        
        selected_port="${ports[$((choice-1))]}"
    else
        # 创建新服务，需要设置端口和密码
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

        read -p "请输入Shadowsocks端口 [默认: $RANDOM_PORT]: " selected_port
        selected_port=${selected_port:-$RANDOM_PORT}
        
        # 检查端口是否已被占用
        if [ -d "$SERVICE_DIR/$selected_port" ]; then
            echo "错误: 端口 $selected_port 已被占用，请选择其他端口。"
            press_any_key
            return
        fi

        read -p "请输入Shadowsocks密码 [默认: $RANDOM_PASSWORD]: " ss_password
        ss_password=${ss_password:-$RANDOM_PASSWORD}
    fi
    
    echo ""
    echo "请选择导入方式:"
    echo "1) 从文件导入"
    echo "2) 手动输入"
    read -p "请选择 [1-2]: " input_mode
    
    declare -a socks_servers_array=()
    declare -a socks_info_array=()
    
    if [ "$input_mode" = "1" ]; then
        # 从文件导入
        read -p "请输入代理列表文件路径: " proxy_file
        
        if [ ! -f "$proxy_file" ]; then
            echo "错误: 文件不存在。"
            press_any_key
            return
        fi
        
        echo "正在从文件导入代理..."
        echo "支持的格式:"
        echo "1. IP:端口"
        echo "2. IP:端口:用户名:密码"
        echo ""
        
        while IFS= read -r line || [ -n "$line" ]; do
            # 跳过空行和注释行
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # 解析代理信息
            IFS=':' read -ra parts <<< "$line"
            
            if [ ${#parts[@]} -lt 2 ]; then
                echo "警告: 忽略无效行: $line"
                continue
            fi
            
            local address="${parts[0]}"
            local port="${parts[1]}"
            local socks_info="${address}:${port}"
            local server_json="{\"address\": \"$address\", \"port\": $port"
            
            # 如果有用户名和密码
            if [ ${#parts[@]} -ge 4 ]; then
                local user="${parts[2]}"
                local pass="${parts[3]}"
                server_json="$server_json, \"users\": [{\"user\": \"$user\", \"pass\": \"$pass\"}]"
                socks_info="${address}:${port}:${user}:${pass}"
            fi
            
            server_json="$server_json}"
            socks_servers_array+=("$server_json")
            socks_info_array+=("$socks_info")
            
            echo "已添加: $socks_info"
        done < "$proxy_file"
    else
        # 手动输入
        echo "请依次输入SOCKS5代理信息，输入空行结束。"
        echo "格式: IP:端口 或 IP:端口:用户名:密码"
        echo ""
        
        while true; do
            read -p "代理 #$((${#socks_info_array[@]}+1)) (留空结束): " proxy_line
            
            # 如果输入为空，结束输入
            [ -z "$proxy_line" ] && break
            
            # 解析代理信息
            IFS=':' read -ra parts <<< "$proxy_line"
            
            if [ ${#parts[@]} -lt 2 ]; then
                echo "警告: 格式无效，请重新输入。"
                continue
            fi
            
            local address="${parts[0]}"
            local port="${parts[1]}"
            local socks_info="${address}:${port}"
            local server_json="{\"address\": \"$address\", \"port\": $port"
            
            # 如果有用户名和密码
            if [ ${#parts[@]} -ge 4 ]; then
                local user="${parts[2]}"
                local pass="${parts[3]}"
                server_json="$server_json, \"users\": [{\"user\": \"$user\", \"pass\": \"$pass\"}]"
                socks_info="${address}:${port}:${user}:${pass}"
            fi
            
            server_json="$server_json}"
            socks_servers_array+=("$server_json")
            socks_info_array+=("$socks_info")
            
            echo "已添加: $socks_info"
        done
    fi
    
    # 检查是否有代理被添加
    if [ ${#socks_servers_array[@]} -eq 0 ]; then
        echo "没有添加任何代理，操作取消。"
        press_any_key
        return
    fi
    
    # 生成JSON配置
    local socks_servers_json=$(printf ",%s" "${socks_servers_array[@]}")
    socks_servers_json=${socks_servers_json:1}
    
    # 生成SOCKS_IPS字符串
    local socks_ips=$(printf "%s," "${socks_info_array[@]}")
    
    if [ "$import_mode" = "2" ]; then
        # 更新现有服务
        local container_name="xray-converter-$selected_port"
        local current_dir="$SERVICE_DIR/$selected_port"
        local info_file="$current_dir/info"
        local config_file="$current_dir/config.json"
        
        if [ ! -f "$info_file" ] || [ ! -f "$config_file" ]; then
            echo "错误: 服务配置文件不完整。"
            press_any_key
            return
        fi
        
        # 读取当前密码
        source "$info_file"
        local current_password="$PASSWORD"
        
        # 更新info文件
        sed -i "s/^SOCKS_IPS=.*$/SOCKS_IPS=$socks_ips/" "$info_file" 2>/dev/null || \
        sed -i '' "s/^SOCKS_IPS=.*$/SOCKS_IPS=$socks_ips/" "$info_file"
        
        # 创建新的config.json
        cat > "$config_file" <<EOF
{
    "inbounds": [{"port": $selected_port, "protocol": "shadowsocks", "settings": {"method": "aes-256-gcm", "password": "$current_password", "network": "tcp,udp"}, "tag": "ss-in"}],
    "outbounds": [{"protocol": "socks", "settings": {"servers": [$socks_servers_json]}, "tag": "socks-out"}],
    "routing": {"rules": [{"type": "field", "inboundTag": ["ss-in"], "outboundTag": "socks-out"}]}
}
EOF
        
        # 重启容器以应用更改
        $DOCKER_CMD restart "$container_name" > /dev/null
        
        echo "✅ 已更新服务 $selected_port 的SOCKS5代理列表。"
        log "已更新服务 $selected_port 的SOCKS5代理列表，共 ${#socks_info_array[@]} 个代理"
    else
        # 创建新服务
        local current_service_dir="$SERVICE_DIR/$selected_port"
        mkdir -p "$current_service_dir"
        
        # 写入元数据文件
        echo "PASSWORD=$ss_password" > "$current_service_dir/info"
        echo "SOCKS_IPS=$socks_ips" >> "$current_service_dir/info"
        echo "CREATED_AT=$(get_current_timestamp)" >> "$current_service_dir/info"
        echo "STATUS=active" >> "$current_service_dir/info"
        
        # 生成config.json
        cat > "$current_service_dir/config.json" <<EOF
{
    "inbounds": [{"port": $selected_port, "protocol": "shadowsocks", "settings": {"method": "aes-256-gcm", "password": "$ss_password", "network": "tcp,udp"}, "tag": "ss-in"}],
    "outbounds": [{"protocol": "socks", "settings": {"servers": [$socks_servers_json]}, "tag": "socks-out"}],
    "routing": {"rules": [{"type": "field", "inboundTag": ["ss-in"], "outboundTag": "socks-out"}]}
}
EOF
        
        # 开放防火墙端口
        open_firewall_port "$selected_port"
        
        # 启动Docker容器
        local container_name="xray-converter-$selected_port"
        echo "正在启动容器 '$container_name'..."
        $DOCKER_CMD run -d --name "$container_name" --network "$DOCKER_NETWORK" --restart always \
            -v "$current_service_dir/config.json:/etc/xray/config.json" \
            -p "$selected_port:$selected_port/tcp" -p "$selected_port:$selected_port/udp" \
            teddysun/xray > /dev/null
        
        echo "✅ 已创建新服务 $selected_port，包含 ${#socks_info_array[@]} 个SOCKS5代理。"
        log "已创建新服务 $selected_port，包含 ${#socks_info_array[@]} 个SOCKS5代理"
    fi
    
    press_any_key
} 