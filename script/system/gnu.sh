#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  gnu.sh
#    CreateTime    ：  2023-07-29 21:34
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  编译安装 gcc、git、htop、
# ==================================================================================================


SERVICE_DIR=$(cd -P "$(dirname "$(readlink -e "$0")")" || exit; pwd -P)        # Shell 脚本目录
ROOT_DIR=$(cd -P "${SERVICE_DIR}/../../" || exit; pwd -P)                      # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="compile-install-$(date +%F).log"                                     # 程序操作日志文件
USER=$(whoami)                                                                 # 当前登录使用的用户


# 刷新环境变量
function flush_env()
{    
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    
    if [ -e "${HOME}/.bash_profile" ]; then                                    #  刷新用户环境变量
        source "${HOME}/.bash_profile"                                         # RedHat 用户环境变量文件
    elif [ -e "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"                                               # Debian、RedHat 用户环境变量文件
    fi
    
    source "/etc/profile"                                                      # 刷新系统环境变量
    # shellcheck source=./../../bin/common.sh
    source "${ROOT_DIR}/bin/common.sh"                                         # 当前程序使用的公共函数
    
    export -A PARAM_LIST=()                                                    # 初始化 配置文件 参数
    read_param "${ROOT_DIR}/conf/${CONFIG_FILE}"                               # 读取配置文件，获取参数    
}


# 安装并配置 gcc
function gcc_install()
{
    local exists folder gcc_home cpu_thread password gcc_version gcv gpv test_result
    
    exists=$(command_exist gcc | wc -l)                                        # 查看是否存在相关命令
    if [[ ${exists} -gt 1 ]]; then
        echo "    **************************** 软件已经安装 ****************************    "
        return 1
    fi
    
    echo "    ************************ $(date '+%T')：解压源码包 ************************    "
    file_decompress "gcc.url"                                                  # 解压源码包
    folder=$(find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print)         # 获取解压目录
    
    echo "    ************************ $(date '+%T')：下载依赖包 ************************    "
    cd "${folder}" || exit                                                     # 进入源码包
    ./contrib/download_prerequisites  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   # 下载依赖
    
    echo "    ************************* $(date '+%T')：编译源码 *************************    "
    cd "${folder}" || exit                                                     # 进入源码包
    gcc_home=$(get_param "gcc.home")                                           # 获取 gcc 安装路径
    cpu_thread=$(get_cpu_thread)                                               # 获取 cpu 逻辑核心数
    {
        ./configure -prefix="${gcc_home}" --enable-checking=release --enable-languages=c,c++ --disable-multilib   # 生成 Makefile 文件
        make "-j${cpu_thread}"                                                 # 编译源码
    }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    sleep 5
    
    echo "    *************************** $(date '+%T')：安装 ***************************    "
    cd "${folder}" || exit                                                     # 进入源码包
    make install  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1                       # 安装 gcc 
    
    echo "    *********************** $(date '+%T')：添加环境变量 ***********************    "
    password=$(get_param "server.password")                                    # 获取管理员密码
    gcc_version=$(get_param "gcc.url" | awk -F '/' '{print $NF}' | awk -F '.' '{print $1}' | grep -oP "\d*") # 获取 gcc 主版本号
    echo "${password}" | sudo -S ln -s "${gcc_home}/bin/gcc" "/usr/bin/gcc${gcc_version}"                    # 创建 gcc 软连接
    echo "${password}" | sudo -S ln -s "${gcc_home}/bin/g++" "/usr/bin/gcc${g++_version}"                    # 创建 g++ 软连接
        
    gcv=$("gcc${gcc_version}" --version | grep -ci "gcc|${gcc_version}")       # gcc 版本号
    gpv=$("g++${gcc_version}" --version | grep -ci "gcc|${gcc_version}")       # g++ 版本号
    if [ "${gcv}" -ne 1 ] || [ "${gpv}" -ne 1 ]; then
        echo "    ****************************** 安装失败 ******************************    "
        return 1
    fi
    
    echo "    ************************ $(date '+%T')：测试 Hello ************************    "
    cd "${folder}" || exit                                                     # 进入源码包
    { 
        echo "#include <stdio.h>"
        echo "int main()"
        echo "{"
        echo "    printf(\"Hello World\nHello World\nHello World\n\");"
        echo "    return 0;"
        echo "}"
        echo ""
    } > "${folder}/hello.c"
    
    # 用 gcc 编译：-Wall，编译后显示所有警告；-o，输出参数，输出名字的参数，如果不加 -o，会生成 a.out 的可执行文件
    "gcc${gcc_version}" -Wall "${folder}/hello.c" -o "${folder}/hello"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    test_result=$("${folder}/hello" | grep -ciw "Hello World")                 # 运行编译结果
    if [[ "${test_result}" -eq 3 ]]; then
        echo "    ****************************** 测试完成 ******************************    "
    else
        echo "    ****************************** 测试失败 ******************************    "
    fi
}


# 安装并配置 git
function git_install()
{
    local result_count folder gcc_home cpu_thread password gcc_version count
    
    result_count=$(command_exist gcc | wc -l)                                  # 查看是否存在相关命令
    if [[ ${result_count} -gt 1 ]]; then
        echo "    **************************** 软件已经安装 ****************************    "
        return 1
    fi
    
    echo "    ************************ 开始安装 git ************************    "
    
}


# 安装并配置 htop
function htop_install()
{
    local result_count folder gcc_home cpu_thread password gcc_version count
    
    result_count=$(command_exist gcc | wc -l)                                  # 查看是否存在相关命令
    if [[ ${result_count} -gt 1 ]]; then
        echo "    **************************** 软件已经安装 ****************************    "
        return 1
    fi
    
    echo "    *********************** 开始安装 htop ************************    "    
}


printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 2. 刷新变量
if [ "$#" -gt 0 ]; then
    flush_env                                                        # 刷新环境变量    
fi

# 3. 匹配输入参数
case "$1" in
    # 3.1 安装 gcc 
    gcc | -c)
        gcc_install
    ;;
    
    # 3.2 安装 git
    git | -g)
        git_install
    ;;
    
    # 3.3 安装 htop 
    htop | -h)
        htop_install
    ;;
    
    # 3.4 安装必要的软件包
    all | -a)
        gcc_install
        git_install
        htop_install
    ;;
    
    # 3.5 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：      "
        echo "        +----------+------------------+ "
        echo "        |  参  数  |      描  述      | "
        echo "        +----------+------------------+ "
        echo "        |    -c    |   安装 gcc       | "
        echo "        |    -g    |   安装 git       | "
        echo "        |    -h    |   安装 htop      | "
        echo "        |    -a    |   安装以上所有   | "
        echo "        +----------+------------------+ "
    ;;
esac

# 4. 获取脚本执行结束时间，并计算脚本执行时间
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)
if [ "$#" -ge 1 ]; then
    echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
fi

printf "================================================================================\n\n"
exit 0
