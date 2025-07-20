#!/bin/bash
# Xray SOCKS5 to Shadowsocks Converter - 配置文件

# --- 版本信息 ---
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="Xray SOCKS5 to Shadowsocks Converter"

# --- 配置常量 ---
readonly CONFIG_DIR="$HOME/.xray-converter"
readonly SERVICE_DIR="$CONFIG_DIR/services"
readonly DOCKER_NETWORK="xray-net"
readonly LOG_FILE="$CONFIG_DIR/xray-converter.log"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly CRON_BACKUP_SCRIPT="$CONFIG_DIR/auto_backup.sh"
readonly ALLOWED_IPS_FILE="$CONFIG_DIR/allowed_ips.txt"
readonly RECYCLE_BIN_DIR="$CONFIG_DIR/recycle_bin"
readonly EXPIRY_CHECK_SCRIPT="$CONFIG_DIR/check_expiry.sh"

# --- 日志级别 ---
readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# --- 基础辅助函数 ---

# 增强的日志记录函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # 如果只传入一个参数，默认为INFO级别
    if [ $# -eq 1 ]; then
        message=$1
        level=$LOG_LEVEL_INFO
    fi

    # 检查日志级别
    if [ "$level" -le "$LOG_LEVEL" ]; then
        local level_name=""
        case $level in
            $LOG_LEVEL_ERROR) level_name="ERROR" ;;
            $LOG_LEVEL_WARN)  level_name="WARN"  ;;
            $LOG_LEVEL_INFO)  level_name="INFO"  ;;
            $LOG_LEVEL_DEBUG) level_name="DEBUG" ;;
        esac

        echo "[$timestamp] [$level_name] $message" | tee -a "$LOG_FILE"
    fi
}

# 错误处理函数
handle_error() {
    local exit_code=$1
    local error_message=$2
    local line_number=${3:-"unknown"}

    log $LOG_LEVEL_ERROR "Error on line $line_number: $error_message (exit code: $exit_code)"

    # 可选的错误恢复逻辑
    if [ "$exit_code" -ne 0 ]; then
        log $LOG_LEVEL_ERROR "Operation failed, please check the logs for details"
    fi

    return $exit_code
}

# 设置错误陷阱
set -eE
trap 'handle_error $? "Unexpected error occurred" $LINENO' ERR

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 输入验证函数
validate_port() {
    local port=$1
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    return 0
}

validate_ip() {
    local ip=$1
    # 简单的IP地址验证
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [ "$i" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# 安全的密码生成
generate_secure_password() {
    local length=${1:-16}
    if command_exists openssl; then
        openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
    else
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$length" | head -n 1
    fi
}

# 安全的文件权限设置
secure_file_permissions() {
    local file_path=$1
    local permissions=${2:-600}

    if [ -f "$file_path" ]; then
        chmod "$permissions" "$file_path"
        log $LOG_LEVEL_DEBUG "Set permissions $permissions for $file_path"
    fi
}

# 清屏
clear_screen() {
    clear
}

# 按任意键继续
press_any_key() {
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 格式化日期显示
format_date() {
    local timestamp=$1
    if [ -n "$timestamp" ]; then
        date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "无效日期"
    else
        echo "永久"
    fi
}

# 获取当前时间戳
get_current_timestamp() {
    date +%s
}

# 计算失效时间戳
calculate_expiry_timestamp() {
    local duration=$1  # 持续时间（天数）
    local current_timestamp=$(get_current_timestamp)
    echo $((current_timestamp + duration * 86400))
}

# 检查服务状态
check_service_status() {
    local port=$1
    local container_name="xray-converter-$port"
    
    # 检查容器是否存在
    if ! $DOCKER_CMD ps -a -f "name=$container_name" --format "{{.Names}}" | grep -q "$container_name"; then
        echo "missing"
        return
    fi
    
    # 检查容器是否运行
    local status=$($DOCKER_CMD ps -f "name=$container_name" --format "{{.State}}")
    if [ -z "$status" ]; then
        echo "stopped"
    else
        echo "$status"
    fi
}

# 检查Docker网络
check_docker_network() {
    if $DOCKER_CMD network inspect "$DOCKER_NETWORK" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 创建Docker网络
create_docker_network() {
    log "创建Docker网络 '$DOCKER_NETWORK'..."
    $DOCKER_CMD network create "$DOCKER_NETWORK" > /dev/null 2>&1
    return $?
}

# 开放防火墙端口
open_firewall_port() {
    local port=$1
    echo ">> 正在为端口 $port 配置防火墙..."
    if command_exists firewall-cmd; then
        sudo firewall-cmd --permanent --add-port=${port}/tcp > /dev/null 2>&1
        sudo firewall-cmd --permanent --add-port=${port}/udp > /dev/null 2>&1
        sudo firewall-cmd --reload
    elif command_exists ufw; then
        sudo ufw allow ${port}/tcp > /dev/null 2>&1
        sudo ufw allow ${port}/udp > /dev/null 2>&1
    fi
}

# 初始化设置
initial_setup() {
    # 创建日志目录
    mkdir -p "$CONFIG_DIR"
    log "初始化 Xray SOCKS5 to Shadowsocks 转换器..."
    
    # 安装必要的依赖 (qrencode, curl)
    if ! command_exists qrencode || ! command_exists curl; then
        echo ">> 正在检查并安装必要的依赖 (qrencode, curl)..."
        if command_exists apt-get; then sudo apt-get update && sudo apt-get install -y qrencode curl;
        elif command_exists yum; then sudo yum install -y qrencode curl;
        elif command_exists dnf; then sudo dnf install -y qrencode curl;
        else echo "警告: 无法自动安装 'qrencode' 和 'curl'。请手动安装。"; fi
    fi
    
    # 检查并配置 Docker
    if ! command_exists docker; then
        echo ">> Docker 未安装，正在尝试自动安装..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        sudo usermod -aG docker "$USER"
        echo "Docker 安装成功！请重新登录或执行 'newgrp docker' 以应用组更改，然后重新运行脚本。"
        exit 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        if sudo docker info > /dev/null 2>&1; then
            echo "警告: 当前用户无法直接访问 Docker。将尝试使用 'sudo'。"
            DOCKER_CMD="sudo docker"
        else
            echo "错误: Docker 守护进程未运行或任何用户都无权访问。"
            echo "请启动 Docker 并确保用户在 'docker' 组中，或以 root 身份运行。"
            exit 1
        fi
    else
        DOCKER_CMD="docker"
    fi
    
    # 创建基础目录和网络
    mkdir -p "$SERVICE_DIR"
    mkdir -p "$RECYCLE_BIN_DIR"  # 确保回收站目录存在
    $DOCKER_CMD network create "$DOCKER_NETWORK" > /dev/null 2>&1
    echo ">> 正在后台预先拉取 Xray 镜像，请稍候..."
    $DOCKER_CMD pull teddysun/xray > /dev/null 2>&1 &
} 