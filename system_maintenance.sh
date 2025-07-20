#!/bin/bash
# Xray SOCKS5 to Shadowsocks Converter - 系统维护模块

# 导入配置
source "$(dirname "$0")/config.sh"

# 自动修复服务
repair_service() {
    local port=$1
    local container_name="xray-converter-$port"
    local status=$(check_service_status "$port")
    
    log "检查服务 '$container_name' (状态: $status)..."
    
    if [ "$status" = "missing" ]; then
        # 容器丢失，需要重新创建
        log "重新创建容器 '$container_name'..."
        local config_path="$SERVICE_DIR/$port/config.json"
        
        if [ ! -f "$config_path" ]; then
            log "错误: 配置文件 '$config_path' 不存在，无法修复。"
            return 1
        fi
        
        $DOCKER_CMD run -d --name "$container_name" --network "$DOCKER_NETWORK" --restart always \
            -v "$config_path:/etc/xray/config.json" \
            -p "$port:$port/tcp" -p "$port:$port/udp" \
            teddysun/xray > /dev/null
        
        if [ $? -eq 0 ]; then
            log "✅ 容器 '$container_name' 已重新创建并启动"
            return 0
        else
            log "❌ 无法重新创建容器 '$container_name'"
            return 1
        fi
    elif [ "$status" = "stopped" ]; then
        # 容器已停止，需要启动
        log "启动容器 '$container_name'..."
        $DOCKER_CMD start "$container_name" > /dev/null
        
        if [ $? -eq 0 ]; then
            log "✅ 容器 '$container_name' 已启动"
            return 0
        else
            log "❌ 无法启动容器 '$container_name'"
            return 1
        fi
    else
        # 容器正在运行，无需修复
        log "✅ 容器 '$container_name' 状态正常 ($status)"
        return 0
    fi
}

