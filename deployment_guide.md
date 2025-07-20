# Xray SOCKS5 转换器 Web端部署指南

## 📋 概述

本指南将帮助您将现有的Bash脚本项目升级为现代化的Web管理平台，支持完整的客户管理、节点管理和服务分配功能。

## 🏗️ 新架构特性

### 数据库结构增强
- **客户管理**: 微信号、微信名称、联系方式、状态管理
- **节点管理**: SOCKS5节点信息、地区分类、连接数控制
- **服务关联**: 客户与服务的多对多关系管理
- **统计分析**: 使用情况统计和性能监控

### Web界面功能
- **客户管理**: 添加、编辑、查看客户信息和服务使用情况
- **节点管理**: SOCKS5节点的完整生命周期管理
- **服务分配**: 灵活的服务创建和客户分配
- **实时监控**: 服务状态、连接数、到期时间监控

## 🚀 部署步骤

### 第一步: 环境准备

```bash
# 1. 安装Node.js (推荐v18+)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. 安装必要的系统依赖
sudo apt-get update
sudo apt-get install -y git sqlite3 build-essential

# 3. 创建项目目录
mkdir xray-web-manager
cd xray-web-manager
```

### 第二步: 项目初始化

```bash
# 1. 初始化Node.js项目
npm init -y

# 2. 安装后端依赖
npm install express cors sqlite3 dockerode qrcode jsonwebtoken bcrypt ws multer

# 3. 安装开发依赖
npm install -D nodemon concurrently

# 4. 创建项目结构
mkdir -p {src,public,data,logs,config}
mkdir -p src/{routes,middleware,utils,models}
```

### 第三步: 配置文件设置

创建 `package.json` 脚本:
```json
{
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js",
    "migrate": "node data_migration_script.js",
    "backup": "node scripts/backup.js"
  }
}
```

创建 `src/app.js`:
```javascript
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// 中间件
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// 路由
app.use('/api', require('./routes/api'));

// 启动服务器
app.listen(PORT, () => {
    console.log(`服务器运行在端口 ${PORT}`);
});
```

### 第四步: 数据库迁移

```bash
# 1. 复制数据库结构文件
cp enhanced_database_schema.sql ./

# 2. 复制迁移脚本
cp data_migration_script.js ./

# 3. 执行数据库初始化
sqlite3 data/enhanced-xray-converter.db < enhanced_database_schema.sql

# 4. 执行数据迁移（如果有旧数据）
npm run migrate
```

### 第五步: 前端部署

```bash
# 1. 安装Vue CLI
npm install -g @vue/cli

# 2. 创建Vue项目
vue create frontend
cd frontend

# 3. 安装UI库和依赖
npm install element-plus @element-plus/icons-vue axios qrcode

# 4. 复制前端组件
cp ../enhanced_web_forms.vue src/components/

# 5. 构建前端
npm run build

# 6. 复制构建文件到后端
cp -r dist/* ../public/
```

### 第六步: Docker配置（可选）

创建 `Dockerfile`:
```dockerfile
FROM node:18-alpine

WORKDIR /app

# 复制package文件
COPY package*.json ./
RUN npm ci --only=production

# 复制应用代码
COPY . .

# 创建数据目录
RUN mkdir -p data logs

# 暴露端口
EXPOSE 3000

# 启动应用
CMD ["npm", "start"]
```

创建 `docker-compose.yml`:
```yaml
version: '3.8'
services:
  xray-web-manager:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - NODE_ENV=production
    restart: unless-stopped
```

## 🔧 配置说明

### 环境变量配置

创建 `.env` 文件:
```env
# 服务器配置
PORT=3000
NODE_ENV=production

# 数据库配置
DATABASE_PATH=./data/enhanced-xray-converter.db

# JWT配置
JWT_SECRET=your-super-secret-key-here
JWT_EXPIRES_IN=24h

# Docker配置
DOCKER_SOCKET=/var/run/docker.sock

# 日志配置
LOG_LEVEL=info
LOG_FILE=./logs/app.log
```

### 系统配置

```bash
# 1. 设置文件权限
chmod 600 .env
chmod 700 data/
chmod 755 logs/

# 2. 配置防火墙
sudo ufw allow 3000/tcp

# 3. 设置开机自启（使用systemd）
sudo tee /etc/systemd/system/xray-web-manager.service > /dev/null <<EOF
[Unit]
Description=Xray Web Manager
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/path/to/xray-web-manager
ExecStart=/usr/bin/node src/app.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable xray-web-manager
sudo systemctl start xray-web-manager
```

## 📊 功能验证

### 1. 基础功能测试

```bash
# 检查服务状态
curl http://localhost:3000/api/system/status

# 测试客户API
curl -X POST http://localhost:3000/api/customers \
  -H "Content-Type: application/json" \
  -d '{"wechat_id":"test001","wechat_name":"测试客户"}'

# 测试节点API
curl -X POST http://localhost:3000/api/nodes \
  -H "Content-Type: application/json" \
  -d '{"node_name":"测试节点","socks5_number":"TEST001","region_id":1,"ip_address":"1.2.3.4","port":1080}'
```

### 2. Web界面测试

1. 访问 `http://your-server:3000`
2. 使用默认管理员账户登录
3. 测试客户管理功能
4. 测试节点管理功能
5. 测试服务创建和分配

## 🔒 安全配置

### 1. 数据库安全

```bash
# 设置数据库文件权限
chmod 600 data/enhanced-xray-converter.db
chown www-data:www-data data/enhanced-xray-converter.db
```

### 2. Web安全

```javascript
// 在app.js中添加安全中间件
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

app.use(helmet());
app.use(rateLimit({
    windowMs: 15 * 60 * 1000, // 15分钟
    max: 100 // 限制每个IP 100次请求
}));
```

### 3. HTTPS配置

```bash
# 使用Let's Encrypt获取SSL证书
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# 配置Nginx反向代理
sudo tee /etc/nginx/sites-available/xray-web-manager > /dev/null <<EOF
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/xray-web-manager /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## 📈 监控和维护

### 1. 日志监控

```bash
# 查看应用日志
tail -f logs/app.log

# 查看系统服务日志
sudo journalctl -u xray-web-manager -f
```

### 2. 性能监控

```bash
# 安装PM2进程管理器
npm install -g pm2

# 使用PM2启动应用
pm2 start src/app.js --name xray-web-manager

# 监控应用性能
pm2 monit
```

### 3. 备份策略

```bash
# 创建自动备份脚本
cat > scripts/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/xray-web-manager"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# 备份数据库
cp data/enhanced-xray-converter.db "$BACKUP_DIR/db_backup_$DATE.db"

# 备份配置文件
tar -czf "$BACKUP_DIR/config_backup_$DATE.tar.gz" .env config/

# 清理7天前的备份
find "$BACKUP_DIR" -name "*.db" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x scripts/backup.sh

# 添加到crontab
echo "0 2 * * * /path/to/xray-web-manager/scripts/backup.sh" | crontab -
```

## 🎉 部署完成

恭喜！您已成功将Bash脚本项目升级为现代化的Web管理平台。

### 下一步建议

1. **用户培训**: 为团队成员提供新界面的使用培训
2. **功能扩展**: 根据实际需求添加更多管理功能
3. **性能优化**: 监控系统性能并进行必要的优化
4. **安全加固**: 定期更新依赖包和安全配置

### 技术支持

如需技术支持或功能定制，请参考项目文档或联系开发团队。
