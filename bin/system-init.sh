#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  system-init.sh
#    CreateTime    ：  2023-07-06 10:09:14
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  对 rocky9 或 alma9 安装后的系统进行初始化，必须使用 root 账户
# =========================================================================================


SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="system-init-$(date +%F).log"                                         # 程序操作日志文件


# 配置网卡
function network_init()
{
    echo "    ****************************** 配置网卡信息 ******************************    "
    # 定义局部变量
    local ip dns gateway network_type
    
    ip=$(get_param  "server.ip")
    dns=$(get_param "server.dns" "," ";" ";")
    gateway=$(get_param "server.gateway")
    
    # 替换网卡配置文件中的参数：ipv4地址、网关、DNS
    # network_type=$(grep -Pozin "\[ipv4\]\nmethod=auto" /etc/NetworkManager/system-connections/ens160.nmconnection | wc -l)
    network_type=$(grep -Pozin "\[ipv4\]\nmethod=auto" /home/issac/ens160.nmconnection | wc -l)
     
    if [[ "${network_type}" -gt 0  ]]; then
        sed -i ":label;N;s|\[ipv4\]\nmethod=auto|\[ipv4\]\nmethod=manual\naddress1=${ip},${gateway}\ndns=${dns}|g;t label" /home/issac/ens160.nmconnection
    else
        sed -i "s|^address1=.*|address1=${ip},${gateway}|g" /home/issac/ens160.nmconnection
        sed -i "s|^dns=.*|dns=${dns}|g"                     /home/issac/ens160.nmconnection
    fi
    
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
    local user password exist software_home
    
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
    
    touch "/etc/profile.d/${user}.sh"                                          # 为用户添加环境配置变量
    chown -R "${user}:${user}" "/etc/profile.d/${user}.sh"                     # 将文件的权限授予新添加的用户
    
    software_home=$(get_param "software.software.home")                        # 获取软件安装根路径
    chown -R "${user}:${user}" "${software_home}"                              # 将软件安装路径的权限授予新添加的用户
    
    { echo ""; echo "set number"; echo ""; }  >> /etc/vimrc                    # 添加 vim 显示行号配置
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
        echo "    +>+>+>+>+>+>+>+>+>+> 安装 ${rpm}    "
        dnf install "${rpm}" -y    >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    done    
}


# 给 Shell 脚本添加可执行权限
function add_execute()
{
    echo "    ***************************** 添加可执行权限 *****************************    "
    # 定义变量
    local item server_hosts=" "
    
    find "${ROOT_DIR}" -iname "*.sh" -o -iname "*.py" -type f -exec dos2unix {} +  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   # 将文件 Windows 换行符改为 UNIX 格式
    find "${ROOT_DIR}" -iname "*.sh" -o -iname "*.py" -type f -exec chmod +x {} +  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   # 给脚本添加可执行权限
    
    cp -frp  "${ROOT_DIR}/script/system/xcall.sh"  /usr/bin/                   # 将 集群间查看命令 脚本复制到系统路径
    cp -frp  "${ROOT_DIR}/script/system/xync.sh"   /usr/bin/                   # 将 集群之间进行文件同步 脚本复制到系统路径
    
    # 获取所有主机名
    for item in $(get_param "server.hosts" "," " ")
    do
        server_hosts="${server_hosts}$(echo "${item}" | awk -F ':' '{print $NF}') "
    done
    
    sed -i "s|\${server_hosts}|${server_hosts}|g"  /usr/bin/xcall.sh           # 修改集群 主机列表
    sed -i "s|\${server_hosts}|${server_hosts}|g"  /usr/bin/xync.sh            # 修改集群 主机列表
}


if [ "$#" -gt 0 ]; then
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    # shellcheck source=./common.sh
    source "${SERVICE_DIR}/common.sh" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   # 获取公共函数
    add_execute                                                                # 给脚本添加可执行权限    
fi

printf "\n================================================================================\n"
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

if [ "$#" -gt 0 ]; then
    echo ""
    echo "    部分配置必须重启才能生效，可运行以下命令："
    echo "        shutdown -r 5"    
fi

printf "================================================================================\n\n"
exit 0
