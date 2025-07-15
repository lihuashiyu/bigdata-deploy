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


# 刷新环境变量
function flush_env()
{
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    
    echo "    ************************** 刷新环境变量 **************************    "
    # 判断用户环境变量文件是否存在
    if [ -e "${HOME}/.bash_profile" ]; then
        source "${HOME}/.bash_profile"                                         # RedHat 用户环境变量文件
    elif [ -e "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"                                               # Debian、RedHat 用户环境变量文件
    fi
    
    source "/etc/profile"                                                      # 系统环境变量文件路径

    # 检查是否以 root 身份运行
    if [ "$EUID" -ne 0 ]; then
        echo "    ***************** 请使用 sudo 或以 root 用户运行 ******************    "
        exit 1
    fi

    echo "    ************************** 获取公共函数 **************************    "
    # shellcheck source=./common.sh
    source "${ROOT_DIR}/bin/common.sh"                                         # 当前程序使用的公共函数
    
    export -A PARAM_LIST=()                                                    # 初始化 配置文件 参数
    read_param "${ROOT_DIR}/conf/${CONFIG_FILE}"                               # 读取配置文件，获取参数
}


# 配置网卡
function network_init()
{
    echo "    ************************** 配置网卡信息 **************************    "
    local ip dns gateway device_name network_type                              # 定义局部变量
    
    ip=$(get_param  "server.ip")                                               # 获取主机的 IP
    dns=$(get_param "server.dns" | tr "," ";" | sed -e "s| ||g")               # 获取主机的 DNS
    gateway=$(get_param "server.gateway")                                      # 获取主机的 网关地址
    device_name=$(nmcli connection | grep -i "ethernet" | awk '{print $NF}')   # 获取正在使用的网卡名称
    
    # 替换网卡配置文件中的参数：ipv4地址、网关、DNS
    # network_type=$(grep -Pozin "\[ipv4\]\nmethod=auto" /etc/NetworkManager/system-connections/ens160.nmconnection | wc -l)
    network_type=$(grep -Poczinc "\[ipv4\]\nmethod=auto" "/etc/NetworkManager/system-connections/${device_name}.nmconnection")
     
    # 判断是否应配置过网卡信息，若未配置就添加，否则就修改
    if [[ "${network_type}" -gt 0  ]]; then
        sed -i ":label;N;s|\[ipv4\]\nmethod=auto|\[ipv4\]\nmethod=manual\naddress1=${ip},${gateway}\ndns=${dns};|g;t label" "/etc/NetworkManager/system-connections/${device_name}.nmconnection"
    else
        sed -i "s|^address1=.*|address1=${ip},${gateway}|g" "/etc/NetworkManager/system-connections/${device_name}.nmconnection"
        sed -i "s|^dns=.*|dns=${dns};|g"                    "/etc/NetworkManager/system-connections/${device_name}.nmconnection"
    fi
    
    {
        nmcli connection reload                                                # 重新加载网卡配置信息
        nmcli connection down   "${device_name}"                               # 关闭网卡
        nmcli connection up     "${device_name}"                               # 开启网卡
    }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    sleep 3
    systemctl restart NetworkManager  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   # 重启网卡服务
}


# 设置主机名与 hosts 映射
function host_init()
{
    echo "    ************************* 设置主机名映射 *************************    "
    local host_name ip_host_list item                                          # 定义局部变量
    
    host_name=$(get_param  "server.hostname")                                  # 获取主机名
    hostname  "${host_name}"                                                   # 临时修改主机名
    echo "${host_name}" > /etc/hostname                                        # 永久修改主机名：hostnamectl set-hostname ***
    
    ip_host_list=$(get_param "server.hosts" | tr "," " ")                      # 获取主机和 ip 映射
    for item in ${ip_host_list}
    do
        append_param "${item//\:/    }"  /etc/hosts                            # 添加 hosts 映射
    done
}


# 关闭防火墙 和 SELinux
function close_protect()
{
    echo "    *************************** 关闭防火墙 ***************************    "
    local exist                                                                # 定义局部变量
    
    systemctl stop    firewalld.service                                        # 关闭防火墙
    systemctl disable firewalld.service >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 # 关闭防火墙开机启动
    
    echo "    ************************** 关闭 SeLinux **************************    "
    setenforce 0                                                               # 临时关闭
    exist=$(grep -ni "^SELINUX=disabled" /etc/sysconfig/selinux)               # 永久关闭，需要重启系统
    if [ -z "${exist}" ]; then
        sed -i "s|SELINUX=enforcing|# SELINUX=enforcing\nSELINUX=disabled|g" /etc/sysconfig/selinux
    fi
}


# 解除文件读写限制
function unlock_limit()
{
    echo "    ************************ 修改打开文件限制 ************************    "    
    cp -fpr "${ROOT_DIR}/conf/limits.conf" /etc/security/limits.d/             # 配置用户打开文件限制
    
    ulimit -l 134217728                                                        # 设置内存块大小（B）
    ulimit -n 65536                                                            # 设置打开文件限制
    ulimit -s 20480                                                            # 设置堆栈大小（B）
    ulimit -u 65536                                                            # 设置最大线程限制
    
    # 系统限制的文件最大值，RedHat 9 系列无需操作
    # append_param "5702400" /proc/sys/fs/file-max                               # RedHat 9 默认值：9223372036854775807
}


# 优化内核
function kernel_optimize()
{
    echo "    **************************** 优化内核 ****************************    "
    local param param_list                                                     # 定义局部变量
    
    param_list=$(read_file "${ROOT_DIR}/conf/sysctl.conf")                     # 读取文件进行内核修改
    for param in ${param_list}
    do
        { 
            sysctl -w  "${param//\$/ }"                                        # 对内核进行临时修改，仅当前会话生效
            sysctl -p                                                          # 刷新配置
        } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1    
        
        append_param "${param//\$/ }" /etc/sysctl.conf                         # 对内核进行永久修改，仅重启后才生效
    done
}


# 添加管理员
function add_user()
{
    echo "    **************************** 添加用户 ****************************    "
    local user password exist software_home                                    # 定义局部变量
    
    user=$(get_param "server.user")                                            # 获取用户名
    password=$(get_param "server.password")                                    # 获取密码
    {
        useradd -m "${user}"                                                   # 添加用户
        echo "${password}" | passwd "${user}" --stdin                          # 给用户指定密码
    } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    chmod u+w /etc/sudoers                                                     # 给文件添加可编辑权限
    # 给用户添加管理员权限
    exist=$(grep -ni "^${user}"  /etc/sudoers)
    if [[ -z "${exist}" ]]; then
        sed -i "s|^root.*|root    ALL=\(ALL\)    ALL\n${user}    ALL=\(ALL\)    ALL|g" /etc/sudoers
    fi
    chmod u-w /etc/sudoers                                                     # 取消可编辑权限
    
    { 
        echo "#!/usr/bin/env bash" 
        echo ""
        echo "alias ll='ls -lh --color=auto' 2>/dev/null"
        echo "" 
    }  > "/etc/profile.d/${user}.sh"                                           # 为用户添加环境变量配置文件
    
    chmod 755 "/etc/profile.d/${user}.sh"                                      # 修改配置文件权限
    chown -R "${user}:${user}" "/etc/profile.d/${user}.sh"                     # 将文件的权限授予新添加的用户
    
    software_home=$(get_param "server.software.home")                          # 获取软件安装根路径
    chown -R "${user}:${user}" "${software_home}"                              # 将软件安装路径的权限授予新添加的用户
}


# 修改 Vim 配置文件
function vim_config()
{    
    cp -fpr "${ROOT_DIR}/conf/vimrc.conf"      /etc/vimrc.local                          # vim 配置文件
    cp -fpr "${ROOT_DIR}/conf/vim-molokai.vim" /usr/share/vim/vim82/colors/molokai.vim   # vim 主题
}


# 替换 dnf 镜像
function dnf_mirror()
{
    echo "    *************************** 替换镜像源 ***************************    "
    local mirror exist epel_image                                              # 定义局部变量
    
    mirror=$(get_param "dnf.image")                                            # 获取 rpm 仓库镜像源路径
    exist=$(echo "${mirror}" | grep -i "rocky")                                # 判断镜像是 rocky 还是 alma
    
    # 备份原来的源，并修改源
    if [[ -n "${exist}" ]]; then
        sed -e      "s|^mirrorlist=|# mirrorlist=|g"                                               \
            -Ee     "s|^#[ \t]*baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=${mirror}|g"  \
            -Ee     "s|^#[ \t]*baseurl=https://dl.rockylinux.org/\$contentdir|baseurl=${mirror}|g" \
            -i.bak  /etc/yum.repos.d/[Rr]ocky*.repo
    else
        sed -e      "s|^mirrorlist=|# mirrorlist=|g"                                     \
            -Ee     "s|^#[ \t]*baseurl=http://repo.almalinux.org|baseurl=${mirror}|g"    \
            -Ee     "s|^#[ \t]*baseurl=https://repo.almalinux.org|baseurl=${mirror}|g"   \
            -i.bak  /etc/yum.repos.d/almalinux*.repo
    fi
    
    epel_image=$(get_param "dnf.epel.image")                                   # epel 国内镜像源
    if [ -f "/etc/yum.repos.d/epel.repo" ]; then        
        sed -e      "s|^metalink|# metalink|"                                                 \
            -Ee     "s|^#[ \t]*baseurl=https://download.example/pub|baseurl=${epel_image}|g"  \
            -i.bak  /etc/yum.repos.d/epel*
    fi
    
    # 先清除缓存，然后更新源缓存和软件 
    { 
        dnf clean     all                                                      # 清除原来的缓存
        dnf makecache                                                          # 建立新的数据缓存
        dnf update    -y                                                       # 升级所有能升级的包
        dnf upgrade   -y                                                       # 升级系统中所有能升级的包
    }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
}


# 安装必要的软件包
function install_rpm()
{
    echo "    *************************** 安装软件包 ***************************    "
    local rpm_list rpm                                                         # 定义局部变量
    rpm_list=$(get_param "dnf.rpm" | tr "," " ")                               # 获取安装软件包名称
    
    # 遍历安装软件包
    for rpm in ${rpm_list}
    do
        echo "    +>+>+>+>+>+>+>+>+>+> 安装 ${rpm}    "
        dnf install "${rpm}" -y    >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1      # 使用 dnf 命令安装软件包
    done    
}


# 更新新内核
function upgrade_kernel()
{
    echo "    **************************** 更新内核 ****************************    "
    local kernel_key kernel_url kernel_header kernel_image kernel_list         # 定义局部变量
            
    kernel_image=$(get_param "kernel.image")                                   # 获取 EL 内核镜像地址
    if [ -e "/etc/yum.repos.d/elrepo.repo" ]; then                             # 修改仓库镜像地址        
        sed -e      "s|^mirrorlist=|# mirrorlist=|g"            \
            -Ee     "s|^[ \t]*http[s]*://.*||g"                 \
            -e      "s|elrepo.org/linux|${kernel_image}|g"      \
            -i.bak  /etc/yum.repos.d/elrepo.repo
    fi
    
    kernel_key=$(get_param "kernel.key")                                       # 新内核公钥
    kernel_url=$(get_param "kernel.url")                                       # 新内核 ELRepo 地址
    
    echo "    **************************** 导入仓库 ****************************    "        
	  {	    
        # RedHat 下使用 ELRepo 第三方的仓库，可以将内核升级到最新版本
        rpm  --import          "${kernel_key}"                                 # 导入公钥
        dnf  -y       install  "${kernel_url}"                                 # 安装 ELRepo 的 rpm
                
        # 修改仓库镜像地址
        sed -e      "s|^mirrorlist=|# mirrorlist=|g"            \
            -Ee     "s|^[ \t]*http[s]*://.*||g"                 \
            -e      "s|elrepo.org/linux|${kernel_image}|g"      \
            -i.bak  /etc/yum.repos.d/elrepo.repo
    } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    echo "    **************************** 升级内核 ****************************    "
    kernel_list=$(dnf --disablerepo="*" --enablerepo="elrepo-kernel" list available | grep -i "kernel-lt-" | awk '{print $1}')   # 获取最新的长期支持内核
    # kernel_list=$(dnf --disablerepo="*" --enablerepo="elrepo-kernel" list available | grep -i "kernel-ml-" | awk '{print $1}') # 获取最新的主线稳定内核
    for kernel in ${kernel_list}
    do
        echo "    +>+>+>+>+>+>+>+>+>+> 升级内核：${kernel}    "
        dnf -y --enablerepo=elrepo-kernel install  "${kernel}"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  # 安装最新的长期支持内核
    done    
    
    echo "    ********************** 升级 kernel-headers ***********************    "
    {        
        kernel_header=$(rpm -qa | grep -i "kernel-headers-$(uname -r)")        # 获取当前内核 kernel-header 版本
        dnf -y remove "${kernel_header}"                                       # 卸载当前的 kernel-headers        
        dnf -y install pciutils-libs                                           # 安装因内核工具卸载，缺失的工具
        dnf -y --enablerepo=elrepo-kernel install kernel-lt-headers            # 安装最新的长期支持内核 kernel-headers
        # dnf -y --enablerepo=elrepo-kernel install kernel-ml-headers          # 安装最新的主线稳定内核 kernel-headers
    } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1    
    
    echo "    **************************** 重建内核 ****************************    "
    {
        grub2-set-default 0                                                    # 设置第一个内核将作为默认内核，临时生效
        
        cp  -fpr  /etc/default/grub                      /etc/default/grub.bak # 备份内核配置文件
        sed -i    "s|^GRUB_DEFAULT=.*|GRUB_DEFAULT=0|g"  /etc/default/grub     # 设置第一个内核将作为默认内核，永久生效
        
        grub2-mkconfig -o /boot/grub2/grub.cfg                                 # 重新创建内核配置
    } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
}


# 更新新内核，删除老内核
function remove_kernel()
{
    echo "    *************************** 移除旧内核 ***************************    "
    local kernel_list kernel kernel_version                                    # 定义局部变量
    
    kernel_version=$(uname -r | awk -F '.' '{$NF=""; print $0}' | tr " " ".")  # 查询系统已安装的旧内核版本
    kernel_list=$(rpm -qa | grep -iE "kernel|elrepo-release-" | grep -viE "srpm-macros|${kernel_version}")   # 查询系统已安装的旧内核包
    
    # 删除旧内核
    for kernel in ${kernel_list}
    do
        echo "    +>+>+>+>+>+>+>+>+>+> 卸载内核：${kernel}    "
        dnf remove -y "${kernel}"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1      # 删除旧内核
    done    
    
    grub2-mkconfig -o /boot/grub2/grub.cfg >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1        # 重新编译引导             
}


# 添加中文支持
function add_chinese()
{
    echo "    ************************** 添加中文支持 **************************    "
    local language_count chinese zh result_count                               # 定义局部变量
    
    language_count=$(localectl list-locales | grep -ic "zh_CN")                # 查看系统是否安装简体中文语言包
    if [ "${language_count}" -eq 1 ]; then
        echo "    *************************** 中文已安装 ***************************    "
    else
        {
            chinese=$(dnf list | grep -i "glibc-langpack" | grep -i "zh")      # 筛选出需要的中文语言包
            for zh in ${chinese}
            do
                dnf  install  -y  "${zh}"                                      # 安装中文语言包
            done
            
            localectl  set-locale  LANG="zh_CN.utf8"                           # 修改当前生效语言包为中文zh_CN.utf8
        }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
    fi    
    
    cd "${ROOT_DIR}" || exit                                                   # 进入项目根路径
    result_count=$(git log | grep -ic "添加简体中文支持")                       # 检查中文是否生效
    if [ "${result_count}" -eq 1 ]; then
        echo "    **************************** 添加成功 ****************************    "
    else
        echo "    **************************** 添加失败 ****************************    "        
    fi    
}


# 添加便捷的命令别名
function add_alias()
{
    echo "    **************************** 添加别名 ****************************    "
    local user                                                                 # 定义局部变量    
    user=$(get_param "server.user")                                            # 获取用户名
    
    cp    -fpr  "${ROOT_DIR}/conf/zalias.sh" /etc/profile.d/                   # 复制别名文件    
    chown -R    "${user}:${user}"            /etc/profile.d/zalias.sh          # 权限授予用户
    
    source   /etc/profile                                                      # 使环境变量生效
}


# 安装常用字体
function font_install
{
    local font_list font user                 	                               # 定义局部变量
    user=$(get_param "server.user")                                            # 获取用户名
    
    echo "    **************************** 字体管理 ****************************    "
    dnf -y install fontconfig mkfontscale  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1        # 安装字体管理工具
    
    echo "    **************************** 安装字体 ****************************    "
    mkdir -p "/usr/share/fonts/${user}"                                        # 创建字体存放路径
    font_list=$(ls "${ROOT_DIR}"/lib/*.ttf)                                    # 获取字体路径
    
    for font in ${font_list}
    do
        echo "    +>+>+>+>+>+>+>+> 安装 $(echo "${font}" | awk -F '/' '{print $NF}')    " 
        cp -fpr "${font}"  "/usr/share/fonts/${user}/"                         # 安装字体
    done
        
    echo "    **************************** 刷新缓存 ****************************    "
    {
        chown -R "${user}:${user}" "/usr/share/fonts/${user}"                  # 将文件的权限授予新用户
        mkfontscale                                                            # 字体大小
        mkfontdir                                                              # 字体路径
        fc-cache -fv                                                           # 刷新字体缓存
    }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
}


# 给 Shell 脚本添加可执行权限，安装集群操作脚本
function add_execute()
{
    echo "    ************************* 添加可执行权限 *************************    "
    local item server_hosts result_count                                       # 定义局部变量
    
    {
        find "${ROOT_DIR}" -iname "*.sh" -type f -exec dos2unix {} + -exec chmod +x {} + # 将 shell  文件换行符改为 UNIX 格式，并赋予执行权限
        find "${ROOT_DIR}" -iname "*.py" -type f -exec dos2unix {} + -exec chmod +x {} + # 将 python 文件换行符改为 UNIX 格式，并赋予执行权限
        
        dos2unix  "${ROOT_DIR}"/conf/*                                         # 将配置文件修改为 UNIX 换行        
    }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    if [ ! -f /usr/local/bin/xcall ]; then
        cp -frp  "${ROOT_DIR}/script/system/xcall.sh"  /usr/local/bin/xcall    # 将 集群间查看命令 脚本复制到系统路径
    fi
    
    if [ ! -f /usr/local/bin/xync ]; then
        cp -frp  "${ROOT_DIR}/script/system/xync.sh"   /usr/local/bin/xync     # 将 集群之间进行文件同步 脚本复制到系统路径
    fi
    
    # 获取所有主机名
    for item in $(get_param "server.hosts" | tr "," " ")
    do
        server_hosts="${server_hosts}$(echo "${item}" | awk -F ':' '{print $NF}') "
    done
    
    result_count=$(grep -ic "\${server_hosts}" /usr/local/bin/xcall)           # 判断是否存在未修改
    if [ "${result_count}" -eq 1 ]; then        
        sed -i "s|\${server_hosts}|${server_hosts}|g"  /usr/local/bin/xcall    # 修改集群 主机列表
        chmod 755                                      /usr/local/bin/xcall    # 添加执行权限
    fi
    
    result_count=$(grep -ic "\${server_hosts}" /usr/local/bin/xync)            # 判断是否存在未修改
    if [ "${result_count}" -eq 1 ]; then            
        sed -i "s|\${server_hosts}|${server_hosts}|g"  /usr/local/bin/xync     # 修改集群 主机列表
        chmod 755                                      /usr/local/bin/xync     # 添加执行权限
    fi
}


printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 2. 刷新变量
if [ "$#" -gt 0 ]; then
    flush_env                                                                  # 刷新环境变量
    if [ ! -x "${ROOT_DIR}/bin/common.sh" ]; then
        add_execute                                                            # 给脚本添加可执行权限
    fi
fi

# 3. 匹配输入参数
case "$1" in
    # 3.1 配置网卡
    network | -n)
        network_init
    ;;
    
    # 3.2 设置主机名与 hosts 映射
    host | -h)
        host_init
    ;;
    
    # 3.3 关闭防火墙 和 SELinux
    close | -l)
        close_protect
    ;;
    
    # 3.4 解除文件读写限制
    unlock | -u)
        unlock_limit
    ;;
    
    # 3.5 优化内核
    knernel | -k)
        kernel_optimize
    ;;
        
    # 3.6 添加管理员
    add | -c)
        add_user
    ;;
    
    # 3.7 添加管理员
    vim | -v)
        vim_config
    ;;
    
    # 3.8 替换 dnf 镜像
    dnf | -d)
        dnf_mirror
    ;;
    
    # 3.9 安装必要的软件包
    install | -i)
        install_rpm
    ;;
    
    # 3.10 更新内核删除旧内核
    upgrade | -p)
        upgrade_kernel
    ;;
    
    # 3.11 更新内核删除旧内核
    remove | -r)
        remove_kernel
    ;;
    
    # 3.12 添加命令别名
    alias | -s)
        add_alias
    ;;
    
    # 3.13 添加中文支持
    chinese | -z)
        add_chinese
    ;;
    
    # 3.13 添加中文支持
    font | -f)
        font_install
    ;;
    
    # 3.14 初始化所有配置
    all | -a)
        network_init
        host_init
        close_protect
        unlock_limit
        kernel_optimize
        add_user
        vim_config
        dnf_mirror
        install_rpm
        remove_kernel
        add_alias
        add_chinese
        font_install
    ;;
    
    # 3.15 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：     "
        echo "        +----------------+--------------+ "
        echo "        |     参  数     |    描  述    | "
        echo "        +----------------+--------------+ "
        echo "        |   -n|network   |   配置网卡   | "
        echo "        |   -h|host      |   主机映射   | "
        echo "        |   -l|close     |   关闭保护   | "
        echo "        |   -u|unlock    |   解除限制   | "
        echo "        |   -k|kernel    |   优化内核   | "
        echo "        |   -c|add       |   添加用户   | "
        echo "        |   -v|vim       |   配置 vim   | "
        echo "        |   -d|dnf       |   替换镜像   | "
        echo "        |   -i|install   |   安装软件   | "
        echo "        |   -p|upgrade   |   升级内核   | "
        echo "        |   -r|remove    |   删除内核   | "
        echo "        |   -s|alias     |   添加别名   | "
        echo "        |   -z|chinese   |   添加中文   | "
        echo "        |   -f|font      |   安装字体   | "
        echo "        |   -a|all       |   执行全部   | "
        echo "        +----------------+--------------+ "
    ;;
esac

# 4. 打印提示命令
if [ "$#" -gt 0 ]; then
    echo ""
    echo "    +---------------------------------------------------------+"
    echo "    |  部分配置必须重启才能生效，可运行命令：shutdown -r now  |"
    echo "    +---------------------------------------------------------+"
    echo ""  
fi

# 5. 获取脚本执行结束时间，并计算脚本执行时间
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)
if [ "$#" -ge 1 ]; then
    echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
fi

printf "================================================================================\n\n"
exit 0

