#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  gnu.sh
#    CreateTime    ：  2023-07-29 21:34
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  编译安装 gcc、git、htop、
# ==================================================================================================


USER=$(whoami)                                                                 # 当前登录使用的用户
PARAM_LIST=()                                                                  # 配置文件中参数


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
            # 5. 去除末尾的注释，获取键值对参数，再去除首尾空格，为防止列表中空格影响将空格转为 #
            param=$(echo "${string}" | awk -F '#' '{print $1}' | awk '{gsub(/^\s+|\s+$/, ""); print}' | tr ' |\t' '#')
            
            # 6. 将参数添加到参数列表
            if [ -n "${param}" ]; then
                PARAM_LIST[${#PARAM_LIST[@]}]="${param}"
            fi
        fi
    done < "$1"
}


# 获取参数（$1：参数键值，$2：待替换的字符，$3：需要替换的字符，$4：后缀字符）
function get_param()
{
    # 定义局部变量
    local value
    
    # 获取参数，并进行遍历
    if [[ ${#PARAM_LIST[@]} -eq 0 ]]; then
        read_param "${ROOT_DIR}/conf/${CONFIG_FILE}"
    fi
    
    for param in "${PARAM_LIST[@]}"
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


# 添加到环境变量（$1：配置文件中变量的 key，$1：，$2：软件版本号，$3：是否为系统环境变量）
function append_env()
{
    echo "    ******************************* 添加环境变量 *******************************    "
    local software_name variate_key variate_value password env_file exist

    software_name=$(echo "$1" | awk -F '.' '{print $1}')
    variate_key=$(echo "${1^^}" | tr '.' '_')
    variate_value=$(get_param "$1")
    password=$(get_password)

    if [[ -z $3 ]]; then
        env_file="/etc/profile.d/${USER}.sh"
    else
        env_file="${HOME}/.bashrc"
    fi

    exist=$(grep -ni "${variate_key}" "${env_file}")
    if [ -z "${exist}" ]; then
        {
            echo "${password}" | sudo -S echo "# ===================================== ${software_name}-$2 ====================================== #"
            echo "${password}" | sudo -S echo "export ${variate_key}=${variate_value}"
            echo "${password}" | sudo -S echo "export PATH=\${PATH}:\${${variate_key}}/bin"
            echo "${password}" | sudo -S echo ""
        } >> "${env_file}"
    fi
    
    # 刷新环境变量
    source "${env_file}"
    source /etc/profile
}


# 获取配置文件中主机的密码
function get_password()
{
    local user password
    
    # 判断当前登录用户和配置文件中的用户是否相同
    user=$(get_param "server.user")
    
    if [ "${USER}" = "${user}" ]; then
        password=$(get_param "server.password")
    else
        echo "    配置文件：${ROOT_DIR}/conf/${CONFIG_FILE} 中用户和当前登录用户不同 ...... "
        exit 1
    fi
    
    echo "${password}"
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
        find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print -exec rm -rf {} +  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        cd "${ROOT_DIR}/package/" || exit                                       # 进入解压目录
        
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
            mv "${ROOT_DIR}/package/${folder}"* "$2"
        fi
    else
        echo "    文件 ${ROOT_DIR}/package/${file_name} 不存在 "
    fi
}


# 根据文件名获取软件版本号（$1：下载软件包 url 的 key）
function get_name()
{
    local file_name
    
    file_name=$(get_param "$1" | sed 's/.*\/\([^\/]*\)$/\1/')
    
    echo "${file_name}"
}


# 根据文件名获取软件版本号（$1：下载软件包 url 的 key）
function get_version()
{
    local version
    
    version=$(get_name "$1" | grep -oP "\d*\.\d*\.\d+")
    
    echo "${version}" 
}


# 分发文件到其它节点（$1：需要分发的文件路径）
function distribute_file()
{
    echo "    ************************ 分发到其它节点 **************************    "
    local password
    password=$(get_password)
    
    if [ -d "$HOME/.ssh" ]; then
        {
            echo "${password}" | sudo -S xync.sh  "/etc/profile.d/${USER}.sh"
            xync.sh   "$1"
            xcall.sh  "source /etc/profile"
        } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  
    else
        echo "    需要提前手动配置节点间免密登录 ...... "
        exit 1
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


# 获取目录下的所有目录（$1：需要查找的目录，$2：过滤目录）
function get_dir_list()
{
    # 定义参数
    local folder_list 
        
    if [ ! -e "$1" ] || [ ! -d "$1" ]; then
        echo "    ******************* $1：不是文件夹或不存在  ********************    "
        exit 1
    fi
    
    if [ "$#" -eq 2 ]; then
        folder_list=$(find "$1" -iname "*$2*" -maxdepth 0 -type d -print)
    else    
        folder_list=$(find "$1"  -maxdepth 0 -type d -print)
    fi
    
    echo "${folder_list}"
}


# 获取目录下的所有文件（$1：需要查找的目录，$2：过滤文件）
function get_file_list()
{
    # 定义参数
    local file_name_list 
    
    if [ ! -e "$1" ] || [ ! -d "$1" ]; then
        echo "    ******************* $1：不是文件夹或不存在  ********************    "
        exit 1
    fi
    
    if [ "$#" -eq 2 ]; then
        file_name_list=$(find "$1" -iname "*$2*" -maxdepth 0 -type f -print)
    else    
        file_name_list=$(find "$1"  -maxdepth 0 -type f -print)
    fi
    
    echo "${file_name_list}"
}


printf "\n    ************************ 获取公共函数成功 ************************    \n\n"
