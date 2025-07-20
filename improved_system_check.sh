#!/bin/bash
# 改进的系统检查和环境验证模块

# 导入配置
source "$(dirname "$0")/config.sh"

# 系统环境检查
system_environment_check() {
    log $LOG_LEVEL_INFO "开始系统环境检查..."
    
    local check_passed=true
    local warnings=()
    local errors=()
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log $LOG_LEVEL_INFO "✅ 操作系统: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log $LOG_LEVEL_WARN "⚠️  操作系统: macOS (部分功能可能不可用)"
        warnings+=("macOS环境下防火墙配置可能需要手动处理")
    else
        log $LOG_LEVEL_ERROR "❌ 不支持的操作系统: $OSTYPE"
        errors+=("不支持的操作系统")
        check_passed=false
    fi
    
    # 检查必需的命令
    local required_commands=("docker" "curl" "tar" "gzip")
    local optional_commands=("qrencode" "openssl" "shuf" "firewall-cmd" "ufw")
    
    for cmd in "${required_commands[@]}"; do
        if command_exists "$cmd"; then
            log $LOG_LEVEL_INFO "✅ 必需命令: $cmd"
        else
            log $LOG_LEVEL_ERROR "❌ 缺少必需命令: $cmd"
            errors+=("缺少必需命令: $cmd")
            check_passed=false
        fi
    done
    
    for cmd in "${optional_commands[@]}"; do
        if command_exists "$cmd"; then
            log $LOG_LEVEL_INFO "✅ 可选命令: $cmd"
        else
            log $LOG_LEVEL_WARN "⚠️  缺少可选命令: $cmd"
            warnings+=("缺少可选命令: $cmd，某些功能可能受限")
        fi
    done
    
    # 检查Docker状态
    check_docker_environment
    local docker_status=$?
    if [ $docker_status -ne 0 ]; then
        errors+=("Docker环境检查失败")
        check_passed=false
    fi
    
    # 检查磁盘空间
    local available_space=$(df "$CONFIG_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    local required_space=1048576  # 1GB in KB
    
    if [ "$available_space" -gt "$required_space" ]; then
        log $LOG_LEVEL_INFO "✅ 磁盘空间充足: $(($available_space / 1024))MB 可用"
    else
        log $LOG_LEVEL_WARN "⚠️  磁盘空间不足: $(($available_space / 1024))MB 可用，建议至少1GB"
        warnings+=("磁盘空间不足，可能影响备份和日志功能")
    fi
    
    # 检查网络连接
    if curl -s --connect-timeout 5 https://www.google.com >/dev/null; then
        log $LOG_LEVEL_INFO "✅ 网络连接正常"
    else
        log $LOG_LEVEL_WARN "⚠️  网络连接可能有问题"
        warnings+=("网络连接异常，可能影响Docker镜像拉取")
    fi
    
    # 输出检查结果
    echo ""
    echo "=== 系统环境检查结果 ==="
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "警告:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
        echo ""
    fi
    
    if [ ${#errors[@]} -gt 0 ]; then
        echo "错误:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        echo ""
    fi
    
    if [ "$check_passed" = true ]; then
        log $LOG_LEVEL_INFO "✅ 系统环境检查通过"
        return 0
    else
        log $LOG_LEVEL_ERROR "❌ 系统环境检查失败"
        return 1
    fi
}

# Docker环境检查
check_docker_environment() {
    log $LOG_LEVEL_DEBUG "检查Docker环境..."
    
    # 检查Docker是否安装
    if ! command_exists docker; then
        log $LOG_LEVEL_ERROR "Docker未安装"
        return 1
    fi
    
    # 检查Docker守护进程
    if docker info >/dev/null 2>&1; then
        DOCKER_CMD="docker"
        log $LOG_LEVEL_INFO "✅ Docker守护进程运行正常"
    elif sudo docker info >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
        log $LOG_LEVEL_WARN "⚠️  需要sudo权限访问Docker"
    else
        log $LOG_LEVEL_ERROR "❌ Docker守护进程未运行或无权限访问"
        return 1
    fi
    
    # 检查Docker版本
    local docker_version=$($DOCKER_CMD version --format '{{.Server.Version}}' 2>/dev/null)
    if [ -n "$docker_version" ]; then
        log $LOG_LEVEL_INFO "✅ Docker版本: $docker_version"
    else
        log $LOG_LEVEL_WARN "⚠️  无法获取Docker版本信息"
    fi
    
    # 检查Docker网络
    if $DOCKER_CMD network ls | grep -q "$DOCKER_NETWORK"; then
        log $LOG_LEVEL_INFO "✅ Docker网络已存在: $DOCKER_NETWORK"
    else
        log $LOG_LEVEL_INFO "Docker网络不存在，将自动创建: $DOCKER_NETWORK"
    fi
    
    # 检查Xray镜像
    if $DOCKER_CMD images | grep -q "teddysun/xray"; then
        log $LOG_LEVEL_INFO "✅ Xray镜像已存在"
    else
        log $LOG_LEVEL_INFO "Xray镜像不存在，将自动拉取"
    fi
    
    return 0
}

# 自动修复环境问题
auto_fix_environment() {
    log $LOG_LEVEL_INFO "开始自动修复环境问题..."
    
    # 创建必要的目录
    local directories=("$CONFIG_DIR" "$SERVICE_DIR" "$BACKUP_DIR" "$RECYCLE_BIN_DIR")
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            if mkdir -p "$dir"; then
                log $LOG_LEVEL_INFO "✅ 创建目录: $dir"
                chmod 700 "$dir"  # 设置安全权限
            else
                log $LOG_LEVEL_ERROR "❌ 无法创建目录: $dir"
                return 1
            fi
        fi
    done
    
    # 修复文件权限
    if [ -f "$LOG_FILE" ]; then
        chmod 600 "$LOG_FILE"
    fi
    
    if [ -f "$ALLOWED_IPS_FILE" ]; then
        chmod 600 "$ALLOWED_IPS_FILE"
    fi
    
    # 创建Docker网络
    if ! check_docker_network; then
        if create_docker_network; then
            log $LOG_LEVEL_INFO "✅ 创建Docker网络: $DOCKER_NETWORK"
        else
            log $LOG_LEVEL_ERROR "❌ 无法创建Docker网络"
            return 1
        fi
    fi
    
    # 拉取Xray镜像
    if ! $DOCKER_CMD images | grep -q "teddysun/xray"; then
        log $LOG_LEVEL_INFO "正在拉取Xray镜像..."
        if $DOCKER_CMD pull teddysun/xray >/dev/null 2>&1; then
            log $LOG_LEVEL_INFO "✅ Xray镜像拉取成功"
        else
            log $LOG_LEVEL_ERROR "❌ Xray镜像拉取失败"
            return 1
        fi
    fi
    
    log $LOG_LEVEL_INFO "✅ 环境修复完成"
    return 0
}

# 性能监控
monitor_system_performance() {
    log $LOG_LEVEL_DEBUG "监控系统性能..."
    
    # CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "unknown")
    
    # 内存使用率
    local mem_info=$(free | grep Mem)
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_usage=$((mem_used * 100 / mem_total))
    
    # 磁盘使用率
    local disk_usage=$(df "$CONFIG_DIR" | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    
    # Docker容器数量
    local container_count=$($DOCKER_CMD ps -q | wc -l)
    local running_services=$(find "$SERVICE_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    
    echo "=== 系统性能监控 ==="
    echo "CPU使用率: ${cpu_usage}%"
    echo "内存使用率: ${mem_usage}%"
    echo "磁盘使用率: ${disk_usage}%"
    echo "运行中的Docker容器: $container_count"
    echo "配置的服务数量: $running_services"
    
    # 性能警告
    if [ "$mem_usage" -gt 80 ]; then
        log $LOG_LEVEL_WARN "内存使用率过高: ${mem_usage}%"
    fi
    
    if [ "$disk_usage" -gt 90 ]; then
        log $LOG_LEVEL_WARN "磁盘使用率过高: ${disk_usage}%"
    fi
    
    if [ "$container_count" -gt 50 ]; then
        log $LOG_LEVEL_WARN "Docker容器数量较多: $container_count"
    fi
}

# 清理系统资源
cleanup_system_resources() {
    log $LOG_LEVEL_INFO "开始清理系统资源..."
    
    # 清理停止的Docker容器
    local stopped_containers=$($DOCKER_CMD ps -a -f "status=exited" -q)
    if [ -n "$stopped_containers" ]; then
        $DOCKER_CMD rm $stopped_containers >/dev/null 2>&1
        log $LOG_LEVEL_INFO "✅ 清理停止的Docker容器"
    fi
    
    # 清理未使用的Docker镜像
    $DOCKER_CMD image prune -f >/dev/null 2>&1
    log $LOG_LEVEL_INFO "✅ 清理未使用的Docker镜像"
    
    # 清理旧日志文件
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0) -gt 10485760 ]; then
        tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
        log $LOG_LEVEL_INFO "✅ 清理日志文件"
    fi
    
    log $LOG_LEVEL_INFO "✅ 系统资源清理完成"
}
