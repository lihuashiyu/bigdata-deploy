#!/usr/bin/env bash
    
# =========================================================================================
#    FileName      ：  gcc.sh
#    CreateTime    ：  2024-05-19 21:52
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  从源码编译安装 gcc，需要提前安装相关编译工具：
#                          sudo dnf check-update
#                          sudo dnf install -y dnf-utils epel-release
#                          sudo dnf install -y gcc gcc-c++ 
#                          sudo dnf install -y openssl-devel bzip2-devel 
#                          sudo dnf install -y libffi-devel zlib-devel make
#                          sudo dnf install -y cmake
#                          sudo dnf group install "Development Tools" -y
# =========================================================================================
    
GCC_HOME="/opt/gcc"                                                            # GCC 安装路径
URL="https://mirrors.aliyun.com/gnu/gcc/gcc-14.1.0/gcc-14.1.0.tar.xz"          # GCC 下载路径
PASSWORD="111111"                                                              # 管理员账号密码，root 运行，则不需要
    
SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
LOG_DIRECTORY="gcc-$(date +%F)"                                                # 程序操作日目录名
FILE_NAME=$(echo "${URL}" | awk -F '/' '{ print $NF}')                         # 获取下载的压缩包路径
FILE_DIRECTORY=$(echo "${FILE_NAME}" | awk -F '.' '{ print $1"."$2"."$3}')     # 文件解压路径
GCC_VERSION=$(echo "${FILE_NAME}" | awk -F '.' '{print $1}' | grep -oP "\d*")  # 获取 GCC 主版本号
    

