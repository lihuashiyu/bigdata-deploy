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
LOG_FILE="system-init-$(date +%F).log"                                         # 程序操作日志文件
export param_list=()                                                           # 初始化参数列表


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
    # 定义局部变量
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
    echo "    ****************************** 配置网卡信息 ******************************    "
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
    echo "    ***************************** 设置主机名映射 *****************************    "    
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
    echo "    ******************************* 关闭防火墙 *******************************    "  
    # 关闭防火墙
    systemctl stop    firewalld.service
    systemctl disable firewalld.service
    
    # 关闭 SELinux
    setenforce 0
    sed -i "s|SELINUX=enforcing|# SELINUX=enforcing\nSELinux=disabled|g" /etc/sysconfig/selinux 
    echo "SELinux=disabled" >>       /etc/sysconfig/selinux
}


# 解除文件读写限制
function unlock_limit()
{
    echo "    **************************** 修改打开文件限制 ****************************    "  
    
    # 修改打开文件限制
    cat "${ROOT_DIR}/conf/limits.conf" >> /etc/security/limits.conf    
    
    # 系统限制的文件最大值
    echo "65536" >> /proc/sys/fs/file-max                                 # 
}


# 优化内核
function kernel_optimize()
{
    echo "    ******************************** 优化内核 ********************************    "
    cat "${ROOT_DIR}/conf/sysctl.conf" >> /etc/sysctl.conf
}


# 添加管理员
function add_user()
{
    echo "    ******************************** 添加用户 ********************************    "
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


# 替换 dnf 镜像
function dnf_mirror()
{
    echo "    ******************************* 替换镜像源 *******************************    "
    # 定义变量
    local mirror
    
    # 备份原来的路径
    mirror=$(get_mirror "dnf.image")
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^#baseurl=https://dl.rockylinux.org/\$contentdir|baseurl=${mirror}|g" \
        -i.bak /etc/yum.repos.d/[Rr]ocky-*.repo
    
    { dnf clean all; dnf makecache; dnf update; dnf upgrade; }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
}


# 安装必要的软件包
function install_rpm()
{
    echo "    ******************************* 安装软件包 *******************************    "
    # 定义变量
    local rpm_list=""
    
    rpm_list=$(get_param "dnf.rpm" "," " ")
    
    dnf install "${rpm_list}" -y    >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
}


printf "\n================================================================================\n"
read_param                                                                     # 读取配置文件，获取参数
mkdir -p "${ROOT_DIR}/logs"                                                    # 创建日志目录

# 匹配输入参数
case "$1" in
    # 1. 配置网卡
    network)
        network_init
    ;;

    # 2. 设置主机名与 hosts 映射
    host)
        host_init
    ;;
    
    # 3. 关闭防火墙 和 SELinux
    stop)
        stop_protect
    ;;
    
    # 4. 解除文件读写限制
    unlock)
        unlock_limit
    ;;
    
    # 5. 优化内核
    knernel)
        kernel_optimize
    ;;
        
    # 6. 添加管理员
    add)
        add_user
    ;;
    
    # 7. 替换 dnf 镜像
    dnf)
        dnf_mirror
    ;;
    
    # 8. 安装必要的软件包
    install)
        install_rpm
    ;;
    
    # 9. 安装必要的软件包
    all)
        network_init
        host_init
        stop_protect
        unlock_limit
        kernel_optimize
        add_user
        dnf_mirror
        install_rpm
    ;;
    
    # 10. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：                       "
        echo "        +-------------------+--------------+ "
        echo "        |       参 数       |    描  述    | "
        echo "        +-------------------+--------------+ "
        echo "        |  network_init     |   配置网卡   | "
        echo "        |  host_init        |   主机映射   | "
        echo "        |  stop_protectt    |   关闭保护   | "
        echo "        |  unlock_limit     |   解除限制   | "
        echo "        |  kernel_optimize  |   优化内核   | "
        echo "        |  add_user         |   添加用户   | "
        echo "        |  dnf_mirror       |   替换镜像   | "
        echo "        |  install_rpm      |   安装软件   | "
        echo "        |  all              |   执行全部   | "
        echo "        +-------------------+--------------+ "
    ;;
esac
printf "================================================================================\n\n"
exit 0
