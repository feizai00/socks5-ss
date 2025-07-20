# Xray SOCKS5 转换器管理平台 - 前端

基于 Vue.js 3 + Element Plus 构建的现代化管理界面，为 Xray SOCKS5 到 Shadowsocks 代理转换提供完整的 Web 管理功能。

## ✨ 特性

- 🎨 **现代化设计** - 基于 Element Plus 的美观界面
- 📱 **响应式布局** - 完美适配桌面端和移动端
- 🌙 **主题切换** - 支持明暗主题切换
- 🔐 **权限管理** - 完整的用户认证和权限控制
- 📊 **数据可视化** - 丰富的图表和统计信息
- 🚀 **高性能** - 基于 Vite 的快速构建和热更新

## 🛠️ 技术栈

- **框架**: Vue.js 3 (Composition API)
- **构建工具**: Vite 4
- **UI 库**: Element Plus
- **状态管理**: Pinia
- **路由**: Vue Router 4
- **HTTP 客户端**: Axios
- **图表**: ECharts + Vue-ECharts
- **样式**: SCSS
- **工具库**: Day.js, QRCode.js

## 📦 安装

```bash
# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 构建生产版本
npm run build

# 预览生产构建
npm run preview

# 代码检查
npm run lint

# 代码格式化
npm run format
```

## 🏗️ 项目结构

```
frontend/
├── public/                 # 静态资源
├── src/
│   ├── api/               # API 接口
│   ├── assets/            # 资源文件
│   ├── components/        # 通用组件
│   ├── layout/            # 布局组件
│   ├── router/            # 路由配置
│   ├── stores/            # Pinia 状态管理
│   ├── styles/            # 全局样式
│   ├── utils/             # 工具函数
│   ├── views/             # 页面组件
│   ├── App.vue            # 根组件
│   └── main.js            # 入口文件
├── .env.development       # 开发环境配置
├── .env.production        # 生产环境配置
├── index.html             # HTML 模板
├── package.json           # 项目配置
├── vite.config.js         # Vite 配置
└── README.md              # 项目说明
```

## 🎯 主要功能

### 🏠 仪表板
- 系统状态概览
- 实时统计数据
- 图表可视化
- 快速操作入口

### 👥 客户管理
- 客户信息管理
- 微信号和联系方式
- 服务使用情况
- 批量操作支持

### 🌐 节点管理
- SOCKS5 节点管理
- 地区分类
- 连接状态监控
- 性能统计

### ⚙️ 服务管理
- Shadowsocks 服务创建
- 客户分配管理
- 连接信息和二维码
- 批量操作

### 📊 统计分析
- 使用情况统计
- 性能监控
- 趋势分析
- 报表导出

### 🔧 系统设置
- 用户管理
- 权限配置
- 系统参数
- 备份恢复

## 🎨 界面预览

### 登录页面
- 现代化登录界面
- 功能特性展示
- 响应式设计

### 仪表板
- 统计卡片
- 图表展示
- 快速操作
- 系统信息

### 管理页面
- 数据表格
- 筛选搜索
- 批量操作
- 详情对话框

## 🔧 开发指南

### 环境要求
- Node.js 16+
- npm 8+ 或 yarn 1.22+

### 开发流程
1. 克隆项目并安装依赖
2. 配置环境变量
3. 启动开发服务器
4. 开始开发

### 代码规范
- 使用 ESLint 进行代码检查
- 使用 Prettier 进行代码格式化
- 遵循 Vue.js 官方风格指南

### 组件开发
- 使用 Composition API
- 组件命名采用 PascalCase
- 合理使用 Props 和 Emits

### 状态管理
- 使用 Pinia 进行状态管理
- 按功能模块划分 Store
- 合理使用 computed 和 watch

## 📱 响应式设计

### 断点设置
- 移动端: < 768px
- 平板端: 768px - 1024px
- 桌面端: > 1024px

### 适配策略
- 移动端优先设计
- 弹性布局和网格系统
- 触摸友好的交互

## 🚀 部署

### 构建
```bash
npm run build
```

### 部署到 Nginx
```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /path/to/dist;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Docker 部署
```dockerfile
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## 🔒 安全考虑

- JWT Token 管理
- API 请求拦截
- XSS 防护
- CSRF 防护
- 输入验证

## 📈 性能优化

- 路由懒加载
- 组件按需加载
- 图片懒加载
- 代码分割
- 缓存策略

## 🐛 调试

### 开发工具
- Vue DevTools
- 浏览器开发者工具
- Network 面板
- Console 日志

### 常见问题
1. API 请求失败 - 检查后端服务状态
2. 路由跳转异常 - 检查路由配置
3. 样式异常 - 检查 CSS 优先级
4. 组件渲染问题 - 检查数据流

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 支持

如有问题，请联系开发团队或查看项目文档。