# 系统自检
system_diagnostic() {
    clear_screen
    echo "--- 系统自检 ---"
    
    # 确保日志目录存在
    mkdir -p "$CONFIG_DIR"
    
    # 1. 检查Docker服务
    echo "1. 检查Docker服务..."
    if $DOCKER_CMD info &>/dev/null; then
        echo "✅ Docker服务正在运行"
    else
        echo "❌ Docker服务未运行或无法访问"
        echo "   建议: 执行 'systemctl start docker' 启动Docker服务"
        press_any_key
        return
    fi
    
    # 2. 检查Docker网络
    echo "2. 检查Docker网络..."
    if check_docker_network; then
        echo "✅ Docker网络 '$DOCKER_NETWORK' 存在"
    else
        echo "❌ Docker网络 '$DOCKER_NETWORK' 不存在"
        read -p "   是否创建此网络? (Y/n): " create_net
        if [[ ! "$create_net" =~ ^[nN]$ ]]; then
            if create_docker_network; then
                echo "✅ Docker网络已创建"
            else
                echo "❌ 无法创建Docker网络"
                press_any_key
                return
            fi
        fi
    fi
    
    # 3. 检查Xray镜像
    echo "3. 检查Xray镜像..."
    if $DOCKER_CMD images | grep -q "teddysun/xray"; then
        echo "✅ Xray镜像已存在"
    else
        echo "❌ Xray镜像不存在"
        read -p "   是否拉取Xray镜像? (Y/n): " pull_image
        if [[ ! "$pull_image" =~ ^[nN]$ ]]; then
            echo "   正在拉取镜像，请稍候..."
            $DOCKER_CMD pull teddysun/xray
            if [ $? -eq 0 ]; then
                echo "✅ Xray镜像已拉取"
            else
                echo "❌ 无法拉取Xray镜像"
                press_any_key
                return
            fi
        fi
    fi
    
    # 4. 检查所有服务状态
    echo "4. 检查所有服务状态..."
    if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
        echo "   未找到任何服务配置"
    else
        local total=0
        local running=0
        local stopped=0
        local missing=0
        
        for port_dir in "$SERVICE_DIR"/*; do
            if [ -d "$port_dir" ]; then
                local port=$(basename "$port_dir")
                local status=$(check_service_status "$port")
                
                total=$((total + 1))
                
                if [ "$status" = "running" ]; then
                    running=$((running + 1))
                elif [ "$status" = "stopped" ]; then
                    stopped=$((stopped + 1))
                elif [ "$status" = "missing" ]; then
                    missing=$((missing + 1))
                fi
            fi
        done
        
        echo "   服务统计:"
        echo "   - 总服务数: $total"
        echo "   - 运行中: $running"
        echo "   - 已停止: $stopped"
        echo "   - 容器丢失: $missing"
        
        if [ $stopped -gt 0 ] || [ $missing -gt 0 ]; then
            echo ""
            echo "⚠️ 检测到 $((stopped + missing)) 个服务存在问题"
            echo "   建议使用「一键修复所有服务」功能进行修复"
        else
            echo ""
            echo "✅ 所有服务状态正常"
        fi
    fi
    
    press_any_key
}

# 一键修复所有服务
repair_all_services() {
    clear_screen
    echo "--- 一键修复所有服务 ---"
    
    if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
        echo "未找到任何服务配置。"
        press_any_key
        return
    fi
    
    # 确保Docker网络存在
    if ! check_docker_network; then
        echo "Docker网络不存在，正在创建..."
        create_docker_network
    fi
    
    echo "开始修复所有服务..."
    local success=0
    local failed=0
    
    for port_dir in "$SERVICE_DIR"/*; do
        if [ -d "$port_dir" ]; then
            local port=$(basename "$port_dir")
            local container_name="xray-converter-$port"
            echo -n "正在检查服务 '$container_name'... "
            
            if repair_service "$port"; then
                echo "✅ 已修复"
                success=$((success + 1))
            else
                echo "❌ 修复失败"
                failed=$((failed + 1))
            fi
        fi
    done
    
    echo ""
    echo "修复完成:"
    echo "- 成功: $success 个服务"
    echo "- 失败: $failed 个服务"
    
    if [ $failed -gt 0 ]; then
        echo "查看日志获取详细信息: $LOG_FILE"
    fi
    
    press_any_key
}

# 重启所有服务
restart_all_services() {
    clear_screen
    echo "--- 重启所有服务 ---"
    
    if [ ! -d "$SERVICE_DIR" ] || [ -z "$(ls -A $SERVICE_DIR 2>/dev/null)" ]; then
        echo "未找到任何服务配置。"
        press_any_key
        return
    fi
    
    local count=0
    
    for port_dir in "$SERVICE_DIR"/*; do
        if [ -d "$port_dir" ]; then
            local port=$(basename "$port_dir")
            local container_name="xray-converter-$port"
            
            echo -n "重启服务 '$container_name'... "
            if $DOCKER_CMD restart "$container_name" &>/dev/null; then
                echo "✅ 成功"
                count=$((count + 1))
            else
                echo "❌ 失败"
            fi
        fi
    done
    
    echo ""
    echo "已重启 $count 个服务"
    press_any_key
}

# 升级Docker镜像
upgrade_docker_image() {
    clear_screen
    echo "--- 升级 Xray Docker 镜像 ---"
    
    # 检查Docker是否运行
    if ! $DOCKER_CMD info &>/dev/null; then
        echo "❌ Docker服务未运行，无法升级镜像。"
        press_any_key
        return
    fi
    
    echo "正在检查最新版本的 teddysun/xray 镜像..."
    $DOCKER_CMD pull teddysun/xray
    
    if [ $? -eq 0 ]; then
        echo "✅ 镜像已更新至最新版本。"
        
        read -p "是否要重启所有服务以应用新镜像? (y/N): " restart_services
        if [[ "$restart_services" =~ ^[yY]([eE][sS])?$ ]]; then
            echo "正在重启所有服务..."
            restart_all_services
        else
            echo "镜像已更新，但服务尚未重启。下次重启服务时将使用新镜像。"
        fi
        
        log "已升级Docker镜像: teddysun/xray"
    else
        echo "❌ 镜像更新失败，请检查网络连接或Docker服务状态。"
    fi
    
    press_any_key
} 