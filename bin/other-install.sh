#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  other-install.sh
#    CreateTime    ：  2023-08-25 21:21
#    Author        ：  lihua shiyu
#    Email         ：  issacal@qq.com
#    IDE           ：  lihuashiyu@github.com
#    Description   ：  安装软件：Nginx
# ==================================================================================================


SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="other-install-$(date +%F).log"                                       # 程序操作日志文件
USER=$(whoami)                                                                 # 当前登录使用的用户  


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
    
    echo "    ************************** 获取公共函数 **************************    "
    # shellcheck source=./common.sh
    source "${ROOT_DIR}/bin/common.sh"                                         # 当前程序使用的公共函数
    
    export -A PARAM_LIST=()                                                    # 初始化 配置文件 参数
    read_param "${ROOT_DIR}/conf/${CONFIG_FILE}"                               # 读取配置文件，获取参数        
}


# 安装并初始化 Nginx
function nginx_install()
{
    echo "    ************************* 开始安装 Nginx *************************    "
    local nginx_home folder nginx_host nginx_port nginx_version result_count
     
    nginx_home=$(get_param "nginx.home")                                       # Nginx 安装路径
    download        "nginx.url"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1       # 下载 Nginx 源码    
    file_decompress "nginx.url"                                                # 解压 Nginx 源码包
    
    echo "    **************************** 编译源码 ****************************    "
    folder=$(find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print)         # 获取解压目录
    cd "${folder}" || exit                                                     # 进入 Nginx 源码目录
    {
        git clone https://github.com/fdintino/nginx-upload-module.git               # 获取 上传文件 模块源码
        git clone https://github.com/masterzen/nginx-upload-progress-module.git     # 获取
    } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    rm -rf  "${nginx_home}"                                                    # 删除可能存在的安装目录
    
    {
        cd "${folder}" || exit                                                 # 进入 Nginx 源码目录
        # 指定安装路径和编译模块
        ./configure --prefix="${nginx_home}"         --add-dynamic-module="${folder}/nginx-upload-module" \
                    --with-compat                    --with-http_gzip_static_module                       \
                    --with-stream                    --with-http_image_filter_module                      \
                    --with-file-aio                  --with-http_ssl_module                               \
                    --with-http_realip_module        --with-http_addition_module                          \
                    --with-http_sub_module           --with-http_dav_module                               \
                    --with-http_flv_module           --with-http_mp4_module                               \
                    --with-http_gunzip_module        --with-http_gzip_static_module                       \
                    --with-http_random_index_module  --with-http_secure_link_module                       \
                    --with-http_stub_status_module   --with-http_auth_request_module 
        cd "${folder}" || exit                                                 # 进入 Nginx 源码目录             
        make                                                                   # 编译源码
        cd "${folder}" || exit                                                 # 进入 Nginx 源码目录
        make install                                                           # 安装到指定路径
    } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    echo "    ************************** 修改配置文件 **************************    "
    # 创建必要的目录
    mkdir -p    "${nginx_home}/data/file"            "${nginx_home}/data/upload" "${nginx_home}/logs"
    mv          "${nginx_home}/sbin"                 "${nginx_home}/bin"            # 修改目录名称
    cp    -fpr  "${ROOT_DIR}/script/other/nginx.sh"  "${nginx_home}/bin/"           # 复制 启停脚本
    cp    -fpr  "${ROOT_DIR}/conf/nginx.conf"        "${nginx_home}/conf/"          # 复制 配置文件
    cp    -fpr  "${ROOT_DIR}/lib/nginx-rename.py"    "${nginx_home}/data/upload"    # 复制 重命名 文件    
    mv          "${nginx_home}/html"                 "${nginx_home}/data"           # 移动目录
    # tar   -zxf  "${ROOT_DIR}/lib/upload.tar.gz"  -C  "${nginx_home}/data/upload"  # 上传页面
    tar   -zxf  "${ROOT_DIR}/lib/hive.tar.gz"    -C  "${nginx_home}/data/"          # Hive 计划可视化页面
    
    nginx_version=$(get_version "nginx.url")                                   # 获取 Nginx 版本
    append_env "nginx.home" "${nginx_version}"                                 # 添加环境变量
    
    echo "    **************************** 启动程序 ****************************    "
    "${nginx_home}/bin/nginx" -c "${nginx_home}/conf/nginx.conf"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    sleep 3
    
    nginx_host=$(hostname)
    nginx_port=$(grep -m 1 -niE "^[ ]+ listen.*;" "${nginx_home}/conf/nginx.conf" | awk '{print $3}' | awk -F ';' '{print $1}' | awk '{print $1}' )
    curl -o "${nginx_home}/logs/test.log" "http://${nginx_host}:${nginx_port}/index.html" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    result_count=$(grep -nic "thank you" "${nginx_home}/logs/test.log")
    if [ "${result_count}" -ne 1 ]; then
        echo "    **************************** 验证失败 ****************************    "
    else
        echo "    **************************** 验证成功 ****************************    "
    fi
}


