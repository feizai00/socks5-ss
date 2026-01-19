# Xray Converter Management Platform

一个基于 Docker 的 Xray SOCKS5 转 Shadowsocks 可视化管理平台。

## ✨ 功能特性

*   **可视化管理**: 直观的 Web 界面管理节点、客户和服务。
*   **Docker 集成**: 自动管理 Xray 容器，实现端口和服务隔离。
*   **SOCKS5 转换**: 将 SOCKS5 代理转换为 Shadowsocks 协议，方便各类客户端连接。
*   **多用户/权限**: 内置 JWT 认证和角色管理。
*   **实时状态**: 监控容器运行状态。
*   **持久化存储**: 使用 SQLite 数据库，数据易于备份和迁移。

## 🚀 快速部署

### 方式一：一键安装（推荐）

适用于 Ubuntu 20.04+ / Debian 11+ / CentOS 8+ 系统。

```bash
# 下载并执行安装脚本 (请将 URL 替换为您的 GitHub 仓库 raw 地址)
bash <(curl -sL https://raw.githubusercontent.com/feizai00/socks5-ss-web/main/install.sh)
```

### 方式二：手动 Docker 部署

1.  **克隆仓库**
    ```bash
    git clone https://github.com/feizai00/socks5-ss-web.git
    cd socks5-ss-web
    ```

2.  **配置环境**
    ```bash
    cp .env.example .env
    # 编辑 .env 文件（可选，修改 JWT_SECRET 等）
    ```

3.  **构建并启动**
    ```bash
    chmod +x start.sh
    ./start.sh
    ```

4.  **访问系统**
    *   URL: `http://服务器IP:3000`
    *   默认账号: `admin`
    *   默认密码: `admin123`

## 📂 项目结构

```
.
├── backend/            # 后端 Node.js 源码 (Express + SQLite)
├── frontend/           # 前端 Vue 3 源码
├── docker-compose.yml  # Docker 编排文件
├── Dockerfile          # 多阶段构建镜像定义
├── install.sh          # 一键部署脚本
├── start.sh            # 本地启动脚本
└── .env.example        # 环境变量示例
```

## 🛠️ 开发指南

1.  **前端开发**
    ```bash
    cd frontend
    npm install
    npm run dev
    ```

2.  **后端开发**
    ```bash
    cd backend
    npm install
    npm run dev
    ```

## 📝 注意事项

*   请确保服务器已安装 `curl`, `git`。
*   安装脚本会自动尝试安装 `docker` 和 `docker-compose`。
*   生产环境建议配置 Nginx 反向代理并启用 HTTPS。
