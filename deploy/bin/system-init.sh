#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  system-init.sh
#    CreateTime    ：  2023-07-06 10:09:14
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  对 rocky9 或 alma9 安装后的系统进行初始化，必须使用 root 账户
# =========================================================================================


SERVICE_DIR=$(cd "$(dirname "$0")" || exit; pwd)                               # shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="system-init-$(date +%F).log"                                         # 程序操作日志文件


# 读取配置文件，获取配置参数
function read_param()
{
    # 1. 定义局部变量
    local line string param_list=()
    
    # 2. 读取配置文件
    while read -r line
    do
        # 3. 去除 行首 和 行尾 的 空格 和 制表符
        string=$(echo "${line}" | sed -e 's/^[ \t]*//g' | sed -e 's/[ \t]*$//g')
        
        # 4. 判断是否为注释文字，是否为空行
        if [[ ! ${string} =~ ^# ]] && [ "" != "${string}" ]; then
            # 5. 去除末尾的注释，获取键值对参数，再去除首尾空格，为防止列表中空格影响将空格转为 #
            param=$(echo "${string}" | awk -F '#' '{print $1}' | awk '{gsub(/^\s+|\s+$/, ""); print}' | tr ' |\t' '#')
            
            # 6. 将参数添加到参数列表
            param_list[${#param_list[@]}]="${param}"
        fi
    done < "$1"
    
    # 将参数列表进行返回
    echo "${param_list[@]}"
}


# 获取参数（$1：参数键值，$2：待替换的字符，$3：需要替换的字符，$4：后缀字符）
function get_param()
{
    # 定义局部变量
    local param_list value
    
    # 获取参数，并进行遍历
    param_list=$(read_param "${ROOT_DIR}/conf/${CONFIG_FILE}")
    for param in ${param_list}
    do
        # 判断参数是否符合以 键 开始，并对键值对进行 切割 和 替换 
        if [[ ${param} =~ ^$1 ]]; then
            value=$(echo "${param//#/ }" | awk -F '=' '{print $2}' | awk '{gsub(/^\s+|\s+$/, ""); print}' | tr "\'$2\'" "\'$3\'")
        fi
    done
    
    # 返回结果
    echo "${value}$4"
}


# 判断文件中参数是否存在，不存在就文件末尾追加（$1：待追加的参数，$2：文件绝对路径）
function append_param()
{
    # 定义参数
    local exist
    
    # 根据文件获取该文件中，是否存在某参数，不存在就追加到文件末尾
    exist=$(grep -ni "$1" "$2")
    if [ -z "${exist}" ]; then 
        echo "$1" >> "$2"
    fi
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
    
    # 替换网卡配置文件中的参数：ipv4地址、网关、DNS
    sed -i "s|^address1=.*|address1=${ip},${gateway}|g" /etc/NetworkManager/system-connections/ens160.nmconnection
    sed -i "s|^dns=.*|dns=${dns}|g"                     /etc/NetworkManager/system-connections/ens160.nmconnection
    
    { nmcli connection reload; nmcli connection down ens160; nmcli connection up ens160; } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
}


# 设置主机名与 hosts 映射
function host_init()
{
    echo "    ***************************** 设置主机名映射 *****************************    "    
    # 定义参数
    local host_name ip_host_list item
    
    # 配置主机名
    host_name=$(get_param  "server.hostname")
    echo "${host_name}" > /etc/hostname
    
    # 添加主机和 ip 映射
    ip_host_list=$(get_param "server.hosts" "," " ")
    for item in ${ip_host_list}
    do
        append_param "${item//\:/    }"  /etc/hosts
    done
}


# 关闭防火墙 和 SELinux
function stop_protect()
{
    echo "    ******************************* 关闭防火墙 *******************************    "  
    # 定义参数
    local exist
    
    # 关闭防火墙
    systemctl stop    firewalld.service
    systemctl disable firewalld.service  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    # 关闭 SELinux
    setenforce 0                                                               # 临时关闭
    exist=$(grep -ni "^selinux=disabled" /etc/sysconfig/selinux)               # 永久关闭，需要重启系统
    if [ -z "${exist}" ]; then
        sed -i "s|SELINUX=enforcing|# SELINUX=enforcing\nSELINUX=disabled|g" /etc/sysconfig/selinux 
    fi
}


# 解除文件读写限制
function unlock_limit()
{
    echo "    **************************** 修改打开文件限制 ****************************    "
    
    # 配置用户打开文件限制
    cp -fpr "${ROOT_DIR}/conf/limits.conf" /etc/security/limits.d/     
    
    # 系统限制的文件最大值，RedHat 9 系列无需操作
    # append_param "65536" /proc/sys/fs/file-max                               # RedHat 9 默认值：9223372036854775807
}


# 优化内核
function kernel_optimize()
{
    echo "    ******************************** 优化内核 ********************************    "
    # 定义参数
    local param_list
    
    # 获取配置文件中所有的参数
    param_list=$(read_param "${ROOT_DIR}/conf/sysctl.conf")
    for param in ${param_list}
    do 
        sysctl -w "${param//#/}"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1       # 对内核进行临时修改，仅当前会话生效
        append_param "${param//#/ }" /etc/sysctl.conf                          # 对内核进行永久修改，仅重启后才生效
    done
    
    sysctl -p  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1                            # 刷新配置
}


# 添加管理员
function add_user()
{
    echo "    ******************************** 添加用户 ********************************    "
    # 定义变量
    local user password exist
    
    user=$(get_param "server.user")                                            # 用户名
    useradd -m "${user}"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1               # 添加用户，并指定密码
    
    password=$(get_param "server.password")                                    # 密码
    echo "${password}" | passwd "${user}" --stdin >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1      # 修改用户的密码
    
    chmod u+w /etc/sudoers                                                     # 给文件添加可编辑权限
    # 给用户添加管理员权限
    exist=$(grep -ni "^${user}"  /etc/sudoers)
    if [[ -z "${exist}" ]]; then
        sed -i "s|^root.*|root    ALL=\(ALL\)    ALL\n${user}    ALL=\(ALL\)    ALL|g" /etc/sudoers
    fi
    chmod u-w /etc/sudoers                                                     # 取消可编辑权限
}


# 替换 dnf 镜像
function dnf_mirror()
{
    echo "    ******************************* 替换镜像源 *******************************    "
    # 定义变量
    local mirror exist
    
    # 备份原来的路径
    mirror=$(get_param "dnf.image")
    
    # 备份原来的源，并修改源
    exist=$(echo "${mirror}" | grep -i "rocky")
    if [[ -n "${exist}" ]]; then
        sed -e "s|^mirrorlist=|#mirrorlist=|g" \
            -e "s|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=${mirror}|g"  \
            -e "s|^#baseurl=https://dl.rockylinux.org/\$contentdir|baseurl=${mirror}|g" \
            -i.bak /etc/yum.repos.d/[Rr]ocky*.repo
    else
        sed -e "s|^mirrorlist=|#mirrorlist=|g" \
            -e "s|^# baseurl=http://repo.almalinux.org|baseurl=${mirror}|g"  \
            -e "s|^# baseurl=https://repo.almalinux.org|baseurl=${mirror}|g" \
            -i.bak /etc/yum.repos.d/almalinux*.repo
    fi
    
    #  更新源缓存和软件 
    { dnf clean all; dnf makecache; dnf update  -y; dnf upgrade -y; }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
}


# 安装必要的软件包
function install_rpm()
{
    echo "    ******************************* 安装软件包 *******************************    "
    # 定义变量
    local rpm_list rpm
    
    # 获取安装软件包名称
    rpm_list=$(get_param "dnf.rpm" "," " ")
    for rpm in ${rpm_list}
    do
        echo "    +++++++++++++++++++++++++ 安装 ${rpm} +++++++++++++++++++++++++    "
        dnf install "${rpm}" -y    >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    done    
}


printf "\n================================================================================\n"
mkdir -p "${ROOT_DIR}/logs"                                                    # 创建日志目录

# 匹配输入参数
case "$1" in
    # 1. 配置网卡
    network | -n)
        network_init
    ;;

    # 2. 设置主机名与 hosts 映射
    host | -h)
        host_init
    ;;
    
    # 3. 关闭防火墙 和 SELinux
    stop | -s)
        stop_protect
    ;;
    
    # 4. 解除文件读写限制
    unlock | -u)
        unlock_limit
    ;;
    
    # 5. 优化内核
    knernel | -k)
        kernel_optimize
    ;;
        
    # 6. 添加管理员
    add | -c)
        add_user
    ;;
    
    # 7. 替换 dnf 镜像
    dnf | -d)
        dnf_mirror
    ;;
    
    # 8. 安装必要的软件包
    install | -i)
        install_rpm
    ;;
    
    # 9. 安装必要的软件包
    all | -a)
        network_init
        sleep 1
        host_init
        sleep 1
        stop_protect
        sleep 1
        unlock_limit
        sleep 1
        kernel_optimize
        sleep 1
        add_user
        sleep 1
        dnf_mirror
        sleep 1
        install_rpm
    ;;
    
    # 10. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：     "
        echo "        +-------------+--------------+ "
        echo "        |    参 数    |    描  述    | "
        echo "        +-------------+--------------+ "
        echo "        |   network   |   配置网卡   | "
        echo "        |   host      |   主机映射   | "
        echo "        |   stop      |   关闭保护   | "
        echo "        |   unlock    |   解除限制   | "
        echo "        |   kernel    |   优化内核   | "
        echo "        |   add       |   添加用户   | "
        echo "        |   dnf       |   替换镜像   | "
        echo "        |   install   |   安装软件   | "
        echo "        |   all       |   执行全部   | "
        echo "        +-------------+--------------+ "
    ;;
esac
printf "================================================================================\n\n"
exit 0
