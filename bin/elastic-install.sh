#!/usr/bin/env bash
# shellcheck disable=SC2029,SC2120

# =========================================================================================
#    FileName      ：  elastic-install.sh
#    CreateTime    ：  2023-07-11 14:59:51
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  安装 elastic 相关软件
# =========================================================================================

SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="elastic-install-$(date +%F).log"                                     # 程序操作日志文件
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


# 安装并初始化 ElasticSearch
function es_install()
{
    echo "    ************************** 开始安装 ES ***************************    "
    local elasticsearch_list elasticsearch_port elasticsearch_host_ports elasticsearch_heap elasticsearch_version id host test_result
    
    JAVA_HOME=$(get_param "java.home")                                         # 获取 Java 安装路径
    ELASTIC_SEARCH_HOME=$(get_param "elasticsearch.home")                      # 获取  ES  安装路径
    file_decompress "elasticsearch.url" "${ELASTIC_SEARCH_HOME}"               # 解压  ES  安装包
    
    echo "    *********************** 修改 ES 配置文件 *************************    "
    mkdir -p "${ELASTIC_SEARCH_HOME}/data" "${ELASTIC_SEARCH_HOME}/logs"       # 创建必要的目录    
    cp -fpr "${ROOT_DIR}/script/elastic/elasticsearch.sh"  "${ELASTIC_SEARCH_HOME}/bin/"                # 复制 ES  启停脚本
    cp -fpr "${ROOT_DIR}/conf/elasticsearch.yml"           "${ELASTIC_SEARCH_HOME}/config/"             # 复制 ES  配置文件
    cp -fpr "${ROOT_DIR}/conf/elasticsearch-jvm.options"   "${ELASTIC_SEARCH_HOME}/config/jvm.options"  # 复制 JVM 配置文件
    
    elasticsearch_list=$(get_param "elasticsearch.hosts" | tr ',' ' ')         # 获取 ES 安装节点
    elasticsearch_port=$(get_param "elasticsearch.port")                       # 获取 ES 端口号
    elasticsearch_heap=$(get_param "elasticsearch.heap")                       # 获取 ES 占用内存
    elasticsearch_host_ports=$(echo "${elasticsearch_list}" | sed -e "s|$|,|g" | sed -e "s|,|:${elasticsearch_port}\", \"|g" | sed -e "s|^|\"|g" | sed -e "s|, \"$||g")
    
    # 修改启停脚本
    sed -i "s|\${elasticsearch_list}|${elasticsearch_list}|g"  "${ELASTIC_SEARCH_HOME}/bin/elasticsearch.sh"
    
    # 修改配置文件
    sed -i "s|\${ELASTIC_SEARCH_HOME}|${ELASTIC_SEARCH_HOME}|g"            "${ELASTIC_SEARCH_HOME}/config/elasticsearch.yml"
    sed -i "s|\${elasticsearch_port}|${elasticsearch_port}|g"              "${ELASTIC_SEARCH_HOME}/config/elasticsearch.yml"
    sed -i "s|\${elasticsearch_host_ports}|${elasticsearch_host_ports}|g"  "${ELASTIC_SEARCH_HOME}/config/elasticsearch.yml"
    
    # 修改 JVM 配置
    sed -i "s|\${elasticsearch_heap}|${elasticsearch_heap}|g"   "${ELASTIC_SEARCH_HOME}/config/jvm.options"
    
    elasticsearch_version=$(get_version "elasticsearch.url")                   # 获取 ES 的版本
    append_env      "elasticsearch.home"     "${elasticsearch_version}"        # 添加环境变量
    distribute_file "${elasticsearch_list}"  "${FLUME_HOME}/"                  # 分发到其它节点
    
    echo "    *********************** 修改 ES 唯一标识 *************************    "
    id=0
    for host in ${elasticsearch_list}
    do
        id=$((id + 1))
        xssh "${host}" "sed -i 's|\${id}|${id}|g' '${ELASTIC_SEARCH_HOME}/config/elasticsearch.yml'"
    done
    
    echo "    **************************** 启动 ES *****************************    "
    "${ELASTIC_SEARCH_HOME}/bin/elasticsearch.sh"  start >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    host=$(echo "${elasticsearch_list}" | awk '{print $1}')
    test_result=$(curl -XGET "http://${host}:${elasticsearch_port}/_cluster/state?pretty" | grep -ci "state_uuid") > /dev/null 
    if [ "${test_result}" -eq ${id} ]; then
        echo "    ************************** ES 测试成功 ***************************    "
    else
        echo "    ************************** ES 测试失败 ***************************    "
    fi
}


printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 2. 刷新变量
if [ "$#" -gt 0 ]; then
    export JAVA_HOME ELASTIC_SEARCH_HOME KIBANA_HOME LOGSTASH_HOME 
    flush_env                                                                    # 刷新环境变量   
fi

# 3. 匹配输入参数
case "$1" in
    # 3.1 安装 ElasticSearch 
    elasticsearch | -e)
        es_install
    ;;

    # 3.2 安装 LogStash 
    logstash | -l)
        logstash_install
    ;;
    # 3.3 安装 Kibana 
    kibana | -k)
        kibana_install
    ;;
    
    # 3.4 安装所有
    all | -a)
        es_install
        logstash_install
        kibana_install
    ;;
    
    # 3.5 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：             "
        echo "        +----------+-------------------------+ "
        echo "        |  参  数  |         描   述         | "
        echo "        +----------+-------------------------+ "
        echo "        |    -e    |  安装 elasticsearch     | "
        echo "        |    -l    |  安装 logstash          | "
        echo "        |    -k    |  安装 kibana            | "
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
