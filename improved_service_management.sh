#!/bin/bash
# 改进的服务管理模块示例

# 导入配置
source "$(dirname "$0")/config.sh"

# 改进的添加服务函数
add_service_improved() {
    clear_screen
    log $LOG_LEVEL_INFO "开始添加新的 Shadowsocks 转换服务"
    
    # 输入验证和错误处理
    local shadowsocks_port=""
    local shadowsocks_password=""
    local socks_servers=()
    
    # 获取并验证端口
    while true; do
        local random_port
        if command_exists shuf; then
            random_port=$(shuf -i 10000-60000 -n 1)
        else
            random_port=$((10000 + RANDOM % 50001))
        fi
        
        read -p "请输入 Shadowsocks 监听端口 [默认: $random_port]: " shadowsocks_port
        shadowsocks_port=${shadowsocks_port:-$random_port}
        
        if validate_port "$shadowsocks_port"; then
            if [ ! -d "$SERVICE_DIR/$shadowsocks_port" ]; then
                break
            else
                echo "错误: 端口 $shadowsocks_port 已被占用，请选择其他端口。"
            fi
        else
            echo "错误: 无效的端口号，请输入 1-65535 之间的数字。"
        fi
    done
    
    # 生成安全密码
    local default_password=$(generate_secure_password 16)
    read -p "请输入 Shadowsocks 密码 [默认: $default_password]: " shadowsocks_password
    shadowsocks_password=${shadowsocks_password:-$default_password}
    
    # 验证密码强度
    if [ ${#shadowsocks_password} -lt 8 ]; then
        log $LOG_LEVEL_WARN "密码长度较短，建议使用至少8位字符"
    fi
    
    # 获取SOCKS5配置（带验证）
    echo "---"
    echo "接下来，请配置 SOCKS5 代理信息。"
    
    local count=1
    while true; do
        echo "---"
        echo "配置第 $count 个 SOCKS5 代理:"
        
        local socks_ip=""
        local socks_port=""
        
        # 验证IP地址
        while true; do
            read -p "请输入 SOCKS5 IP 地址: " socks_ip
            if validate_ip "$socks_ip" || [[ "$socks_ip" =~ ^[a-zA-Z0-9.-]+$ ]]; then
                break
            else
                echo "错误: 无效的IP地址或域名格式"
            fi
        done
        
        # 验证端口
        while true; do
            read -p "请输入 SOCKS5 端口: " socks_port
            if validate_port "$socks_port"; then
                break
            else
                echo "错误: 无效的端口号"
            fi
        done
        
        # 构建服务器配置
        local server_config="{\"address\": \"$socks_ip\", \"port\": $socks_port"
        
        # 可选的认证配置
        read -p "此代理是否需要用户名/密码认证? (y/N): " needs_auth
        if [[ "$needs_auth" =~ ^[yY]([eE][sS])?$ ]]; then
            local username=""
            local password=""
            
            read -p "请输入用户名: " username
            read -s -p "请输入密码: " password
            echo ""
            
            if [ -n "$username" ] && [ -n "$password" ]; then
                server_config="$server_config, \"users\": [{\"user\": \"$username\", \"pass\": \"$password\"}]"
            fi
        fi
        
        server_config="$server_config}"
        socks_servers+=("$server_config")
        
        read -p "是否要添加另一个 SOCKS5 代理? (Y/n): " add_another
        if [[ "$add_another" =~ ^[nN][oO]?$ ]]; then 
            break
        fi
        count=$((count + 1))
    done
    
    # 创建服务配置
    if create_service_config "$shadowsocks_port" "$shadowsocks_password" "${socks_servers[@]}"; then
        log $LOG_LEVEL_INFO "服务 $shadowsocks_port 创建成功"
        view_service_info "$shadowsocks_port" "true"
    else
        log $LOG_LEVEL_ERROR "服务 $shadowsocks_port 创建失败"
        return 1
    fi
}

# 创建服务配置的独立函数
create_service_config() {
    local port=$1
    local password=$2
    shift 2
    local socks_servers=("$@")
    
    local service_dir="$SERVICE_DIR/$port"
    
    # 创建服务目录
    if ! mkdir -p "$service_dir"; then
        log $LOG_LEVEL_ERROR "无法创建服务目录: $service_dir"
        return 1
    fi
    
    # 生成配置文件
    local socks_servers_json=$(printf ",%s" "${socks_servers[@]}")
    socks_servers_json=${socks_servers_json:1}
    
    # 创建Xray配置
    cat > "$service_dir/config.json" <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $port,
            "protocol": "shadowsocks",
            "settings": {
                "method": "aes-256-gcm",
                "password": "$password",
                "network": "tcp,udp"
            },
            "tag": "ss-in"
        }
    ],
    "outbounds": [
        {
            "protocol": "socks",
            "settings": {
                "servers": [$socks_servers_json]
            },
            "tag": "socks-out"
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "inboundTag": ["ss-in"],
                "outboundTag": "socks-out"
            }
        ]
    }
}
EOF
    
    # 设置安全的文件权限
    secure_file_permissions "$service_dir/config.json" 600
    
    # 创建服务信息文件
    cat > "$service_dir/info" <<EOF