# 刷新环境变量
function flush_env()
{
    echo "    ************************ $(date '+%T')：刷新环境变量 ************************    "
    source "/etc/profile"                                                      # 刷新系统环境变量
    
    if [ -e "${HOME}/.bash_profile" ]; then                                    #  刷新用户环境变量
        source "${HOME}/.bash_profile"                                         # RedHat 用户环境变量文件
    fi

    if [ -e "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"                                               # Debian、RedHat 用户环境变量文件
    fi
    
    mkdir -p "${SERVICE_DIR}/${LOG_DIRECTORY}"                                 # 创建日志文件夹
}
    

# 下载软件包
function download()
{
    local is_exist log_file                                                    # 定义局部变量
    log_file="${SERVICE_DIR}/${LOG_DIRECTORY}/download.log"                    # 下载 GCC 软件包的日志路径
    
    # 下载软件包
    if [ -n "${URL}" ]; then
        cd "${SERVICE_DIR}" || exit                                            # 进入到项目目录
        rm -f "${FILE_NAME}"                                                   # 删除已经存在的安装包
        
        echo "    ***************** $(date '+%T')：开始下载 ${FILE_NAME} *****************    "
        is_exist=$(command -v "curl" | wc -l)                                  # 判断 curl 命令是否存在
        if [ "${is_exist}" -eq 0 ]; then
            wget -P "${SERVICE_DIR}" "${URL}" >> "${log_file}" 2>&1
        else
            curl --parallel --parallel-immediate -k -L -C - -o "${SERVICE_DIR}/${FILE_NAME}" "${URL}" \
                >> "${log_file}" 2>&1
        fi
        echo "    **************** $(date '+%T')：${FILE_NAME} 下载完成 ******************    "
    else
        echo "    ****************************** url 不存在 ******************************    "
    fi
}
    

# 下载相关依赖
function depend()
{
    log_file="${SERVICE_DIR}/${LOG_DIRECTORY}/depend.log"                      # 下载 GCC 依赖的日志路径
    cd "${SERVICE_DIR}" || exit                                                # 进入到项目目录
    rm    -rf "${FILE_DIRECTORY}"                                              # 删除可能存在的已解压目录
    mkdir -p  "${FILE_DIRECTORY}"                                              # 创建需要的文件夹
    
    echo "    ******************* $(date '+%T')：解压 ${FILE_NAME} *******************    "
    if [ -e "${FILE_NAME}" ]; then                                             # 判断文件是否存在
        if [[ "${FILE_NAME}" =~ tar.xz$ ]]   || [[ "${FILE_NAME}" =~ txz$ ]]; then
            tar -Jxvf "${FILE_NAME}"   >> "${log_file}" 2>&1
        elif [[ "${FILE_NAME}" =~ tar.gz$ ]] || [[ "${FILE_NAME}" =~ tgz$ ]]; then
            tar -zxvf "${FILE_NAME}"   >> "${log_file}" 2>&1
        else
            unzip "${FILE_NAME}"       >> "${log_file}" 2>&1
        fi    
    else
        echo "    ******************** 文件 ${FILE_NAME} 不存在 *********************    "
        exit 1
    fi
    
    echo "    ************************* $(date '+%T')：下载依赖包 *************************    "
    cd "${SERVICE_DIR}/${FILE_DIRECTORY}" || exit                              # 进入源码路径
    ./contrib/download_prerequisites >> "${log_file}" 2>&1                     # 下载依赖
        
    echo "    ************************ $(date '+%T')：依赖下载完成 ************************    "
}
    

# 编译安装
function compile()
{
    local cpu_thread                                                           # 定义局部变量
    log_file="${SERVICE_DIR}/${LOG_DIRECTORY}/compile.log"                     # 编译安装 GCC 的日志路径
    
    cd "${SERVICE_DIR}/${FILE_DIRECTORY}" || exit                              # 进入源码路径
    cpu_thread=$(grep -i "cpu cores" /proc/cpuinfo | uniq | awk '{print $NF}') # 获取 cpu 核心数
    
    echo "    *********************** $(date '+%T')：生成 MakeFile ************************    "
    # 生成 Makefile 文件    
    ./configure -prefix="${GCC_HOME}"            \
                --enable-threads=posix           \
                --enable-checking=release        \
                --enable-languages=c,c++         \
                --enable-bootstrap               \
                --disable-multilib               \
                >> "${log_file}" 2>&1
    
    echo "    ************************** $(date '+%T')：编译源码 **************************    "
    make "-j${cpu_thread}" >> "${log_file}" 2>&1
    sleep 5
    
    echo "    ************************** $(date '+%T')：安装 GCC **************************    "
    cd "${SERVICE_DIR}/${FILE_DIRECTORY}" || exit                              # 进入源码路径
    rm -rf "${GCC_HOME}"                                                       # 删除可能安装过的目录
    make install           >> "${log_file}" 2>&1                               # 安装 gcc
        
    echo "    ************************** $(date '+%T')：安装完成 **************************    "
}    
     

# 添加到环境变量    
function environment()
{    
    local gcv gpv                                                              # 定义局部变量
    
    echo "    ************************ $(date '+%T')：添加环境变量 ************************    "
    
    # 判断是否是 root 账户
    if [ "${USER}" == "root" ]; then
        rm -f "/usr/local/bin/gcc${GCC_VERSION}"                               # 删除已存在的 gcc 软连接
        rm -f "/usr/local/bin/g++${GCC_VERSION}"                               # 删除已存在的 gcc 软连接
        
        ln -s "${GCC_HOME}/bin/gcc"  "/usr/local/bin/gcc${GCC_VERSION}"        # 创建 gcc 软连接
        ln -s "${GCC_HOME}/bin/g++"  "/usr/local/bin/g++${GCC_VERSION}"        # 创建 g++ 软连接
    else    
        echo "${PASSWORD}" | sudo -S rm -f  "/usr/local/bin/gcc${GCC_VERSION}"
        echo "${PASSWORD}" | sudo -S rm -f  "/usr/local/bin/g++${GCC_VERSION}"
        
        echo "${PASSWORD}" | sudo -S ln -s "${GCC_HOME}/bin/gcc" "/usr/local/bin/gcc${GCC_VERSION}"
        echo "${PASSWORD}" | sudo -S ln -s "${GCC_HOME}/bin/g++" "/usr/local/bin/g++${GCC_VERSION}"
        
        echo "${PASSWORD}" | sudo -S chown -R "${USER}:${USER}"  "/usr/local/bin/gcc${GCC_VERSION}"
        echo "${PASSWORD}" | sudo -S chown -R "${USER}:${USER}"  "/usr/local/bin/g++${GCC_VERSION}"
        echo ""
    fi
    
    gcv=$("gcc${GCC_VERSION}" --version | grep -i "gcc" | grep -ci "${GCC_VERSION}")               # 验证 gcc 版本号
    gpv=$("g++${GCC_VERSION}" --version | grep -i "g++" | grep -ci "${GCC_VERSION}")               # 验证 g++ 版本号
    if [ "${gcv}" -ne 1 ] || [ "${gpv}" -ne 1 ]; then
        echo "    ************************** $(date '+%T')：添加失败 **************************    "
        exit 1
    fi
    
    echo "    ************************** $(date '+%T')：添加成功 **************************    " 
}
    

# 测试编译安装结果
function testing()
{
    local test_result                                                          # 定义局部变量
    log_file="${SERVICE_DIR}/${LOG_DIRECTORY}/test.log"                        # 测试 GCC 编译的日志路径
    
    echo "    ************************* $(date '+%T')：测试 Hello *************************    "
    cd "${SERVICE_DIR}/${FILE_DIRECTORY}" || exit                              # 进入源码路径
    
    {
        echo "#include <stdio.h>"
        echo "int main()"
        echo "{"
        echo "    printf(\"Hello World\nHello World\nHello World\n\");"
        echo "    return 0;"
        echo "}"
        echo ""
    } > "${SERVICE_DIR}/hello.c"
    
    # 用 gcc 编译：-Wall，编译后显示所有警告；-o，输出参数，输出名字的参数，如果不加 -o，会生成 a.out 的可执行文件
    "gcc${GCC_VERSION}" -Wall "${SERVICE_DIR}/hello.c" -o "${SERVICE_DIR}/hello" >> "${log_file}" 2>&1
    
    test_result=$("${SERVICE_DIR}/hello" | grep -ciw "Hello World")            # 运行编译结果
    if [[ ${test_result} -eq 3 ]]; then
        echo "    ************************** $(date '+%T')：测试完成 **************************    "
    else
        echo "    ************************** $(date '+%T')：测试失败 **************************    "
    fi
}
    

printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 2. 刷新变量
flush_env                                                                      # 刷新环境变量

# 3. 匹配输入参数
case "$1" in
    # 3.1 下载压缩包
    -d | --download | download)
        download
     ;;
    
    # 3.2 下载依赖
    -p | --depend | depend)
        depend
    ;;
    
    # 3.3 编译安装
    -c | --compile | compile)
        compile
    ;;
    
    # 3.4 添加环境变量
    -e | --environment | environment)
        environment
    ;;
    
    # 3.5 测试安装
    -t | --test | test)
        testing
    ;;
    
    # 3.6 安装 gcc
    -a | --all | all)
        download
        depend
        compile
        environment
        testing
    ;;
    
    # 3.7 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：      "
        echo "        +----------+-----------------+--------------+ "
        echo "        |  短参数  |    长 参 数     |    描  述    | "
        echo "        +----------+-----------------+--------------+ "
        echo "        |    -d    |  --download     |   下载文件   | "
        echo "        |    -p    |  --depend       |   下载依赖   | "
        echo "        |    -c    |  --compile      |   编译安装   | "
        echo "        |    -e    |  --environment  |   添加环境   | "
        echo "        |    -t    |  --test         |   测试安装   | "
        echo "        |    -a    |  --all          |   安装 GCC   | "
        echo "        +----------+-----------------+--------------+ "
    ;;
esac
    
# 4. 获取脚本执行结束时间，并计算脚本执行时间
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)
if [ "$#" -ge 1 ]; then
    echo "    脚本（$(basename "$0")）执行共消耗：$((end - start))s ...... "
fi
    
printf "================================================================================\n\n"
exit 0
