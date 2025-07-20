#!/bin/bash

# Xray转换器管理平台部署脚本
# 使用方法: ./deploy.sh [production|staging]

set -e

# 配置变量
ENVIRONMENT=${1:-production}
PROJECT_NAME="xray-converter"
DEPLOY_USER="deploy"
DEPLOY_PATH="/opt/${PROJECT_NAME}"
BACKUP_PATH="/opt/backups/${PROJECT_NAME}"
NGINX_CONFIG_PATH="/etc/nginx/sites-available/${PROJECT_NAME}"
SYSTEMD_SERVICE_PATH="/etc/systemd/system/${PROJECT_NAME}.service"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    # 更新包管理器
    apt update
    
    # 安装基础依赖
    apt install -y curl wget git nginx certbot python3-certbot-nginx
    
    # 安装Node.js 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
    
    # 安装PM2
    npm install -g pm2
    
    # 安装Docker
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    fi
    
    # 安装Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    log_info "系统依赖安装完成"
}

# 创建部署用户
create_deploy_user() {
    log_info "创建部署用户..."
    
    if ! id "$DEPLOY_USER" &>/dev/null; then
        useradd -m -s /bin/bash $DEPLOY_USER
        usermod -aG docker $DEPLOY_USER
        log_info "用户 $DEPLOY_USER 创建成功"
    else
        log_warn "用户 $DEPLOY_USER 已存在"
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    mkdir -p $DEPLOY_PATH
    mkdir -p $BACKUP_PATH
    mkdir -p $DEPLOY_PATH/logs
    mkdir -p $DEPLOY_PATH/data
    mkdir -p $DEPLOY_PATH/uploads
    
    chown -R $DEPLOY_USER:$DEPLOY_USER $DEPLOY_PATH
    chown -R $DEPLOY_USER:$DEPLOY_USER $BACKUP_PATH
    
    log_info "目录结构创建完成"
}

# 配置Nginx
configure_nginx() {
    log_info "配置Nginx..."
    
    cat > $NGINX_CONFIG_PATH << 'EOF'
server {
    listen 80;
    server_name your-domain.com;  # 替换为您的域名
    
    # 重定向到HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;  # 替换为您的域名
    
    # SSL配置 (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # 静态文件
    location / {
        root /opt/xray-converter/frontend/dist;
        try_files $uri $uri/ /index.html;
        
        # 缓存静态资源
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # API代理
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # WebSocket支持
    location /socket.io/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 文件上传大小限制
    client_max_body_size 100M;
    
    # 日志
    access_log /var/log/nginx/xray-converter.access.log;
    error_log /var/log/nginx/xray-converter.error.log;
}
EOF
    
    # 启用站点
    ln -sf $NGINX_CONFIG_PATH /etc/nginx/sites-enabled/
    
    # 测试配置
    nginx -t
    
    log_info "Nginx配置完成"
}

# 配置systemd服务
configure_systemd() {
    log_info "配置systemd服务..."
    
    cat > $SYSTEMD_SERVICE_PATH << EOF
[Unit]
Description=Xray Converter Management Platform
After=network.target

[Service]
Type=simple
User=$DEPLOY_USER
WorkingDirectory=$DEPLOY_PATH
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=$ENVIRONMENT
Environment=PORT=3000

# 日志
StandardOutput=append:$DEPLOY_PATH/logs/app.log
StandardError=append:$DEPLOY_PATH/logs/error.log

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DEPLOY_PATH

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable $PROJECT_NAME
    
    log_info "systemd服务配置完成"
}

# 部署应用
deploy_application() {
    log_info "部署应用..."
    
    # 切换到部署用户
    sudo -u $DEPLOY_USER bash << 'DEPLOY_SCRIPT'
    
    # 进入部署目录
    cd /opt/xray-converter
    
    # 如果是首次部署，克隆代码
    if [ ! -d ".git" ]; then
        git clone https://github.com/your-username/xray-converter.git .
    else
        # 更新代码
        git fetch origin
        git reset --hard origin/main
    fi
    
    # 安装后端依赖
    npm install --production
    
    # 构建前端
    cd frontend
    npm install
    npm run build
    cd ..
    
    # 复制环境配置
    if [ ! -f ".env" ]; then
        cp .env.example .env
        echo "请编辑 .env 文件配置数据库等信息"
    fi
    
DEPLOY_SCRIPT
    
    log_info "应用部署完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # 安装ufw
    apt install -y ufw
    
    # 基础规则
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # 允许SSH
    ufw allow ssh
    
    # 允许HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # 启用防火墙
    ufw --force enable
    
    log_info "防火墙配置完成"
}

# 设置SSL证书
setup_ssl() {
    log_info "设置SSL证书..."
    
    read -p "请输入您的域名: " DOMAIN
    read -p "请输入您的邮箱: " EMAIL
    
    if [ -n "$DOMAIN" ] && [ -n "$EMAIL" ]; then
        # 替换Nginx配置中的域名
        sed -i "s/your-domain.com/$DOMAIN/g" $NGINX_CONFIG_PATH
        
        # 重新加载Nginx
        systemctl reload nginx
        
        # 获取SSL证书
        certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
        
        log_info "SSL证书设置完成"
    else
        log_warn "跳过SSL证书设置"
    fi
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 启动应用
    systemctl start $PROJECT_NAME
    
    # 启动Nginx
    systemctl start nginx
    systemctl enable nginx
    
    # 检查服务状态
    sleep 5
    
    if systemctl is-active --quiet $PROJECT_NAME; then
        log_info "应用服务启动成功"
    else
        log_error "应用服务启动失败"
        systemctl status $PROJECT_NAME
    fi
    
    if systemctl is-active --quiet nginx; then
        log_info "Nginx服务启动成功"
    else
        log_error "Nginx服务启动失败"
        systemctl status nginx
    fi
}

# 显示部署信息
show_deployment_info() {
    log_info "部署完成！"
    echo
    echo "==================================="
    echo "部署信息:"
    echo "==================================="
    echo "项目路径: $DEPLOY_PATH"
    echo "日志路径: $DEPLOY_PATH/logs"
    echo "备份路径: $BACKUP_PATH"
    echo "Nginx配置: $NGINX_CONFIG_PATH"
    echo "systemd服务: $SYSTEMD_SERVICE_PATH"
    echo
    echo "常用命令:"
    echo "查看应用状态: systemctl status $PROJECT_NAME"
    echo "查看应用日志: journalctl -u $PROJECT_NAME -f"
    echo "重启应用: systemctl restart $PROJECT_NAME"
    echo "重新加载Nginx: systemctl reload nginx"
    echo
    echo "下一步:"
    echo "1. 编辑 $DEPLOY_PATH/.env 配置文件"
    echo "2. 配置域名DNS解析"
    echo "3. 访问您的网站测试功能"
    echo "==================================="
}

# 主函数
main() {
    log_info "开始部署 Xray转换器管理平台 ($ENVIRONMENT 环境)"
    
    check_root
    install_dependencies
    create_deploy_user
    create_directories
    configure_nginx
    configure_systemd
    deploy_application
    configure_firewall
    
    # 询问是否设置SSL
    read -p "是否设置SSL证书? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_ssl
    fi
    
    start_services
    show_deployment_info
}

# 运行主函数
main "$@"