PASSWORD=$password
SOCKS_IPS=$(printf "%s," "${socks_servers[@]}" | sed 's/.*"address": *"\([^"]*\)".*"port": *\([0-9]*\).*/\1:\2/g')
CREATED_AT=$(get_current_timestamp)
STATUS=active
VERSION=$SCRIPT_VERSION
EOF
    
    secure_file_permissions "$service_dir/info" 600
    
    # 启动Docker容器
    if start_docker_container "$port"; then
        log $LOG_LEVEL_INFO "Docker容器启动成功: xray-converter-$port"
        return 0
    else
        log $LOG_LEVEL_ERROR "Docker容器启动失败: xray-converter-$port"
        return 1
    fi
}

# 改进的Docker容器启动函数
start_docker_container() {
    local port=$1
    local container_name="xray-converter-$port"
    local config_path="$SERVICE_DIR/$port/config.json"
    
    # 检查配置文件是否存在
    if [ ! -f "$config_path" ]; then
        log $LOG_LEVEL_ERROR "配置文件不存在: $config_path"
        return 1
    fi
    
    # 检查Docker网络
    if ! check_docker_network; then
        log $LOG_LEVEL_INFO "创建Docker网络: $DOCKER_NETWORK"
        if ! create_docker_network; then
            log $LOG_LEVEL_ERROR "无法创建Docker网络"
            return 1
        fi
    fi
    
    # 停止并删除已存在的容器
    $DOCKER_CMD stop "$container_name" >/dev/null 2>&1 || true
    $DOCKER_CMD rm "$container_name" >/dev/null 2>&1 || true
    
    # 启动新容器
    log $LOG_LEVEL_DEBUG "启动容器: $container_name"
    if $DOCKER_CMD run -d \
        --name "$container_name" \
        --network "$DOCKER_NETWORK" \
        --restart unless-stopped \
        -v "$config_path:/etc/xray/config.json:ro" \
        -p "$port:$port/tcp" \
        -p "$port:$port/udp" \
        teddysun/xray >/dev/null; then
        
        # 等待容器启动
        sleep 2
        
        # 验证容器状态
        if [ "$(check_service_status "$port")" = "running" ]; then
            open_firewall_port "$port"
            return 0
        else
            log $LOG_LEVEL_ERROR "容器启动后状态异常"
            return 1
        fi
    else
        log $LOG_LEVEL_ERROR "Docker容器启动命令失败"
        return 1
    fi
}

# 改进的服务状态检查
check_service_status_improved() {
    local port=$1
    local container_name="xray-converter-$port"
    
    # 检查容器是否存在
    if ! $DOCKER_CMD ps -a -f "name=^${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "missing"
        return
    fi
    
    # 检查容器状态
    local status=$($DOCKER_CMD inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
    echo "${status:-unknown}"
}
