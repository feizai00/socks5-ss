#!/bin/bash

# Git仓库上传脚本
# 使用方法: ./upload-to-git.sh

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# 检查Git是否安装
check_git() {
    if ! command -v git &> /dev/null; then
        log_error "Git未安装，请先安装Git"
        exit 1
    fi
    log_info "Git检查通过"
}

# 配置Git用户信息
configure_git() {
    log_info "配置Git用户信息..."
    
    # 检查是否已配置
    if ! git config --global user.name &> /dev/null; then
        read -p "请输入您的Git用户名: " git_username
        git config --global user.name "$git_username"
    fi
    
    if ! git config --global user.email &> /dev/null; then
        read -p "请输入您的Git邮箱: " git_email
        git config --global user.email "$git_email"
    fi
    
    log_info "Git用户信息配置完成"
    echo "用户名: $(git config --global user.name)"
    echo "邮箱: $(git config --global user.email)"
}

# 初始化Git仓库
init_repository() {
    log_info "初始化Git仓库..."
    
    if [ ! -d ".git" ]; then
        git init
        log_info "Git仓库初始化完成"
    else
        log_warn "Git仓库已存在"
    fi
}

# 添加文件到Git
add_files() {
    log_info "添加文件到Git..."
    
    # 创建.gitignore如果不存在
    if [ ! -f ".gitignore" ]; then
        log_warn ".gitignore文件不存在，将创建默认配置"
        cat > .gitignore << 'EOF'
# 依赖文件
node_modules/
*.log

# 环境变量
.env
.env.local

# 构建输出
dist/
build/

# 数据文件
data/
logs/
uploads/
backups/

# 编辑器
.vscode/
.idea/

# 系统文件
.DS_Store
Thumbs.db
EOF
    fi
    
    # 添加所有文件
    git add .
    
    log_info "文件添加完成"
}

# 提交代码
commit_code() {
    log_info "提交代码..."
    
    # 检查是否有变更
    if git diff --cached --quiet; then
        log_warn "没有文件变更，跳过提交"
        return
    fi
    
    # 提交代码
    git commit -m "Initial commit: Xray SOCKS5 to Shadowsocks Management Platform

Features:
- Complete web management interface
- Customer management system
- Node management with testing
- Service management with configuration
- Real-time monitoring and statistics
- Docker containerization
- Production deployment scripts"
    
    log_info "代码提交完成"
}

# 添加远程仓库
add_remote() {
    log_info "配置远程仓库..."
    
    echo "请先在GitHub上创建一个新仓库："
    echo "1. 访问 https://github.com/new"
    echo "2. Repository name: xray-converter"
    echo "3. 不要勾选 'Initialize this repository with a README'"
    echo "4. 点击 'Create repository'"
    echo
    
    read -p "请输入您的GitHub用户名: " github_username
    read -p "请输入仓库名称 [xray-converter]: " repo_name
    repo_name=${repo_name:-xray-converter}
    
    remote_url="https://github.com/${github_username}/${repo_name}.git"
    
    # 检查是否已有远程仓库
    if git remote get-url origin &> /dev/null; then
        log_warn "远程仓库已存在，将更新URL"
        git remote set-url origin "$remote_url"
    else
        git remote add origin "$remote_url"
    fi
    
    log_info "远程仓库配置完成: $remote_url"
}

# 推送代码
push_code() {
    log_info "推送代码到GitHub..."
    
    # 设置主分支
    git branch -M main
    
    # 推送代码
    if git push -u origin main; then
        log_info "代码推送成功！"
        
        # 获取远程URL
        remote_url=$(git remote get-url origin)
        repo_url=${remote_url%.git}
        
        echo
        echo "🎉 恭喜！代码已成功上传到GitHub"
        echo "仓库地址: $repo_url"
        echo
        echo "下一步："
        echo "1. 访问您的GitHub仓库确认代码已上传"
        echo "2. 复制仓库地址用于服务器部署"
        echo "3. 在服务器上运行部署脚本"
    else
        log_error "代码推送失败"
        echo
        echo "可能的原因："
        echo "1. GitHub仓库不存在或URL错误"
        echo "2. 没有推送权限"
        echo "3. 网络连接问题"
        echo
        echo "解决方案："
        echo "1. 确认GitHub仓库已创建"
        echo "2. 检查用户名和仓库名是否正确"
        echo "3. 确认网络连接正常"
        exit 1
    fi
}

# 显示仓库信息
show_repo_info() {
    echo
    echo "=================================="
    echo "📦 仓库信息"
    echo "=================================="
    echo "本地路径: $(pwd)"
    echo "远程仓库: $(git remote get-url origin 2>/dev/null || echo '未配置')"
    echo "当前分支: $(git branch --show-current 2>/dev/null || echo '未知')"
    echo "最后提交: $(git log -1 --pretty=format:'%h - %s (%cr)' 2>/dev/null || echo '无提交')"
    echo "=================================="
}

# 主函数
main() {
    echo "🚀 开始上传代码到GitHub"
    echo
    
    check_git
    configure_git
    init_repository
    add_files
    commit_code
    add_remote
    push_code
    show_repo_info
    
    echo
    echo "✅ 上传完成！现在可以在服务器上部署了。"
}

# 运行主函数
main "$@"
