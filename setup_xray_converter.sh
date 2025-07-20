#!/bin/bash
# Xray SOCKS5 to Shadowsocks Converter - 主脚本

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 导入配置和各个模块
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/service_management.sh"
source "$SCRIPT_DIR/expiry_management.sh"
source "$SCRIPT_DIR/system_maintenance.sh"
source "$SCRIPT_DIR/backup_restore.sh"
source "$SCRIPT_DIR/security_management.sh"

# --- Main Menu ---

main_menu() {
    while true; do
        clear_screen
        echo "Xray SOCKS5 -> Shadowsocks 管理脚本"
        echo "==================================="
        echo "1. 添加一个新的转换服务"
        echo "2. 列出所有服务"
        echo "3. 查看服务连接信息 (链接/二维码)"
        echo "4. 停止一个服务"
        echo "5. 启动一个服务"
        echo "6. 删除一个服务"
        echo "e. 编辑现有服务"
        echo "---------------------------------"
        echo "7. 系统自检"
        echo "8. 重启所有服务"
        echo "9. 一键修复所有服务"
        echo "---------------------------------"
        echo "b. 备份所有服务配置"
        echo "r. 从备份恢复服务"
        echo "a. 设置自动备份"
        echo "---------------------------------"
        echo "i. 批量导入SOCKS5代理"
        echo "x. 导出服务配置"
        echo "---------------------------------"
        echo "w. 管理IP白名单"
        echo "u. 升级Docker镜像"
        echo "---------------------------------"
        echo "t. 修改服务有效期"
        echo "n. 添加/修改服务备注"
        echo "c. 检查过期服务"
        echo "s. 设置自动检查过期服务"
        echo "m. 管理回收站"
        echo "---------------------------------"
        echo "q. 退出脚本"
        echo "==================================="
        read -p "请输入选项: " choice

        case $choice in
            1) add_service ;;
            2) list_services ;;
            3) view_service_info ;;
            4) manage_service_state "stop" ;;
            5) manage_service_state "start" ;;
            6) delete_service ;;
            e|E) edit_service ;;
            7) system_diagnostic ;;
            8) restart_all_services ;;
            9) repair_all_services ;;
            b|B) backup_services ;;
            r|R) restore_services ;;
            a|A) setup_auto_backup ;;
            i|I) batch_import_proxies ;;
            x|X) export_services ;;
            w|W) manage_ip_whitelist ;;
            u|U) upgrade_docker_image ;;
            t|T) modify_service_expiry ;;
            n|N) add_service_remark ;;
            c|C) check_expired_services ;;
            s|S) setup_expiry_check ;;
            m|M) manage_recycle_bin ;;
            q|Q) echo "正在退出..."; exit 0 ;;
            *) echo "无效的选项，请重试。" && sleep 1 ;;
        esac
    done
}

# --- Script Entry Point ---
initial_setup
main_menu