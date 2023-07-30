#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  gcc.sh
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


# 解压缩文件到临时路径（$1：下载软件包 url 的 key，$2：软件包安装路径）
function file_decompress()
{
    # 定义参数
    local file_name folder
    
    file_name=$(get_param "$1" | sed 's/.*\/\([^\/]*\)$/\1/')
    echo "    ********** 解压缩文件：${file_name} **********    "
    
    if [ -e "${ROOT_DIR}/package/${file_name}" ]; then
        # 判断软件安装目录是否存在，存在就删除
        if [ -n "$2" ] && [ -d "$2" ]; then
            rm -rf "$2"
        fi
        
        # 先删除已经存在的目录
        find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print -exec rm -rf {} +
        cd "${ROOT_DIR}/package" || exit                                       # 进入解压目录
        
        # 对压缩包进行解压
        if [[ "${file_name}" =~ tar.xz$ ]]; then
            tar -Jxvf "${ROOT_DIR}/package/${file_name}"      >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar.gz$ ]] || [[ "${file_name}" =~ tgz$ ]]; then
            tar -zxvf "${ROOT_DIR}/package/${file_name}"      >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar.bz2$ ]]; then
            tar -jxvf "${ROOT_DIR}/package/${file_name}"      >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar.Z$ ]]; then
            tar -Zxvf "${ROOT_DIR}/package/${file_name}"      >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar$ ]]; then
            tar -xvf "${ROOT_DIR}/package/${file_name}"       >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ zip$ ]]; then
            unzip "${ROOT_DIR}/package/${file_name}"          >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ xz$ ]]; then
            xz -dk "${ROOT_DIR}/package/${file_name}"         >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ gz$ ]]; then
            gzip -dk "${ROOT_DIR}/package/${file_name}"       >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   
        elif [[ "${file_name}" =~ bz2$ ]]; then
            bzip2 -vcdk "${ROOT_DIR}/package/${file_name}"    >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ Z$ ]]; then
            uncompress -rc "${ROOT_DIR}/package/${file_name}" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ rar$ ]]; then
            unrar vx  "${ROOT_DIR}/package/${file_name}"      >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
        fi
        
        # 将文件夹移动到安装路径
        if [ -n "$2" ]; then
            folder=$(find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print)
            mkdir -p "$2"
            mv "${folder}"* "$2"
        fi
    else
        echo "    文件 ${ROOT_DIR}/package/${file_name} 不存在 "
    fi
}


# 获取 cpu 超线程数
function get_cpu_thread()
{
    local physical_count core_count processor_count thread 
    
    # 查看物理 CPU 个数
    physical_count=$(grep -i "physical id" /proc/cpuinfo | sort | uniq | wc -l)
    
    # 查看每个物理 CPU 中 core 的个数(即核数)
    core_count=$(grep -i "cpu cores" /proc/cpuinfo | uniq | awk '{print $NF}')
    
    # 查看逻辑 CPU 的个数
    processor_count=$(grep -ci "processor" /proc/cpuinfo)
    
    # 总逻辑 CPU 数 = 物理 CPU 个数 X 每颗物理 CPU 的核数 X 超线程数
    thread=$(( physical_count * core_count * processor_count ))
    
    echo "${thread}"
}


# 安装并配置 gcc
function gcc_install()
{
    local folder gcc_home cpu_thread password gcc_version count
    
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
    { echo "#include <stdio.h>"; echo "int main()";  echo "{"; echo "    printf(\"Hello World\nHello World\nHello World\");"; echo "    return 0;"; echo "}"; echo ""; } > hello.c
    
    # 用 gcc 编译：-Wall，编译后显示所有警告；-o，输出参数，输出名字的参数，如果不加 -o，会生成 a.out 的可执行文件
    "gcc${gcc_version}" -Wall hello.c -o hello  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
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
    echo "    ************************ 开始安装 git ************************    "
    
}

# 安装并配置 htop
function htop_install()
{
    echo "    *********************** 开始安装 htop ************************    "
    
}


printf "\n================================================================================\n"
mkdir -p "${ROOT_DIR}/logs"                                                    # 创建日志目录

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
