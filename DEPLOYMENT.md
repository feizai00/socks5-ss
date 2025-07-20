# 🚀 Xray转换器管理平台部署指南

## 📋 部署前准备

### 系统要求
- **操作系统**: Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- **内存**: 最少 2GB，推荐 4GB+
- **存储**: 最少 20GB 可用空间
- **网络**: 公网IP和域名（可选）

### 必需软件
- Docker 20.10+
- Docker Compose 2.0+
- Git
- Nginx（可选，可使用Docker版本）

## 🎯 部署方式选择

### 方式一：一键自动部署（推荐新服务器）
适用于全新的服务器，会自动安装所有依赖。

```bash
# 下载部署脚本
wget https://raw.githubusercontent.com/your-username/xray-converter/main/deploy.sh

# 给脚本执行权限
chmod +x deploy.sh

# 运行部署脚本
sudo ./deploy.sh production
```

### 方式二：快速Docker部署（推荐已有Docker环境）
适用于已安装Docker的服务器。

```bash
# 克隆项目
git clone https://github.com/your-username/xray-converter.git
cd xray-converter

# 运行快速部署脚本
chmod +x quick-deploy.sh
./quick-deploy.sh
```

### 方式三：手动部署
适用于需要自定义配置的场景。

## 📝 手动部署详细步骤

### 1. 准备服务器环境

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础依赖
sudo apt install -y curl wget git nginx certbot python3-certbot-nginx

# 安装Docker
curl -fsSL https://get.docker.com | sh
sudo systemctl enable docker
sudo systemctl start docker

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 将当前用户添加到docker组
sudo usermod -aG docker $USER
newgrp docker
```

### 2. 克隆项目代码

```bash
# 克隆到部署目录
sudo mkdir -p /opt/xray-converter
sudo chown $USER:$USER /opt/xray-converter
git clone https://github.com/your-username/xray-converter.git /opt/xray-converter
cd /opt/xray-converter
```

### 3. 配置环境变量

```bash
# 复制环境配置模板
cp .env.example .env

# 编辑配置文件
nano .env
```

**重要配置项：**
```bash
# 修改为您的域名
DOMAIN=your-domain.com

# 生成安全密钥
JWT_SECRET=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 16)
SESSION_SECRET=$(openssl rand -hex 32)

# 数据库密码
DB_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
```

### 4. 创建必要目录

```bash
mkdir -p data logs uploads backups config ssl
mkdir -p nginx/conf.d monitoring/grafana/provisioning
chmod 755 data logs uploads backups
```

### 5. 构建和启动服务

```bash
# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

### 6. 配置Nginx反向代理

```bash
# 创建Nginx配置
sudo nano /etc/nginx/sites-available/xray-converter
```

**Nginx配置内容：**
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
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
```

```bash
# 启用站点
sudo ln -s /etc/nginx/sites-available/xray-converter /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 7. 配置SSL证书

```bash
# 使用Let's Encrypt获取免费SSL证书
sudo certbot --nginx -d your-domain.com

# 设置自动续期
sudo crontab -e
# 添加以下行：
# 0 12 * * * /usr/bin/certbot renew --quiet
```

### 8. 配置防火墙

```bash
# 安装并配置UFW
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

## 🔧 配置说明

### 环境变量配置

| 变量名 | 说明 | 默认值 | 必需 |
|--------|------|--------|------|
| `DOMAIN` | 您的域名 | - | 是 |
| `JWT_SECRET` | JWT密钥 | - | 是 |
| `DB_PASSWORD` | 数据库密码 | - | 是 |
| `REDIS_PASSWORD` | Redis密码 | - | 是 |
| `SMTP_HOST` | 邮件服务器 | - | 否 |
| `TELEGRAM_BOT_TOKEN` | Telegram机器人令牌 | - | 否 |

### 端口说明

| 端口 | 服务 | 说明 |
|------|------|------|
| 3000 | 主应用 | Web界面和API |
| 5432 | PostgreSQL | 数据库 |
| 6379 | Redis | 缓存 |
| 9090 | Prometheus | 监控 |
| 3001 | Grafana | 监控面板 |

## 🔍 验证部署

### 1. 检查服务状态

```bash
# 检查Docker容器
docker-compose ps

# 检查应用日志
docker-compose logs -f app

# 检查健康状态
curl http://localhost:3000/api/health
```

### 2. 访问Web界面

打开浏览器访问：`https://your-domain.com`

默认登录信息：
- 用户名: `admin`
- 密码: `admin123`

**⚠️ 首次登录后请立即修改密码！**

## 📊 监控和维护

### 日常维护命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f [service_name]

# 重启服务
docker-compose restart [service_name]

# 更新应用
git pull
docker-compose up -d --build

# 备份数据
docker-compose exec db pg_dump -U xray_user xray_converter > backup.sql

# 清理Docker资源
docker system prune -f
```

### 监控面板

- **Grafana**: `http://your-domain.com:3001`
  - 用户名: `admin`
  - 密码: `admin123`

- **Prometheus**: `http://your-domain.com:9090`

## 🚨 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查日志
   docker-compose logs
   
   # 检查端口占用
   netstat -tlnp | grep :3000
   ```

2. **数据库连接失败**
   ```bash
   # 检查数据库状态
   docker-compose exec db pg_isready -U xray_user
   
   # 重启数据库
   docker-compose restart db
   ```

3. **SSL证书问题**
   ```bash
   # 检查证书状态
   sudo certbot certificates
   
   # 手动续期
   sudo certbot renew
   ```

### 日志位置

- 应用日志: `/opt/xray-converter/logs/`
- Nginx日志: `/var/log/nginx/`
- Docker日志: `docker-compose logs`

## 🔄 更新部署

### 更新应用

```bash
cd /opt/xray-converter

# 备份当前版本
docker-compose exec db pg_dump -U xray_user xray_converter > backup-$(date +%Y%m%d).sql

# 拉取最新代码
git pull

# 重新构建并启动
docker-compose up -d --build

# 验证更新
curl http://localhost:3000/api/health
```

### 回滚版本

```bash
# 查看提交历史
git log --oneline

# 回滚到指定版本
git reset --hard <commit_hash>

# 重新部署
docker-compose up -d --build
```

## 📞 技术支持

如果在部署过程中遇到问题，请：

1. 查看本文档的故障排除部分
2. 检查项目的 Issues 页面
3. 提交新的 Issue 并附上详细的错误信息

---

**祝您部署顺利！🎉**
