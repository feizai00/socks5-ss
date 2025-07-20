# Xray SOCKS5 转 Shadowsocks Web管理平台设计方案

## 🎯 项目概述

将现有的Bash脚本转换为现代化的Web管理平台，提供直观的用户界面和强大的管理功能。

## 🏗️ 系统架构

### 技术栈选择

#### 后端 (推荐方案)
- **框架**: Node.js + Express.js
- **数据库**: SQLite (开发) / PostgreSQL (生产)
- **ORM**: Prisma 或 Sequelize
- **认证**: JWT + bcrypt
- **实时通信**: Socket.io
- **Docker集成**: dockerode

#### 前端
- **框架**: Vue.js 3 + TypeScript
- **UI库**: Element Plus
- **状态管理**: Pinia
- **路由**: Vue Router
- **HTTP客户端**: Axios
- **图表**: ECharts
- **二维码**: qrcode.js

## 📱 功能模块设计

### 1. 用户认证与权限管理
```
- 登录/注销
- 用户角色管理 (管理员/普通用户)
- 操作权限控制
- 会话管理
```

### 2. 仪表板 (Dashboard)
```
- 系统状态概览
- 服务运行统计
- 资源使用监控
- 最近操作日志
- 快速操作面板
```

### 3. 服务管理
```
- 服务列表 (表格/卡片视图)
- 添加新服务 (向导式界面)
- 编辑服务配置
- 启动/停止/重启服务
- 删除服务
- 批量操作
- 服务状态实时监控
```

### 4. 连接信息管理
```
- 连接信息展示
- 二维码生成和显示
- 连接链接复制
- 配置文件导出
- 分享功能
```

### 5. 有效期管理
```
- 服务有效期设置
- 过期提醒
- 自动过期处理
- 有效期批量修改
- 回收站管理
```

### 6. 系统维护
```
- 系统健康检查
- 服务自动修复
- Docker镜像管理
- 系统资源监控
- 日志查看和搜索
```

### 7. 备份与恢复
```
- 手动备份
- 自动备份设置
- 备份文件管理
- 一键恢复
- 备份验证
```

### 8. 安全管理
```
- IP白名单管理
- 访问日志
- 安全事件监控
- 防火墙规则管理
```

### 9. 批量操作
```
- SOCKS5代理批量导入
- 服务批量创建
- 配置批量导出
- 批量状态管理
```

## 🎨 用户界面设计

### 主要页面布局
```
├── 登录页面
├── 主界面
│   ├── 侧边导航栏
│   ├── 顶部工具栏
│   └── 主内容区域
│       ├── 仪表板
│       ├── 服务管理
│       ├── 系统监控
│       ├── 设置中心
│       └── 日志中心
```

### 响应式设计
- 桌面端: 完整功能界面
- 平板端: 适配触摸操作
- 移动端: 核心功能优化

## 🔧 技术实现要点

### 1. 后端API设计
```javascript
// RESTful API 设计示例
GET    /api/services           // 获取服务列表
POST   /api/services           // 创建新服务
GET    /api/services/:id       // 获取服务详情
PUT    /api/services/:id       // 更新服务
DELETE /api/services/:id       // 删除服务
POST   /api/services/:id/start // 启动服务
POST   /api/services/:id/stop  // 停止服务

GET    /api/system/status      // 系统状态
POST   /api/system/backup      // 创建备份
GET    /api/logs               // 获取日志
```

### 2. 实时功能实现
```javascript
// WebSocket 事件
socket.on('service-status-changed', (data) => {
  // 更新服务状态
});

socket.on('system-log', (log) => {
  // 实时日志显示
});

socket.on('backup-progress', (progress) => {
  // 备份进度更新
});
```

### 3. 数据库设计
```sql
-- 服务表
CREATE TABLE services (
  id INTEGER PRIMARY KEY,
  port INTEGER UNIQUE NOT NULL,
  password TEXT NOT NULL,
  method TEXT DEFAULT 'aes-256-gcm',
  socks_servers JSON NOT NULL,
  status TEXT DEFAULT 'active',
  expires_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 用户表
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT DEFAULT 'user',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 操作日志表
CREATE TABLE operation_logs (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  action TEXT NOT NULL,
  target TEXT,
  details JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🚀 开发阶段规划

### 第一阶段: 核心功能 (2-3周)
- [ ] 项目初始化和环境搭建
- [ ] 用户认证系统
- [ ] 基础服务管理功能
- [ ] Docker集成
- [ ] 基础UI界面

### 第二阶段: 高级功能 (2-3周)
- [ ] 实时监控和日志
- [ ] 备份恢复功能
- [ ] 批量操作
- [ ] 系统维护功能
- [ ] 移动端适配

### 第三阶段: 优化完善 (1-2周)
- [ ] 性能优化
- [ ] 安全加固
- [ ] 用户体验优化
- [ ] 文档完善
- [ ] 测试覆盖

## 💡 开发建议

### 1. 渐进式迁移
- 保留现有脚本作为后端服务
- 通过API包装现有功能
- 逐步重构核心逻辑

### 2. 容器化部署
```dockerfile
# 示例 Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

### 3. 配置管理
```yaml
# docker-compose.yml
version: '3.8'
services:
  web-app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
    environment:
      - NODE_ENV=production
      - DATABASE_URL=sqlite:./data/app.db
```

## 🔒 安全考虑

### 1. 认证与授权
- JWT token 过期机制
- 角色基础的访问控制
- API 速率限制

### 2. 数据安全
- 敏感数据加密存储
- HTTPS 强制使用
- 输入验证和清理

### 3. 系统安全
- Docker socket 安全访问
- 文件权限控制
- 审计日志记录

## 📊 性能优化

### 1. 前端优化
- 组件懒加载
- 虚拟滚动
- 缓存策略

### 2. 后端优化
- 数据库索引
- 查询优化
- 缓存机制

### 3. 部署优化
- CDN 加速
- 负载均衡
- 监控告警
