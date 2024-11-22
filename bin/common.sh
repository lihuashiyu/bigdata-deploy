#!/usr/bin/env bash
# shellcheck disable=SC2029,SC2120

# ==================================================================================================
#    FileName      ：  common.sh
#    CreateTime    ：  2023-07-29 21:34
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  部署项目的公共函数
# ==================================================================================================


# 创建必要的文件夹
function create_dir()
{
    local service_dir root_dir                                                 # 定义局部变量
    
    service_dir=$(dirname "$(readlink -e "$0")")                               # Shell 脚本目录
    root_dir=$(cd "${service_dir}/../" || exit; pwd)                           # 项目根目录
    
    mkdir -p "${root_dir}/logs"  "${root_dir}/package"                         # 创建日志目录和包下载目录   
}


# 拆分选项，删除不符合的参数，支持 GNU 短参数，长参数（$@）
function argument_split()
{
    local param argument argument_list               # 定义局部变量

    # 拆分选项
    for param in "$@"
    do
        # 1. 支持带有横线的参数
        if [[ "${param}" =~ ^- ]] && [[ ! "${param}" =~ ^[-]{3} ]]; then
            argument=$(echo "${param}" | awk -F '@' '{ print $1 }'  | awk '{gsub(/^\s+|\s+$/, ""); print}')
        # 2. 支持不带横线的参数
        elif [[ "${param}" =~ ^[a-zA-Z0-9] ]]; then
            argument=$(echo "${param}" | awk -F '@' '{ print $NF }' | sed -e 's|^[ \t]*||g' | sed -e 's|[ \t]*$||g')
        # 3. 错误参数
        else 
            echo "    命令支持短参数和长参数，参数格式如下：    "
            echo "        command -o [arg1 arg2 arg3 ...], command --option=[arg1,arg2,arg3 ...]   "
            return
        fi
        
        # 4. 将参数放进参数组，并删除前后的空格
        if [ -n "${param}" ]; then
            ARGUMENT_MAP[${#ARGUMENT_MAP[@]}]="${argument// /\$}"
        fi
    done
}


# 截取参数，将参数分组，支持 GNU 短参数，长参数（$@）
function argument_group()
{
    local param_list number n argument option param value result               # 定义局部变量

    param_list=("$@")                                                          # 使用数组存储参数
    number=${#param_list[@]}                                                   # 获取参数的数量

    # 倒序输出参数
    for ((n = number - 1; n >= 0; n--))
    do
        argument="${param_list[${n}]}"                                         # 获取函数参数值

        # 1. 支持长参数
        if [[ "${argument}" =~ ^-- ]] && [[ ! "${argument}" =~ ^[-]{3} ]]; then
            result=$(long_argument "${argument} ${param}")                     # 处理长参数
            param=""
        # 2. 支持短参数
        elif [[ "${argument}" =~ ^- ]] && [[ ! "${argument}" =~ ^[-]{2} ]]; then
            result=$(short_argument "${argument} ${param}")                     # 处理短参数
            param=""
        # 3. 参数值
        elif [[ "${argument}" =~ ^[a-zA-Z0-9] ]]; then
            param="${argument} ${param}"                                       # 处理参数值
        # 4. 错误参数
        else
            echo "    命令支持短参数和长参数，参数格式如下：    "
            echo "        command -o [arg1 arg2 arg3 ...], command --option=[arg1,arg2,arg3 ...]   "
        fi

        # 6. 将参数放进参数组，并删除前后的空格
        if [ -n "${result}" ]; then
            option=$(echo "${result}" | awk -F '@' '{ print $1 }'  | awk '{gsub(/^\s+|\s+$/, ""); print}')
            value=$(echo  "${result}" | awk -F '@' '{ print $NF }' | sed -e 's|^[ \t]*||g' | sed -e 's|[ \t]*$||g')

            ARGUMENT_MAP["${option}"]="${value}"
        fi
    done
}


# 处理长参数（$1：多个参数）
# shellcheck disable=SC2048
function long_argument()
{
    local argument option value                                                # 定义局部变量
    
    for argument in $*
    do
        # 获取长选项的值
        if [[ "${argument}" =~ -- ]]; then
            option=$(echo "${argument}@" | awk -F '=' '{print $1}' | awk -F ',' '{print $1}')
            
            # 获取长选项的参数
            if [[ "${argument}" =~ = ]]; then                            
                value="$(echo "${argument}" | awk -F '=' '{print $NF}' | awk '{print $1}' | tr ' ' '#' | tr ',' ' ')"
                break
            fi
        fi
    done
    
    # 舍去空值
    if [ -n "${value}" ]; then
        echo "${option}@${value}"
    else    
        echo "${option}"
    fi
}


# 处理短参数（$@：多个参数）
# shellcheck disable=SC2048
function short_argument()
{ 
    local argument option value                                                # 定义局部变量
    
    for argument in $*
    do
        # 获取短选项的值
        if [[ "${argument}" =~ - ]]; then
            option=$(echo "${argument}@" | awk -F '=' '{print $1}' | awk -F ',' '{print $1}')
            
            if [[ "${argument}" =~ = ]] || [[ "${argument}" =~ "#" ]] || [[ "${argument}" =~ , ]]; then            
                echo ""
                return
            fi    
        # 获取短选项的参数
        else            
            value="${value} $(echo "${argument}" | tr ' ' '#')"
        fi  
    done
    
    echo "${option}${value}"
}


# 读取配置文件，获取配置参数（$1：读取文件的绝对路径，$2：注释开始标识，$3：键值对分割标识）
function read_param()
{
    # 1. 定义局部变量
    local file_path="" annotation_symbol="#" separator="=" line string param key value
    
    if [ "$#" -eq 0 ]; then
        echo "    必须输入文件路径 ...... "
        exit 1
    elif [ "$#" -eq 1 ]; then
        file_path=$1
    elif [ "$#" -eq 2 ]; then
        file_path=$1
        annotation_symbol=$2               
    elif [ "$#" -eq 3 ]; then
        file_path=$1
        annotation_symbol=$2
        separator=$3
    else
        echo "    从第 4 个参数开始无效 ...... "
    fi
    
    # 2. 读取配置文件
    while read -r line
    do
        # 3. 去除行尾的回车、换行符，行首 和 行尾 的 空格 和 制表符
        string=$(echo "${line}" | sed -e 's/\r//g' | sed -e 's/\n//g' | sed -e 's/^[ \t]*//g' | sed -e 's/[ \t]*$//g')
        
        # 4. 判断是否为注释文字，是否为空行
        if [[ ! ${string} =~ ^${annotation_symbol} ]] && [ "" != "${string}" ]; then
            # 5. 去除末尾的注释，获取键值对参数，再去除首尾空格，为防止列表中空格影响将空格转为 #
            param=$(echo "${string}" | awk -F "${annotation_symbol}" '{print $1}' | sed -e 's/^[ \t]*//g' | sed -e 's/[ \t]*$//g')
            
            # 6. 将参数添加到参数列表
            if [ -n "${param}" ]; then
                # 7. 获取参数的键值对
                key=$(echo "${param}"   | awk -F "${separator}" '{print $1}'  | awk '{gsub(/^\s+|\s+$/, ""); print}')
                value=$(echo "${param}" | awk -F "${separator}" '{print $NF}' | awk '{gsub(/^\s+|\s+$/, ""); print}')
                
                # 8. 将键值对添加到 数组（Map）
                PARAM_LIST["${key}"]="${value}"
            fi
        fi
    done < "${file_path}"
}


# 读取文件（$1：读取文件的绝对路径）
function read_file()
{
    # 1. 定义局部变量
    local line line_value result_list=()
    
    # 2. 读取配置文件
    while read -r line
    do
        # 3. 去除行尾的回车、换行符，行首 和 行尾 的 空格 和 制表符
        line_value=$(echo "${line}" | sed -e 's/\r//g' | sed -e 's/\n//g' | sed -e 's/^[ \t]*//g' | sed -e 's/[ \t]*$//g')
        
        # 4. 判断是否为空行
        if [ -n "${line_value}" ]; then
            result_list[${#result_list[@]}]="${line_value// /\$}"
        fi
    done < "$1"
    
    echo "${result_list[*]}"
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
    
    # 获取结果
    value=$(echo "${PARAM_LIST[$1]}" | tr "\'$2\'" "\'$3\'")
    
    # 返回结果
    echo "${value}$4"
}


# 判断文件中参数是否存在，不存在就文件末尾追加（$1：待追加的参数，$2：文件绝对路径）
function append_param()
{
    # 定义参数
    local exist
    
    # 根据文件获取该文件中，是否存在某参数，不存在就追加到文件末尾
    exist=$(grep -nic "$1" "$2")
    if [ "${exist}" -ne 1 ]; then 
        echo -e "$1" >> "$2"
    fi
}


# 添加到环境变量（$1：配置文件中变量的 key，$1：，$2：软件版本号，$3：是否为系统环境变量）
function append_env()
{
    echo "    ************************** 添加环境变量 **************************    "
    local software_name variate_key variate_value password env_file exist
    
    software_name=$(echo "$1" | awk -F '.' '{print $1}')                       # 获取软件名称
    variate_key=$(echo "${1^^}" | tr '.' '_')                                  # 获取 Key
    variate_value=$(get_param "$1")                                            # 获取 Value
    password=$(get_password)                                                   # 获取管理员密码
    
    if [ -z "$3" ]; then
        env_file="/etc/profile.d/${USER}.sh"                                   # 系统环境变量文件
    else
        env_file="${HOME}/.bashrc"                                             # 用户环境变量文件
    fi
    
    exist=$(grep -ni "${variate_key}" "${env_file}")                           # 判断是否已经加入环境变量
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


# 下载软件包（$1：配置文件中软件包 url 的 key）
function download()
{
    local url file_name is_exist                                               # 定义局部变量
    url=$(get_param "$1")                                                      # 软件下载的 url
    
    # 下载软件包
    if [[ -n ${url} ]]; then
        file_name=$(echo "${url}" | sed 's/.*\/\([^\/]*\)$/\1/')               # 获取文件名
        rm -rf "${ROOT_DIR}/package/${file_name}"                              # 删除已经存在的安装包
        
        echo "    ********** 开始下载：${file_name} ********** "
        is_exist=$(command -v "curl" | wc -l)                                  # 判断 curl 命令是否存在
        if [ "${is_exist}" -eq 0 ]; then
            wget -P "${ROOT_DIR}/package" "${url}"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        else
            curl --parallel --parallel-immediate -k -L -C - -o "${ROOT_DIR}/package/${file_name}" "${url}" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        fi        
    else
        echo "    ********** ${CONFIG_FILE} 中没有 $1 ********** "
    fi
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
            tar -Jxvf "${ROOT_DIR}/package/${file_name}"             >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar.gz$ ]] || [[ "${file_name}" =~ tgz$ ]]; then
            tar -zxvf "${ROOT_DIR}/package/${file_name}"             >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar.bz2$ ]]; then
            tar -jxvf "${ROOT_DIR}/package/${file_name}"             >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar.Z$ ]]; then
            tar -Zxvf "${ROOT_DIR}/package/${file_name}"             >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ tar$ ]]; then
            tar -xvf "${ROOT_DIR}/package/${file_name}"              >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ zip$ ]]; then
            unzip "${ROOT_DIR}/package/${file_name}"                 >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ xz$ ]]; then
            xz -dk "${ROOT_DIR}/package/${file_name}"                >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ gz$ ]]; then
            gzip -dk "${ROOT_DIR}/package/${file_name}"              >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   
        elif [[ "${file_name}" =~ bz2$ ]]; then
            bzip2 -vcdk "${ROOT_DIR}/package/${file_name}"           >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ Z$ ]]; then
            uncompress -rc "${ROOT_DIR}/package/${file_name}"        >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ rar$ ]]; then
            unrar vx  "${ROOT_DIR}/package/${file_name}"             >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ rpm$ ]]; then
            rpm2cpio "${ROOT_DIR}/package/${file_name}" | cpio -div  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        elif [[ "${file_name}" =~ deb$ ]]; then
            ar -vx  "${ROOT_DIR}/package/${file_name}"               >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        else
            echo "File ===> ${file_name} 文件后缀异常 ...... "
        fi
        
        # 将文件夹移动到安装路径
        if [ -n "$2" ]; then
            folder=$(find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print)
            mkdir -p "$2"
            mv "${folder}/"* "$2"
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


