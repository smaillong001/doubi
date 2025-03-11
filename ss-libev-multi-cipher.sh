#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 8+, Debian 11+, Ubuntu 18.04+
#	Description: Shadowsocks-libev Multi-User Management Script with Cipher Selection
#	Version: 1.1.0
#	Author: Adapted by Grok
#=================================================

# 颜色定义
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"

CONFIG_FILE="/etc/shadowsocks-libev/config.json"
SERVICE_FILE="/etc/systemd/system/shadowsocks-libev.service"

# 检查 root 权限
check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} 请使用 root 权限运行脚本（sudo su）" && exit 1
}

# 检查系统类型和版本
check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        version=$(cat /etc/redhat-release | grep -oE '[0-9]+' | head -1)
    elif [[ -f /etc/debian_version ]]; then
        release="debian"
        version=$(cat /etc/debian_version | cut -d'.' -f1)
    elif [[ -f /etc/lsb-release ]]; then
        release="ubuntu"
        version=$(grep DISTRIB_RELEASE /etc/lsb-release | cut -d'=' -f2 | cut -d'.' -f1)
    else
        echo -e "${Error} 不支持的操作系统！" && exit 1
    fi

    if [[ "$release" == "centos" && "$version" -lt 8 ]]; then
        echo -e "${Error} 需要 CentOS 8 或更高版本！" && exit 1
    elif [[ "$release" == "debian" && "$version" -lt 11 ]]; then
        echo -e "${Error} 需要 Debian 11 或更高版本！" && exit 1
    elif [[ "$release" == "ubuntu" && "$version" -lt 18 ]]; then
        echo -e "${Error} 需要 Ubuntu 18.04 或更高版本！" && exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${Info} 安装必要的依赖..."
    if [[ "$release" == "centos" ]]; then
        dnf update -y
        dnf install -y epel-release shadowsocks-libev jq
    elif [[ "$release" == "debian" || "$release" == "ubuntu" ]]; then
        apt-get update -y
        apt-get install -y shadowsocks-libev jq
    fi
}

# 选择加密方法
select_cipher() {
    echo -e "${Info} 请选择加密方法："
    echo -e "  ${Green_font_prefix}1.${Font_color_suffix} aes-256-gcm (推荐)"
    echo -e "  ${Green_font_prefix}2.${Font_color_suffix} chacha20-ietf-poly1305 (推荐)"
    echo -e "  ${Green_font_prefix}3.${Font_color_suffix} aes-128-gcm"
    echo -e "  ${Green_font_prefix}4.${Font_color_suffix} aes-192-gcm"
    echo -e "  ${Green_font_prefix}5.${Font_color_suffix} xchacha20-ietf-poly1305"
    echo -e "  ${Green_font_prefix}6.${Font_color_suffix} aes-256-ctr (传统)"
    echo -e "  ${Green_font_prefix}7.${Font_color_suffix} chacha20-ietf (传统)"
    read -p "请输入选项 [1-7] (默认: 2): " cipher_choice
    case "$cipher_choice" in
        1) cipher="aes-256-gcm" ;;
        2|"") cipher="chacha20-ietf-poly1305" ;;
        3) cipher="aes-128-gcm" ;;
        4) cipher="aes-192-gcm" ;;
        5) cipher="xchacha20-ietf-poly1305" ;;
        6) cipher="aes-256-ctr" ;;
        7) cipher="chacha20-ietf" ;;
        *) echo -e "${Error} 无效选项，使用默认 chacha20-ietf-poly1305" && cipher="chacha20-ietf-poly1305" ;;
    esac
    echo -e "${Info} 已选择加密方法: $cipher"
}

# 初始化配置文件
init_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${Info} 初始化 Shadowsocks-libev 配置文件..."
        mkdir -p /etc/shadowsocks-libev
        select_cipher
        cat > "$CONFIG_FILE" <<EOF
{
    "server": "0.0.0.0",
    "mode": "tcp_and_udp",
    "server_port": 8388,
    "password": "default_password",
    "timeout": 300,
    "method": "$cipher",
    "fast_open": false,
    "nameserver": "8.8.8.8",
    "port_password": {}
}
EOF
    fi
}

# 设置服务
setup_service() {
    echo -e "${Info} 设置 Shadowsocks-libev 服务..."
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Shadowsocks-libev Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ss-server -c $CONFIG_FILE
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable shadowsocks-libev
    systemctl start shadowsocks-libev
}

# 设置防火墙
set_firewall() {
    echo -e "${Info} 配置防火墙..."
    if [[ "$release" == "centos" ]]; then
        systemctl start firewalld
        systemctl enable firewalld
        firewall-cmd --add-port=8388/tcp --permanent
        firewall-cmd --add-port=8388/udp --permanent
        firewall-cmd --reload
    else
        ufw allow 8388/tcp
        ufw allow 8388/udp
        ufw reload
    fi
}

