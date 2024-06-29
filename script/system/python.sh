#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  python.sh
#    CreateTime    ：  2024-06-06 18:51
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  python.sh 被用于 ==> 编译安装 Python
# =========================================================================================

PYTHON_HOME="/opt/python"                                                      # Python 安装路径
URL="https://mirrors.huaweicloud.com/python/3.12.4/Python-3.12.4.tar.xz"       # Python 下载路径
PASSWORD="111111"                                                              # 管理员账号密码，root 运行，则不需要
    
SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
LOG_DIRECTORY="${SERVICE_DIR}/python-log"                                      # 程序操作日目录名
FILE_NAME=$(echo "${URL}" | awk -F '/' '{ print $NF}')                         # 获取下载的压缩包路径
FILE_DIRECTORY=$(echo "${FILE_NAME}" | awk -F '.' '{ print $1"."$2"."$3}')     # 文件解压路径
PYTHON_VERSION=$(echo "${FILE_NAME}" | awk -F '.' '{print $1$2}' | grep -oP "\d*")  # 获取 Python 主版本号
    

# 刷新环境变量
function flush_env()
{
    echo "    ************************ $(date '+%T')：刷新环境变量 ************************    "
    source "/etc/profile"                                                      # 刷新系统环境变量
    
    if [ -e "${HOME}/.bash_profile" ]; then                                    # 刷新用户环境变量
        source "${HOME}/.bash_profile"                                         # RedHat 用户环境变量文件
    fi
    
    if [ -e "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"                                               # Debian、RedHat 用户环境变量文件
    fi
    
    mkdir -p "${LOG_DIRECTORY}"                                                # 创建日志文件夹
}
    

# 下载软件包
function download()
{
    local is_exist log_file                                                    # 定义局部变量
    log_file="${LOG_DIRECTORY}/download.log"                                   # 下载 Python 软件包的日志
    
    # 下载软件包
    if [ -n "${URL}" ]; then
        cd "${SERVICE_DIR}" || exit                                            # 进入到项目目录
        rm -f "${FILE_NAME}"                                                   # 删除已经存在的安装包
        
        echo "    *************** $(date '+%T')：开始下载 ${FILE_NAME} ****************    "
        is_exist=$(command -v "curl" | wc -l)                                  # 判断 curl 命令是否存在
        if [ "${is_exist}" -eq 0 ]; then
            wget -P "${SERVICE_DIR}" "${URL}" >> "${log_file}" 2>&1
        else
            curl --parallel --parallel-immediate -k -L -C - -o "${SERVICE_DIR}/${FILE_NAME}" "${URL}" \
                >> "${log_file}" 2>&1
        fi
        
        is_text=$(file "${SERVICE_DIR}/${FILE_NAME}" | grep -ci "text")        # 判断下载内容
        if [ "${is_text}" -eq 0 ]; then
            echo "    ************** $(date '+%T')：${FILE_NAME} 下载完成 *****************    "
        else
            echo "    ************** $(date '+%T')：${FILE_NAME} 下载失败 *****************    "
            exit 1
        fi                
    else
        echo "    ****************************** url 不存在 ******************************    "
        exit 1
    fi
}
    

# 下载相关依赖
function decompress()
{
    local log_file                                                             # 定义局部变量
    log_file="${LOG_DIRECTORY}/decompress.log"                                 # 格式解压日志
    
    cd "${SERVICE_DIR}" || exit                                                # 进入到项目目录
    rm    -rf "${FILE_DIRECTORY}"                                              # 删除可能存在的已解压目录
    mkdir -p  "${FILE_DIRECTORY}"                                              # 创建需要的文件夹
    
    echo "    ***************** $(date '+%T')：解压 ${FILE_NAME} ******************    "
    if [ -e "${FILE_NAME}" ]; then                                             # 判断文件是否存在        
        tar -Jxvf "${FILE_NAME}"   >> "${log_file}"     2>&1
    else
        echo "    ******************** 文件 ${FILE_NAME} 不存在 *********************    "
        exit 1
    fi   
}
   
   
# 编译安装
function compile()
{
    local configure_log compile_log install_log build_directory cpu_thread     # 定义局部变量
    
    build_directory="${SERVICE_DIR}/${FILE_DIRECTORY}/build"                   # 源码编译目录
    configure_log="${LOG_DIRECTORY}/configure.log"                             # 配置日志
    compile_log="${LOG_DIRECTORY}/compile.log"                                 # 编译日志
    install_log="${LOG_DIRECTORY}/install.log"                                 # 安装日志
    
    mkdir -p "${build_directory}"                                              # 创建源码编译路径
    cpu_thread=$(grep -i "cpu cores" /proc/cpuinfo | uniq | awk '{print $NF}') # 获取 cpu 核心数
    
    echo "    *********************** $(date '+%T')：生成 MakeFile ************************    "
    cd "${build_directory}" || exit                                            # 进入源码编译路径
    ../configure  --prefix="${PYTHON_HOME}"      \
                  --enable-shared                \
                  --enable-optimizations         \
        >> "${configure_log}" 2>&1
            
    echo "    ************************** $(date '+%T')：编译源码 **************************    "
    cd "${build_directory}" || exit                                            # 进入源码编译路径
    make "-j${cpu_thread}"   >> "${compile_log}" 2>&1                          # 编译 python    
    
    if [ "$?" ]; then                                                          # 判断编译结果
        echo "    ************************** $(date '+%T')：编译成功 **************************    "
    else    
        echo "    ************************** $(date '+%T')：编译失败 **************************    "
        exit 1        
    fi
        
    echo "    ************************ $(date '+%T')：安装 Python *************************    "
    
    cd "${build_directory}" || exit                                            # 进入源码编译路径
    rm -rf "${PYTHON_HOME}"                                                    # 删除可能安装过的目录
    make install             >> "${install_log}" 2>&1                          # 安装 Python 
    
    if [ "$?" ]; then                                                          # 判断安装结果
        echo "    ************************** $(date '+%T')：安装成功 **************************    "
    else    
        echo "    ************************** $(date '+%T')：安装失败 **************************    "
        exit 1        
    fi
}    
     

# 添加到环境变量    
function environment()
{    
    local pv iv system_version install_version                                 # 定义局部变量
    
    echo "    ************************ $(date '+%T')：添加环境变量 ************************    "    
    install_version=$(echo "${FILE_DIRECTORY}" | awk -F '-' '{print $NF}' | awk -F '.' '{print $1"."$2}')    
    
    # 判断是否是 root 账户
    if [ "${USER}" == "root" ]; then
        rm -f "/usr/local/bin/python${PYTHON_VERSION}"                         # 删除已存在的 python 软连接
        rm -f "/usr/local/bin/pip${PYTHON_VERSION}"                            # 删除已存在的   pip  软连接
        
        ln -s "${PYTHON_HOME}/bin/python${install_version}"  "/usr/local/bin/python${PYTHON_VERSION}"
        ln -s "${PYTHON_HOME}/bin/pip${install_version}"     "/usr/local/bin/pip${PYTHON_VERSION}"
        
        ldconfig  "${PYTHON_HOME}/lib/"                                        # 添加共享库
    else    
        echo "${PASSWORD}" | sudo -S rm -f  "/usr/local/bin/python${PYTHON_VERSION}"
        echo "${PASSWORD}" | sudo -S rm -f  "/usr/local/bin/pip${PYTHON_VERSION}"
        
        echo "${PASSWORD}" | sudo -S ln -s "${PYTHON_HOME}/bin/python${install_version}" "/usr/local/bin/python${PYTHON_VERSION}"
        echo "${PASSWORD}" | sudo -S ln -s "${PYTHON_HOME}/bin/pip${install_version}"    "/usr/local/bin/pip${PYTHON_VERSION}"
        
        echo "${PASSWORD}" | sudo -S chown -R "${USER}:${USER}"  "/usr/local/bin/python${PYTHON_VERSION}"
        echo "${PASSWORD}" | sudo -S chown -R "${USER}:${USER}"  "/usr/local/bin/pip${PYTHON_VERSION}"     
        
        echo "${PASSWORD}" | sudo -S ldconfig "${PYTHON_HOME}/lib/"            # 添加共享库   
        echo ""
    fi
    
    system_version=$(grep -i "linux" /etc/os-release | tr -cd '[0-9]\.' | awk -F '.' '{print $1}')
    if [ -n "${system_version}" ] && [ "${system_version}" -lt 9 ]; then       # 修改 yum 使用的 python 版本
        echo "${PASSWORD}" | sudo -S sed -i "s|^#!\/usr\/bin\/python|#!\/usr\/local\/bin\/python2.7|g" /usr/bin/yum 
        echo "${PASSWORD}" | sudo -S sed -i "s|^#!\/usr\/bin\/python|#!\/usr\/local\/bin\/python2.7|g" /usr/libexec/urlgrabber-ext-down
    fi
        
    pv=$("python${PYTHON_VERSION}" -V | grep -ci "${install_version}")         # 验证 python 版本号
    iv=$("pip${PYTHON_VERSION}"    -V | grep -ci "${install_version}")         # 验证 pip 版本号
    if [ "${pv}" -ne 1 ] || [ "${iv}" -ne 1 ]; then
        echo "    ************************** $(date '+%T')：添加失败 **************************    "
        exit 1
    fi
    
    echo "    ************************** $(date '+%T')：添加成功 **************************    " 
}
    

# 测试编译安装结果
function testing()
{
    local test_log test_result                                                 # 定义局部变量
    test_log="${LOG_DIRECTORY}/test.log"                                       # 测试 Python 编译的日志路径
    
    echo "    ************************* $(date '+%T')：测试 Hello *************************    "
    cd "${SERVICE_DIR}/${FILE_DIRECTORY}" || exit                              # 进入源码路径
    
    {
        echo "#!/usr/local/bin/python${PYTHON_VERSION}"
        echo ""
        echo "print(\"Hello Python ${PYTHON_VERSION}! \")"
        echo ""
    } > "${SERVICE_DIR}/test.py"
        
    chmod +x "${SERVICE_DIR}/test.py"                                          # 给文件添加执行权限
    test_result=$("${SERVICE_DIR}/test.py" | grep -ci "${PYTHON_VERSION}!")    # 获取执行后的结果
    if [ "${test_result}" -eq 1 ]; then
        echo "    ************************** $(date '+%T')：测试完成 **************************    "
    else
        echo "    ************************** $(date '+%T')：测试失败 **************************    "
        exit 1
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
    
    # 3.2 编译安装
    -o | --decompress | decompress)
        decompress
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
    
    # 3.6 安装 Python 
    -a | --all | all)
        download
        decompress
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
        echo "        |    -c    |  --compile      |   编译安装   | "
        echo "        |    -o    |  --decompress   |   编译安装   | "
        echo "        |    -e    |  --environment  |   添加环境   | "
        echo "        |    -t    |  --test         |   测试安装   | "
        echo "        |    -a    |  --all          |   安装 Python   | "
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