# 分发文件到其它节点（$1：需要分发的节点，$2：需要分发的文件路径，$3：启用 root 进行传输）
function distribute_file()
{
    echo "    ************************ 分发到其它节点 **************************    "
    
    if [ -d "$HOME/.ssh" ]; then
        {
            xync  "$1" "/etc/profile.d/${USER}.sh" "env"
            xync  "$1" "$2" 
            xcall  "$1" "source ${HOME}/.bashrc; source /etc/profile"
        } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  
    else
        echo "    需要提前配置节点间免密登录：password-free-login.sh ...... "
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


# 集群间执行命令（$1：需要执行命令的节点，$2：命令）
function xssh()
{
    local password                                                             # 定义局部变量 
    password=$(get_param "server.password")                                    # 获取管理员密码
    
    if [ -n "$3" ]; then
        echo "${password}" | sudo -S ssh "root@$1" "source ~/.bashrc; source /etc/profile; $2"
    else 
        ssh "${USER}@$1" "source ~/.bashrc; source /etc/profile; $2"
    fi
}


# 集群间执行命令（$1：需要执行命令的集群节点，$2：命令，$3：启用 root 进行传输）
function xcall()
{
    local host_list cmd host_name                                              # 定义局部变量 
    host_list=$(echo "$1" | tr "#" " ")                                        # 获取主机列表
    cmd=$(echo "$2" | tr "#" " ")                                              # 获取命令
    
    for host_name in ${host_list}
    do
        echo "    ===================== ${host_name}：${cmd} =====================    "
        xssh "${host_name}" "${cmd}" "$3"
    done
}


# 集群间数据同步（$1：需要数据同步的集群节点，$2：同步的数据目录，$3：启用 root 进行传输）
function xync()
{
    local host_list host_name password                                         # 定义局部变量 
    host_list=$(echo "$1" | tr "#" " ")                                        # 获取主机列表
    password=$(get_param "server.password")                                    # 获取管理员密码
    
    for host_name in ${host_list}
    do
        echo "    ===================== 向（${host_name}）同步数据 =====================    "
        if [ -n "$3" ]; then
            echo "${password}" | sudo -S rsync -zav --delete  "$2"  "root@${host_name}:$2"
        else 
            rsync -zav --delete  "$2"  "${USER}@${host_name}:$2"
        fi
    done
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


# 判断命令是否存在（$1：需要查找的命令）
function command_exist()
{
    local exists
    exists=$(command -v "$1" > /dev/null 2>&1; echo $?)
    if [[ "${exists}" -eq 0 ]]; then
        echo "    **************************** 软件已经安装 ****************************    "
        echo "        ===> 位置：$(command -v "$1") "
        echo "        ===> 相关文件：$(whereis "$1") "
    else
        echo "    ***************** 推荐使用命令：sudo dnf install git *****************    "
    fi
}


create_dir
