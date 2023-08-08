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


# 安装并配置 gcc
function gcc_install()
{
    local exists result_count folder gcc_home cpu_thread password gcc_version count
    exists=$(command_exist gcc)
    echo "${exists}"
    result_count=$(echo "${exists}" | wc -l)
    if [[ ${result_count} -gt 1 ]]; then
        return
    fi
    
    echo "exists= ${exists}"
    echo "    ************************ $(date '+%T')：解压源码包 ************************    "
    file_decompress "gcc.url"                                                  # 解压源码包
    folder=$(find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print)         # 获取解压目录
    cd "${folder}" || exit                                                     # 进入源码包
    
    echo "    ************************ $(date '+%T')：下载依赖包 ************************    "
    ./contrib/download_prerequisites  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   # 下载依赖
    
    echo "    ************************* $(date '+%T')：编译源码 *************************    "
    cd "${folder}" || exit                                                     # 进入源码包
    gcc_home=$(get_param "gcc.home")                                           # 获取 gcc 安装路径
    cpu_thread=$(get_cpu_thread)                                               # 获取 cpu 逻辑核心数
    ./configure -prefix="${gcc_home}" --enable-checking=release --enable-languages=c,c++ --disable-multilib >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    make "-j${cpu_thread}"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1             # 编译源码
    sleep 5
    
    echo "    *************************** $(date '+%T')：安装 ***************************    "
    cd "${folder}" || exit                                                     # 进入源码包
    make install  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1                       # 安装 gcc 
    
    password=$(get_param "server.password")                                    # 获取管理员密码
    gcc_version=$(get_param "gcc.url" | awk -F '/' '{print $NF}' | awk -F '.' '{print $1}' | grep -oP "\d*") # 获取 gcc 主版本号
    echo "${password}" | sudo -S ln -s "${gcc_home}/bin/gcc" "/usr/bin/gcc${gcc_version}"          # 创建 gcc 软连接
    echo "${password}" | sudo -S ln -s "${gcc_home}/bin/g++" "/usr/bin/gcc${g++_version}"          # 创建 g++ 软连接
    
    echo "    ************************* $(date '+%T')：查看版本 *************************    "
    "${gcc_home}/bin/gcc" --version | grep -i "gcc"                            # 查看 gcc 版本号
    "${gcc_home}/bin/g++" --version | grep -i "gcc"                            # 查看 g++ 版本号
    
    echo "    ************************ $(date '+%T')：测试 hello ************************    "
    cd "${folder}" || exit                                                     # 进入源码包
    { echo "#include <stdio.h>"; echo "int main()";  echo "{"; echo "    printf(\"Hello World\nHello World\nHello World\n\");"; echo "    return 0;"; echo "}"; echo ""; } > "${folder}/hello.c"
    
    # 用 gcc 编译：-Wall，编译后显示所有警告；-o，输出参数，输出名字的参数，如果不加 -o，会生成 a.out 的可执行文件
    "gcc${gcc_version}" -Wall "${folder}/hello.c" -o "${folder}/hello"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    count=$("${folder}/hello" | grep -ciw "Hello World")    # 运行编译结果
    if [[ "${count}" -eq 3 ]]; then
        echo "    ****************************** 测试完成 ******************************    "
    else
        echo "    ****************************** 测试失败 ******************************    "
    fi
}


# 安装并配置 git
function git_install()
{
    local exists folder gcc_home cpu_thread password gcc_version count
    
    exists=$(command -v gcc > /dev/null 2>&1; echo $?)
    if [[ "${exists}" -eq 0 ]]; then
        echo "    **************************** 软件已经安装 ****************************    "
        echo "        ===> 位置：$(command -v gcc) "
        return
    fi
    
    echo "    ************************ 开始安装 git ************************    "
    
}


# 安装并配置 htop
function htop_install()
{
    echo "    *********************** 开始安装 htop ************************    "
    
}


if [ "$#" -gt 0 ]; then
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    
    # shellcheck source=./../../bin/common.sh
    source "${ROOT_DIR}/bin/common.sh" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  # 获取公共函数    
fi

if [ "$#" -gt 0 ]; then
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    
    source "${HOME}/.bashrc"                                                   # 刷系用户环境变量
    source /etc/profile                                                        # 刷系统新环境变量
    # shellcheck source=./../../bin/common.sh
    source "${ROOT_DIR}/bin/common.sh" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  # 获取公共函数    
fi

printf "\n================================================================================\n"
# 匹配输入参数
case "$1" in
    # 1. 安装 gcc 
    gcc | -c)
        gcc_install
    ;;
    
    # 2. 安装 git
    git | -g)
        git_install
    ;;
    
    # 3. 安装 htop 
    htop | -h)
        htop_install
    ;;
    
    # 11. 安装必要的软件包
    all | -a)
        gcc_install
        git_install
        htop_install
    ;;
    
    # 10. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：             "
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
printf "================================================================================\n\n"
exit 0