# 安装并初始化 NodeJs
function node_install()
{
    echo "    ************************ 开始安装 NodeJs *************************    "
    local node_home node_version mirror_url result_count                       # 定义局部变量
    
    node_home=$(get_param "nodejs.home")                                       # NodeJs 安装路径    
    node_version=$(get_version "nodejs.url")                                   # 获取 NodeJs 版本
    
    echo "    *************************** 安装 NodeJS **************************    " 
    download        "nodejs.url"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1      # 下载软件
    file_decompress "nodejs.url"   "${node_home}"                              # 解压 NodeJs 包
    append_env      "nodejs.home"  "${node_version}"  "env"                    # 添加环境变量
    
    echo "    ************************** 修改配置文件 **************************    "
    mkdir -p  "${node_home}/data/cache" "${node_home}/data/global"             # 创建 存储目录
    mirror_url=$(get_param "npm.mirror")                                       # 获取 npm 国内镜像地址 
    "${node_home}/bin/npm"  config  set registry  "${mirror_url}"              # 设置 npm 国内镜像
    "${node_home}/bin/npm"  config  set prefix    "${node_home}/data/global"   # 设置 npm 下载缓存路径
    "${node_home}/bin/npm"  config  set cache     "${node_home}/data/cache"    # 设置 npm 存储路径
    
    echo "const hello = 'Hello world'"  >>  "${node_home}/data/hello.js" 
    echo "console.log(hello)"           >>  "${node_home}/data/hello.js"     
    result_count=$("${node_home}/bin/node" "${node_home}/data/hello.js" | grep -ic "Hello world")    
    if [ "${result_count}" -ne 1 ]; then
        echo "    **************************** 验证失败 ****************************    "
    else
        echo "    **************************** 验证成功 ****************************    "
    fi
}


# Vim 安装插件 YouCompleteMe
function vim_plugin_ycm()
{
    echo "    ********************* 开始安装 YouCompleteMe *********************    "
    local vim_plugin_home ycm_url pass_word                                    # 定义局部变量
     
    vim_plugin_home=$(get_param "vim.plugin.home")                             # Vim 插件安装路径
    ycm_url=$(get_param "vim.ycm.url")                                         # ycm 源码地址
    pass_word=$(get_password)                                                  # 管理员密码
    
    echo "    **************************** 下载源码 ****************************    "
    rm -rf "${vim_plugin_home}/YouCompleteMe"                                  # 若存在 ycm 路径就删除
    echo "${pass_word}" | sudo -S mkdir -p "${vim_plugin_home}"                # 创建 插件路径
    echo "${pass_word}" | sudo -S chown -R "${USER}:${USER}" "${vim_plugin_home}"   # 将创建的文件夹授权给用户 
    cd "${vim_plugin_home}" || exit                                            # 进入插件目录、
    git clone "${ycm_url}"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1            # 克隆源码
    
    echo "    **************************** 下载依赖 ****************************    "
    cd "${vim_plugin_home}/YouCompleteMe" || exit                              # 进入 ycm 源码目录、
    git submodule update --init --recursive >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  # 下载依赖 
    
    echo "    **************************** 编译源码 ****************************    "
    cd "${vim_plugin_home}/YouCompleteMe" || exit                              # 进入 ycm 源码目录、
    python3 install.py --all --verbose >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  # 编译源码
    
    echo "    ************************** 修改配置文件 **************************    "
    echo "${pass_word}" | sudo -S sed -i "s|\"set runtimepath.*|set runtimepath+=${vim_plugin_home}/YouCompleteMe|g"  /etc/vimrc.local 
}


#  安装 micro 编辑器
function micro_install()
{
    echo "    ************************* 开始安装 micro *************************    "
    local micro_home micro_url pass_word folder result_count                   # 定义局部变量
     
    micro_home=$(get_param "micro.home")                                       # Micro 插件安装路径
    micro_url=$(get_param "micro.url")                                         # micro 下载地址
    pass_word=$(get_password)                                                  # 管理员密码
    
    echo "    **************************** 安装软件 ****************************    "
    download        "micro.url"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1       # 下载软件
    file_decompress "micro.url"                                                # 解压 micro 压缩包
    folder=$(find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print)         # 获取解压目录
    cd "${folder}" || exit                                                     # 进入 micro 解压目录    
    echo "${pass_word}" | sudo -S cp -fpr "${folder}/micro" /usr/local/bin/micro    # 安装软件
    
    result_count=$(micro --version | grep -nic "version")
    if [ "${result_count}" -ne 1 ]; then
        echo "    **************************** 验证失败 ****************************    "
    else
        echo "    **************************** 验证成功 ****************************    "
    fi 
}


printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 2. 刷新变量
if [ "$#" -gt 0 ]; then
    export NGINX_HOME 
    flush_env                                                                  # 刷新环境变量    
fi

# 3. 匹配输入参数
case "$1" in
    # 3.1 安装 nginx
    nginx | -n)
        nginx_install
    ;;
    
    # 3.1 安装 nginx
    node | -j)
        node_install
    ;;
    
    # 3.3 安装 vim 插件
    vim | -v)
        vim_plugin_ycm
    ;;
    
    # 3.4 安装 micro
    micro | -m)
        micro_install
    ;;
    
    # 3.5 安装以上所有
    all | -a)
        nginx_install
    ;;
    
    # 3.6 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：             "
        echo "        +----------+-------------------------+ "
        echo "        |  参  数  |         描   述         | "
        echo "        +----------+-------------------------+ "
        echo "        |    -n    |  安装 nginx             | "
        echo "        |    -j    |  安装 node-js           | "
        echo "        |    -v    |  安装 vim 插件          | "
        echo "        |    -m    |  安装 micro             | "
        echo "        |    -a    |  安装以上所有           | "
        echo "        +----------+-------------------------+ "
    ;;
esac

# 4. 获取脚本执行结束时间，并计算脚本执行时间
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)
if [ "$#" -ge 1 ]; then
    echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
fi

printf "================================================================================\n\n"
exit 0
