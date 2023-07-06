#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  01.system-init.sh
#    CreateTime    ：  2023-07-06 10:09:14
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  对 rocky9 或 alma9 安装后的系统进行初始化，必须使用 root 账户
# =========================================================================================


SERVICE_DIR=$(cd "$(dirname "$0")" || exit; pwd)                               # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 组件安装根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
#USER=$(whoami)
export param_list=()                                                                  # 初始化参数列表


# 读取配置文件，获取配置参数
function read_param()
{
    # 1. 定义局部变量
    local line string
    
    # 2. 读取配置文件
    while read -r line
    do
        # 3. 去除 行首 和 行尾 的 空格 和 制表符
        string=$(echo "${line}" | sed -e 's/^[ \t]*//g' | sed -e 's/[ \t]*$//g')
        
        # 4. 判断是否为注释文字，是否为空行
        if [[ ! ${string} =~ ^# ]] && [ "" != "${string}" ]; then
            # 5. 去除末尾的注释，获取键值对参数
            param=$(echo "${string}" | awk -F '#' '{print $1}' | awk '{gsub(/^\s+|\s+$/, ""); print}')
            
            # 6. 将参数添加到参数列表
            param_list[${#param_list[@]}]="${param}"
        fi
    done < "${ROOT_DIR}/conf/${CONFIG_FILE}"
}


# 获取参数（$1：参数键值，$2：待替换的字符，$3：需要替换的字符，$4：后缀字符）
function get_param()
{
    local value=""
    for param in "${param_list[@]}"
    do
        if [[ ${param} =~ ^$1 ]]; then
            value=$(echo "${param}" | awk -F '=' '{print $2}' | tr "\'$2\'" "\'$3\'")
        fi
    done
    
    echo "${value}$4"
}


# 配置网卡
function network_init()
{
    # 定义局部变量
    local ip dns gateway
    
    ip=$(get_param  "server.ip")
    dns=$(get_param "server.dns" "," ";" ";")
    gateway=$(get_param "server.gateway")
    
    # 替换网卡配置文件中的参数
    sed -i "s|^address1=.*|address1=${ip},${gateway}|g" /etc/NetworkManager/system-connections/ens160.nmconnection
    sed -i "s|^dns=.*|dns=${dns}|g"                     /etc/NetworkManager/system-connections/ens160.nmconnection   
}


# 设置主机名与 hosts 映射
function host_init()
{
    # 定义参数
    local host_name ip_host_list
    
    host_name=$(get_param  "server.hostname")
    echo "${host_name}" > /etc/hostname
    
    ip_host_list=$(get_param "server.hosts" "," " ")
    for ip_host in ${ip_host_list}
    do
         echo "${ip_host//\:/    }"  >> /etc/hosts
    done
}


# 关闭防火墙 和 SELinux
function stop_protect()
{
    # 关闭防火墙
    systemctl stop    firewalld.service
    systemctl disable firewalld.service
    
    # 关闭 SELinux
    setenforce 0
    sed -i "s|SELINUX=enforcing|# SELINUX=enforcing\nSELinux=disabled|g" /etc/sysconfig/selinux
    echo "SELinux=disabled" >>       /etc/sysconfig/selinux
}


# 解除文件读写限制
function stop_protect()
{
    # 修改打开文件限制
    echo "*    soft    nproc      65536"      >> /etc/security/limits.conf
    echo "*    hard    nproc      65536"      >> /etc/security/limits.conf
    echo "*    soft    nofile     65536"      >> /etc/security/limits.conf
    echo "*    hard    nofile     65536"      >> /etc/security/limits.conf
    echo "*    soft    stack      20480"      >> /etc/security/limits.conf
    echo "*    hard    stack      20480"      >> /etc/security/limits.conf
    echo "*    soft    memlock    134217728"  >> /etc/security/limits.conf
    echo "*    hard    memlock    134217728"  >> /etc/security/limits.conf
    echo "*    soft    data       unlimited"  >> /etc/security/limits.conf
    echo "*    hard    data       unlimited"  >> /etc/security/limits.conf
    
    # 系统限制的文件最大值
    echo "65536" >> /proc/sys/fs/file-max                                 # 
}


# 优化内核
function kernel_optimize()
{
    /etc/sysctl.conf
    echo "vm.max_map_count             = 655360"               >> /etc/sysctl.conf
    echo "kernel.shmmni                = 4096"                 >> /etc/sysctl.conf 
    echo "kernel.shmmax                = 2147483648"           >> /etc/sysctl.conf 
    echo "kernel.shmall                = 2097152"              >> /etc/sysctl.conf 
    echo "kernel.sem                   = 250 32000 100 128"    >> /etc/sysctl.conf 
    echo "fs.aio-max-nr                = 1048576"              >> /etc/sysctl.conf
    echo "fs.file-max                  = 65536"                >> /etc/sysctl.conf 
    echo "fs.nr_open                   = 196680"               >> /etc/sysctl.conf    
    echo "vm.swappiness                = 40"                   >> /etc/sysctl.conf 
    echo "net.ipv4.ip_local_port_range = 1024 65536"           >> /etc/sysctl.conf 
    echo "net.core.rmem_max            = 16777216"             >> /etc/sysctl.conf
    echo "net.core.wmem_max            = 16777216"             >> /etc/sysctl.conf
    echo "net.ipv4.tcp_rmem            = 4096 87380 16777216"  >> /etc/sysctl.conf
    echo "net.ipv4.tcp_wmem            = 4096 65536 16777216"  >> /etc/sysctl.conf
    echo "net.ipv4.tcp_fin_timeout     = 10"                   >> /etc/sysctl.conf
    echo "net.ipv4.tcp_tw_recycle      = 1"                    >> /etc/sysctl.conf
    echo "net.ipv4.tcp_timestamps      = 0"                    >> /etc/sysctl.conf
    echo "net.ipv4.tcp_window_scaling  = 0"                    >> /etc/sysctl.conf
    echo "net.ipv4.tcp_sack            = 0"                    >> /etc/sysctl.conf
    echo "net.core.netdev_max_backlog  = 30000"                >> /etc/sysctl.conf
    echo "net.ipv4.tcp_no_metrics_save = 1"                    >> /etc/sysctl.conf
    echo "net.core.somaxconn           = 22144"                >> /etc/sysctl.conf
    echo "net.ipv4.tcp_syncookies      = 0"                    >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_orphans     = 262144"               >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog = 262144"               >> /etc/sysctl.conf
    echo "net.ipv4.tcp_synack_retries  = 2"                    >> /etc/sysctl.conf
    echo "net.ipv4.tcp_syn_retries     = 2"                    >> /etc/sysctl.conf
    echo "net.core.rmem_default        = 262144"               >> /etc/sysctl.conf
    echo "net.core.wmem_default        = 262144"               >> /etc/sysctl.conf
    echo "vm.overcommit_memory         = 1"                    >> /etc/sysctl.conf
}


# 添加管理员
function add_user()
{
    # 定义变量
    local user password
    
    user=$(get_param "server.user")                                            # 用户名
    password=$(get_param "server.password")                                    # 密码
    useradd -m -d "/home/${user}" -g "${user}" "${user}"                       # 添加用户，并指定密码
    echo "${password}" | passwd "${user}" --stdin                              # 修改用户的密码
    chmod u+w /etc/sudoers                                                     # 给文件添加可编辑权限
    sed -i "s|^root.*|root    ALL=\(ALL\)    ALL\n${user}    ALL=\(ALL\)    ALL|g" /etc/sudoers 
    chmod u+w /etc/sudoers                                                     # 取消可编辑权限
}


# 安装必要的软件包
function dnf_mirror()
{
    local mirror
    
    # 备份原来的路径
    mirror=$(get_mirror "dnf.image")
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^#baseurl=https://dl.rockylinux.org/\$contentdir|baseurl=${mirror}|g" \
        -i.bak /etc/yum.repos.d/[Rr]ocky-*.repo
    
    dnf clean all
    dnf makecache
    dnf update
    dnf upgrade   
}


# 安装必要的软件包
function install_rpm()
{
    local rpm_list=""
    rpm_list=$(get_param "dnf.rpm" "," " ")
    
    dnf install "${rpm_list}" -y
}


echo "============================================================================"
read_param
install_rpm