# 安装 Shadowsocks-libev
install_ss() {
    check_root
    check_sys
    install_dependencies
    init_config
    setup_service
    set_firewall
    echo -e "${Info} Shadowsocks-libev 安装完成！默认端口: 8388，默认密码: default_password"
}

# 添加用户
add_user() {
    echo -e "${Info} 添加新用户..."
    read -p "请输入端口 (1024-65535): " port
    [[ -z "$port" || "$port" -lt 1024 || "$port" -gt 65535 ]] && echo -e "${Error} 无效端口！" && exit 1
    read -p "请输入密码: " password
    [[ -z "$password" ]] && echo -e "${Error} 密码不能为空！" && exit 1

    # 检查端口是否已存在
    if jq -e ".port_password.\"$port\"" "$CONFIG_FILE" > /dev/null; then
        echo -e "${Error} 端口 $port 已存在！" && exit 1
    fi

    # 添加到配置文件
    jq ".port_password.\"$port\" = \"$password\"" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"

    # 更新防火墙
    if [[ "$release" == "centos" ]]; then
        firewall-cmd --add-port="$port/tcp" --permanent
        firewall-cmd --add-port="$port/udp" --permanent
        firewall-cmd --reload
    else
        ufw allow "$port/tcp"
        ufw allow "$port/udp"
        ufw reload
    fi

    systemctl restart shadowsocks-libev
    echo -e "${Info} 已添加用户 - 端口: $port, 密码: $password"
}

# 删除用户
delete_user() {
    echo -e "${Info} 删除用户..."
    list_users
    read -p "请输入要删除的端口: " port
    if ! jq -e ".port_password.\"$port\"" "$CONFIG_FILE" > /dev/null; then
        echo -e "${Error} 端口 $port 不存在！" && exit 1
    fi

    # 从配置文件中删除
    jq "del(.port_password.\"$port\")" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"

    # 更新防火墙
    if [[ "$release" == "centos" ]]; then
        firewall-cmd --remove-port="$port/tcp" --permanent
        firewall-cmd --remove-port="$port/udp" --permanent
        firewall-cmd --reload
    else
        ufw delete allow "$port/tcp"
        ufw delete allow "$port/udp"
        ufw reload
    fi

    systemctl restart shadowsocks-libev
    echo -e "${Info} 已删除端口 $port"
}

# 列出所有用户
list_users() {
    echo -e "${Info} 当前用户列表:"
    jq -r '.port_password | to_entries[] | "端口: \(.key), 密码: \(.value)"' "$CONFIG_FILE"
    current_cipher=$(jq -r '.method' "$CONFIG_FILE")
    echo -e "${Info} 当前加密方法: $current_cipher"
}

# 修改加密方法
modify_cipher() {
    echo -e "${Info} 修改加密方法..."
    select_cipher
    jq ".method = \"$cipher\"" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
    systemctl restart shadowsocks-libev
    echo -e "${Info} 加密方法已更新为: $cipher"
}

# 检查服务状态
check_status() {
    systemctl is-active shadowsocks-libev > /dev/null
    if [[ $? -eq 0 ]]; then
        echo -e "${Info} Shadowsocks-libev 正在运行"
    else
        echo -e "${Error} Shadowsocks-libev 未运行"
    fi
}

# 主菜单
menu() {
    echo -e "
  Shadowsocks-libev 多用户管理脚本
  --------------------------------
  ${Green_font_prefix}1.${Font_color_suffix} 安装 Shadowsocks-libev
  ${Green_font_prefix}2.${Font_color_suffix} 添加用户
  ${Green_font_prefix}3.${Font_color_suffix} 删除用户
  ${Green_font_prefix}4.${Font_color_suffix} 查看用户列表
  ${Green_font_prefix}5.${Font_color_suffix} 修改加密方法
  ${Green_font_prefix}6.${Font_color_suffix} 检查服务状态
  ${Green_font_prefix}7.${Font_color_suffix} 重启服务
  ${Green_font_prefix}8.${Font_color_suffix} 退出
  --------------------------------
"
    read -p "请输入选项 [1-8]: " choice
    case "$choice" in
        1) install_ss ;;
        2) add_user ;;
        3) delete_user ;;
        4) list_users ;;
        5) modify_cipher ;;
        6) check_status ;;
        7) systemctl restart shadowsocks-libev && echo -e "${Info} 服务已重启" ;;
        8) exit 0 ;;
        *) echo -e "${Error} 无效选项！" ;;
    esac
}

# 主循环
while true; do
    menu
done