#!/bin/bash

# 快速部署脚本 - 适用于已有Docker环境的服务器
# 使用方法: ./quick-deploy.sh

set -e

# 配置变量
PROJECT_NAME="xray-converter"
REPO_URL="https://github.com/your-username/xray-converter.git"  # 替换为您的仓库地址
DEPLOY_PATH="/opt/${PROJECT_NAME}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查Docker环境
check_docker() {
    log_step "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请启动Docker服务"
        exit 1
    fi
    
    log_info "Docker环境检查通过"
}

# 克隆或更新代码
setup_code() {
    log_step "设置项目代码..."
    
    if [ -d "$DEPLOY_PATH" ]; then
        log_info "项目目录已存在，更新代码..."
        cd $DEPLOY_PATH
        git fetch origin
        git reset --hard origin/main
    else
        log_info "克隆项目代码..."
        git clone $REPO_URL $DEPLOY_PATH
        cd $DEPLOY_PATH
    fi
    
    log_info "代码设置完成"
}

# 配置环境变量
setup_environment() {
    log_step "配置环境变量..."
    
    if [ ! -f ".env" ]; then
        log_info "创建环境配置文件..."
        cp .env.example .env
        
        # 生成随机密钥
        JWT_SECRET=$(openssl rand -hex 32)
        ENCRYPTION_KEY=$(openssl rand -hex 16)
        SESSION_SECRET=$(openssl rand -hex 32)
        
        # 替换默认配置
        sed -i "s/your-super-secret-jwt-key-change-this-in-production/$JWT_SECRET/g" .env
        sed -i "s/your-32-character-encryption-key-here/$ENCRYPTION_KEY/g" .env
        sed -i "s/your-session-secret-key/$SESSION_SECRET/g" .env
        
        log_warn "请编辑 .env 文件配置您的域名和其他设置"
        log_warn "配置文件位置: $DEPLOY_PATH/.env"
    else
        log_info "环境配置文件已存在"
    fi
}

# 创建必要目录
create_directories() {
    log_step "创建必要目录..."
    
    mkdir -p data logs uploads backups config
    mkdir -p nginx/conf.d ssl monitoring/grafana/provisioning
    
    # 设置权限
    chmod 755 data logs uploads backups
    
    log_info "目录创建完成"
}

# 构建和启动服务
deploy_services() {
    log_step "构建和启动服务..."
    
    # 停止现有服务
    log_info "停止现有服务..."
    docker-compose down --remove-orphans || true
    
    # 构建镜像
    log_info "构建应用镜像..."
    docker-compose build --no-cache
    
    # 启动服务
    log_info "启动服务..."
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    check_services
}

# 检查服务状态
check_services() {
    log_step "检查服务状态..."
    
    # 检查容器状态
    if docker-compose ps | grep -q "Up"; then
        log_info "服务启动成功"
        docker-compose ps
    else
        log_error "服务启动失败"
        docker-compose logs
        exit 1
    fi
    
    # 检查应用健康状态
    log_info "检查应用健康状态..."
    for i in {1..10}; do
        if curl -f http://localhost:3000/api/health &> /dev/null; then
            log_info "应用健康检查通过"
            break
        else
            log_warn "等待应用启动... ($i/10)"
            sleep 10
        fi
        
        if [ $i -eq 10 ]; then
            log_error "应用健康检查失败"
            docker-compose logs app
            exit 1
        fi
    done
}

# 设置Nginx (如果需要)
setup_nginx() {
    log_step "设置Nginx配置..."
    
    read -p "是否需要配置Nginx反向代理? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 创建Nginx配置
        cat > nginx/conf.d/default.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://app:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
        
        # 启用Nginx服务
        docker-compose up -d nginx
        
        log_info "Nginx配置完成"
    fi
}

# 显示部署结果
show_result() {
    log_step "部署完成！"
    
    echo
    echo "=================================="
    echo "🎉 部署成功！"
    echo "=================================="
    echo "项目路径: $DEPLOY_PATH"
    echo "访问地址: http://$(hostname -I | awk '{print $1}'):3000"
    echo
    echo "管理命令:"
    echo "查看服务状态: docker-compose ps"
    echo "查看日志: docker-compose logs -f"
    echo "重启服务: docker-compose restart"
    echo "停止服务: docker-compose down"
    echo "更新代码: git pull && docker-compose up -d --build"
    echo
    echo "配置文件:"
    echo "环境配置: $DEPLOY_PATH/.env"
    echo "Docker配置: $DEPLOY_PATH/docker-compose.yml"
    echo
    echo "下一步:"
    echo "1. 编辑 .env 文件配置域名等信息"
    echo "2. 配置SSL证书 (如果需要)"
    echo "3. 设置防火墙规则"
    echo "4. 配置域名DNS解析"
    echo "=================================="
}

# 主函数
main() {
    log_info "开始快速部署 Xray转换器管理平台"
    
    check_docker
    setup_code
    setup_environment
    create_directories
    deploy_services
    setup_nginx
    show_result
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 运行主函数
main "$@"
