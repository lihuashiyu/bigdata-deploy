#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  apache-install
#    CreateTime    ：  2023-07-11 14:59:51
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  安装数据库相关软件：apache 相关大数据组件
# =========================================================================================


SERVICE_DIR=$(cd "$(dirname "$0")" || exit; pwd)                               # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 组件安装根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="apache-install-$(date +%F).log"                                      # 程序操作日志文件
USER=$(whoami)                                                                 # 当前登录使用的用户
HADOOP_HOME="/opt/apache/hadoop"                                               # Hadoop 默认安装路径 
SPARK_HOME="/opt/apache/spark"                                                 # Spark  默认安装路径 
FLINK_HOME="/opt/apache/flink"                                                 # Flink  默认安装路径 
ZOOKEEPER_HOME="/opt/apache/zookeeper"                                         # Zookeeper  默认安装路径 
KAFKA_HOME="/opt/apache/kafka"                                                 # Kafka  默认安装路径 
HIVE_HOME="/opt/apache/hive"                                                   # Hive   默认安装路径 
DORIS_HOME="/opt/apache/doris"                                                 # Doris  默认安装路径 


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
    
    if [[ -z "$3" ]]; then
        env_file="/etc/profile.d/${USER}.sh"
    else
        env_file="${HOME}/.bashrc"
    fi
    
    exist=$(grep -ni "${variate_key}" "${env_file}")
    if [ -z "${exist}" ]; then 
        echo "${password}" | sudo -S echo "# ===================================== ${software_name}-$2 ====================================== #" >> "${env_file}"
        echo "${password}" | sudo -S echo "export ${variate_key}=${variate_value}"      >> "${env_file}"
        echo "${password}" | sudo -S echo "export PATH=\${PATH}:\${${variate_key}}/bin" >> "${env_file}"
        echo "${password}" | sudo -S echo ""                                            >> "${env_file}"
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
        cd "${ROOT_DIR}/package" || exit
        ls -F "${ROOT_DIR}/package" | grep "/$" | xargs rm -rf
        
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
            folder=$(ls -F | grep "/$")
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


# 安装并初始化 Hadoop
function hadoop_install()
{
    echo "    ************************ 开始安装 Hadoop *************************    "
    HADOOP_HOME=$(get_param "hadoop.home")                                 # 获取 Hadoop 安装路径
    file_decompress "hadoop.url" "${HADOOP_HOME}"                          # 解压 Hadoop 安装包
    
    echo "    ********************* 修改 Hadoop 配置文件 ***********************    "
    
}


# 安装并初始化 Spark
function spark_install()
{
    echo "    ************************* 开始安装 Spark *************************    "
    
}


# 安装并初始化 Flink
function flink_install()
{
    echo "    ************************* 开始安装 Flink *************************    "
    
}


# 安装并初始化 Zookeeper
function zookeeper_install()
{
    echo "    *********************** 开始安装 Zookeeper ***********************    "
    
}


# 安装并初始化 Kafka
function kafka_install()
{
    echo "    ************************* 开始安装 Kafka *************************    "
    
}


# 安装并初始化 Hive
function hive_install()
{
    echo "    ************************* 开始安装 Hive **************************    "
    
}


# 安装并初始化 Doris
function doris_install()
{
    echo "    ************************* 开始安装 Doris *************************    "
    
}


# 安装并初始化 HBase
function hbase_install()
{
    echo "    ************************* 开始安装 HBase *************************    "
    
}


# 安装并初始化 Phoenix
function phoenix_install()
{
    echo "    ************************ 开始安装 Phoenix ************************    "
    
}


# 安装并初始化 Flume
function flume_install()
{
    echo "    ************************* 开始安装 Flume *************************    "
    
}


printf "\n================================================================================\n"
mkdir -p "${ROOT_DIR}/logs"                                                    # 创建日志目录

# 匹配输入参数
case "$1" in
    # 1. 安装 hadoop 
    hadoop | -h)
        hadoop_install
    ;;
    
    # 2. 安装 spark
    spark | -s)
        spark_install
    ;;
    
    # 3. 安装 flink 
    flink | -f)
        flink_install
    ;;
    
    # 4. 安装 maven
    zookeeper | -z)
        zookeeper_install
    ;;
    
    # 5. 安装 kafka
    kafka | -k)
        kafka_install
    ;;
    
    # 6. 安装 hive
    hive | -i)
        hive_install
    ;;
    
    # 7. 安装 doris
    doris | -d)
        doris_install
    ;;
    
    # 8. 安装 hbase
    hbase | -b)
        hbase_install
    ;;
    
    # 9. 安装 phoenix
    phoenix | -p)
        phoenix_install
    ;;
    
    # 10. 安装 flume
    flume | -l)
        flume_install
    ;;
    
    # 11. 安装必要的软件包
    all | -a)
        hadoop_install
        spark_install
        flink_install
        zookeeper_install
        kafka_install
        hive_install
        doris_install
        hbase_install
        phoenix_install
        flume_install
    ;;
    
    # 10. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：   "
        echo "        +----------+-------------------------+ "
        echo "        |  参  数  |         描   述         |  "
        echo "        +----------+-------------------------+ "
        echo "        |    -h    |  安装 apache hadoop     | "
        echo "        |    -s    |  安装 apache spark      | "
        echo "        |    -f    |  安装 apache flink      | "
        echo "        |    -z    |  安装 apache zookeeper  | "
        echo "        |    -k    |  安装 apache kafka      | "
        echo "        |    -i    |  安装 apache hive       | "
        echo "        |    -d    |  安装 apache doris      | "
        echo "        |    -b    |  安装 apache hbase      | "
        echo "        |    -p    |  安装 apache phoenix    | "
        echo "        |    -l    |  安装 apache flume      | "
        echo "        |    -a    |  安装以上所有           | "
        echo "        +----------+-------------------------+ "
    ;;
esac
printf "================================================================================\n\n"
exit 0