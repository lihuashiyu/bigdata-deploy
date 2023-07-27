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
JAVA_HOME="/opt/java/jdk"                                                      # Java     默认安装路径  
SCALA_HOME="/opt/java/scala"                                                   # Scala    默认安装路径  
HADOOP_HOME="/opt/apache/hadoop"                                               # Hadoop   默认安装路径 
SPARK_HOME="/opt/apache/spark"                                                 # Spark    默认安装路径 
FLINK_HOME="/opt/apache/flink"                                                 # Flink    默认安装路径 
ZOOKEEPER_HOME="/opt/apache/zookeeper"                                         # Zookeeper  默认安装路径 
KAFKA_HOME="/opt/apache/kafka"                                                 # Kafka    默认安装路径 
HIVE_HOME="/opt/apache/hive"                                                   # Hive     默认安装路径 
DORIS_HOME="/opt/apache/doris"                                                 # Doris    默认安装路径 
FLUME_HOME="/opt/apache/flume"                                                 # Flume    默认安装路径 
HBASE_HOME="/opt/apache/hbase"                                                 # HBase    默认安装路径 
PHOENIX_HOME="/opt/apache/phoenix"                                             # Phoenix  默认安装路径 


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
    echo "    ************************** 添加环境变量 ***************************    "
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


# 分发文件到其它节点（$1：需要分发的文件路径）
function distribute_file()
{
    echo "    ************************ 分发到其它节点 **************************    "
    local password
    password=$(get_password)
    
    if [ -d "$HOME/.ssh" ]; then
        echo "${password}" | sudo -S xync.sh  "/etc/profile.d/${USER}.sh" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
        
        xync.sh  "$1"                   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
        xcall.sh  "source /etc/profile"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
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


# 安装并初始化 Hadoop
function hadoop_install()
{
    echo "    ************************ 开始安装 Hadoop *************************    "
    local host_list user hadoop_version password host host_name
    
    JAVA_HOME=$(get_param "java.home")                                     # 获取 java   安装路径
    HADOOP_HOME=$(get_param "hadoop.home")                                 # 获取 Hadoop 安装路径
    file_decompress "hadoop.url" "${HADOOP_HOME}"                          # 解压 Hadoop 安装包
    
    echo "    ********************* 修改 Hadoop 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/script/apache/hadoop.sh"     "${HADOOP_HOME}/bin/"
    
    cp -fpr "${ROOT_DIR}/conf/hadoop-core-site.xml"   "${HADOOP_HOME}/etc/hadoop/core-site.xml"
    cp -fpr "${ROOT_DIR}/conf/hadoop-hdfs-site.xml"   "${HADOOP_HOME}/etc/hadoop/hdfs-site.xml"
    cp -fpr "${ROOT_DIR}/conf/hadoop-mapred-site.xml" "${HADOOP_HOME}/etc/hadoop/mapred-site.xml"
    cp -fpr "${ROOT_DIR}/conf/hadoop-yarn-site.xml"   "${HADOOP_HOME}/etc/hadoop/yarn-site.xml"
    
    sed -i "s|\${HADOOP_HOME}|${HADOOP_HOME}|g"                           "${HADOOP_HOME}"/etc/hadoop/*-site.xml
    sed -i "s|# export JAVA_HOME=|export JAVA_HOME=${JAVA_HOME}|g"        "${HADOOP_HOME}"/etc/hadoop/hadoop-env.sh
    sed -i "s|# export HADOOP_HOME=|export HADOOP_HOME=${HADOOP_HOME}|g"  "${HADOOP_HOME}"/etc/hadoop/hadoop-env.sh
    
    append_param "JAVA_HOME=${JAVA_HOME}"     "${HADOOP_HOME}/etc/hadoop/yarn-env.sh"
    rm -rf "${HADOOP_HOME}/etc/hadoop/workers"
    touch  "${HADOOP_HOME}/etc/hadoop/workers"
    
    host_list=$(get_param "server.hosts" | tr ',' ' ')
    for host in ${host_list}
    do
        host_name=$(echo "${host}" | awk -F ':' '{print $2}')
        if [[ "${host_name}" =~ slave ]]; then
            append_param "${host_name}" "${HADOOP_HOME}/etc/hadoop/workers"
        fi
    done    
    
    echo "    *********************** 创建数据存储目录 *************************    "
    mkdir -p "${HADOOP_HOME}/data" "${HADOOP_HOME}/logs"
    
    user=$(get_param "server.user")
    hadoop_version=$(get_version "hadoop.url")
    append_env "hadoop.home" "${hadoop_version}"
    
    password=$(get_password)
    echo "${password}" | sudo -S sed -i "s|\${HADOOP_HOME}\/bin$|\${HADOOP_HOME}\/bin:\${HADOOP_HOME}\/sbin|g" "/etc/profile.d/${user}.sh"
    append_param "export HADOOP_CLASSPATH=\$(hadoop classpath)"                  "/etc/profile.d/${user}.sh"
    append_param "                                            "                  "/etc/profile.d/${user}.sh"
    
    distribute_file "${HADOOP_HOME}/"                                          # 分发文件到其它节点
        
    echo "    *********************** 格式化 NameNode *************************    "
    "${HADOOP_HOME}/bin/hadoop" namenode -format > "${HADOOP_HOME}/logs/format.log" 2>&1
    grep -ni "formatted"  "${HADOOP_HOME}/logs/format.log"
    
    echo "    *********************** 启动 Hadoop 集群 *************************    "
    "${HADOOP_HOME}/sbin/start-all.sh"                                >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
    "${HADOOP_HOME}/sbin/mr-jobhistory-daemon.sh" start historyserver >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    sleep 20
    
    echo "    *********************** 测试 Hadoop 集群 *************************    "
    # 计算 pi 
    "${HADOOP_HOME}/bin/hadoop" jar "${HADOOP_HOME}/share/hadoop/mapreduce/hadoop-mapreduce-examples-${hadoop_version}.jar" pi 10 10 >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    grep -ni "Pi is"  "${ROOT_DIR}/logs/${LOG_FILE}"
    
    # 计算 wc 
    "${HADOOP_HOME}/bin/hadoop" fs -rm -r    /hadoop/test/wc/       >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1    
    "${HADOOP_HOME}/bin/hadoop" fs -mkdir -p /hadoop/test/wc/input
    "${HADOOP_HOME}/bin/hadoop" fs -put      "${HADOOP_HOME}/etc/hadoop/workers" /hadoop/test/wc/input
    "${HADOOP_HOME}/bin/hadoop" jar          "${HADOOP_HOME}/share/hadoop/mapreduce/hadoop-mapreduce-examples-${hadoop_version}.jar" \
                                             wordcount /hadoop/test/wc/input /hadoop/test/wc/output \
                                             >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    "${HADOOP_HOME}/bin/hadoop" fs -cat      /hadoop/test/wc/output/*
}


# 安装并初始化 Spark
function spark_install()
{
    echo "    ************************* 开始安装 Spark *************************    "
    local hadoop_version spark_version spark_src_url folder host_list host host_name password name
    
    JAVA_HOME=$(get_param "java.home")                                         # 获取 java   安装路径
    SCALA_HOME=$(get_param "scala.home")                                       # 获取 java   安装路径
    HADOOP_HOME=$(get_param "hadoop.home")                                     # 获取 Hadoop 安装路径
    SPARK_HOME=$(get_param "spark.home")                                       # 获取 Hadoop 安装路径
    
    hadoop_version=$(get_version "hadoop.url")
    spark_version=$(get_version "spark.nohadoop.url")
    
    echo "    ****************** 获取 Spark 的源码并应用补丁 *******************    "
    mkdir -p "${ROOT_DIR}/src"                                                 # 创建源码保存目录
    cd "${ROOT_DIR}/src" || exit                                               # 进入目录
    
    # 将 Spark 源码克隆到本地
    spark_src_url=$(get_param "spark.resource.url")                            # 获取 spark 源码路径
    if [ ! -e "${ROOT_DIR}/src/spark/.git" ]; then
        git clone    "${spark_src_url}"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
    fi 
    
    cd spark || exit                                                           # 进入 spark 源码路径
    { git checkout "v${spark_version}"; mvn clean; }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
    
    # 应用补丁，包含 commit 内容
    git am --ignore-space-change --ignore-whitespace "${ROOT_DIR}/patch/spark-${spark_version}.patch"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    # git am "${ROOT_DIR}/patch/spark-${spark_version}-hadoop-${hadoop_version}.patch"
    
    echo "    ************************ 编译 Spark-${spark_version} ************************    "
    rm -rf "${ROOT_DIR}/src/spark/spark-${spark_version}-bin-build.tgz"
    ./dev/make-distribution.sh --name build --tgz                               \
                               -Phive-3.1 -Phive-thriftserver -Phadoop-3.2      \
                               -Phadoop-provided -Pyarn -Pscala-2.12            \
                               "-Dhadoop.version=${hadoop_version}" -DskipTests \
                               >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    echo "    ************************* 解压安装 Spark *************************    "
    name=$(get_name "spark.url")
    cp -fpr "${ROOT_DIR}/src/spark/spark-${spark_version}-bin-build.tgz"  "${ROOT_DIR}/package/${name}"
    file_decompress "spark.url" "${SPARK_HOME}"
    
    echo "    *********************** 修改 Spark 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/conf/spark-env.sh"        "${SPARK_HOME}/conf/"
    cp -fpr "${ROOT_DIR}/conf/spark-defaults.conf" "${SPARK_HOME}/conf/"
    sed -i "s|\${JAVA_HOME}|${JAVA_HOME}|g"        "${SPARK_HOME}/conf/spark-env.sh"
    sed -i "s|\${SCALA_HOME}|${SCALA_HOME}|g"      "${SPARK_HOME}/conf/spark-env.sh"
    sed -i "s|\${HADOOP_HOME}|${HADOOP_HOME}|g"    "${SPARK_HOME}/conf/spark-env.sh"
    sed -i "s|\${SPARK_HOME}|${SPARK_HOME}|g"      "${SPARK_HOME}/conf/spark-env.sh"
    
    touch "${SPARK_HOME}/conf/workers"
    host_list=$(get_param "server.hosts" | tr ',' ' ')
    for host in ${host_list}
    do
        host_name=$(echo "${host}" | awk -F ':' '{print $2}')
        if [[ "${host_name}" =~ slave ]]; then
            append_param "${host_name}" "${SPARK_HOME}/conf/workers"
        fi
    done
    
    password=$(get_password)
    append_env "spark.home" "${spark_version}"                                 # 添加环境变量
    echo "${password}" | sudo -S sed -i "s|\${SPARK_HOME}\/bin$|\${SPARK_HOME}\/bin:\${SPARK_HOME}\/sbin|g" "/etc/profile.d/${USER}.sh"
    distribute_file "${SPARK_HOME}/"                                           # 将 Spark 目录同步到其它节点
    
    echo "    ******************** 上传 Spark 依赖 到 HDFS *********************    "
    file_decompress "spark.nohadoop.url"                                       # 解压不带 Hadoop 的Spark 包
    folder=$(ls -F | grep "/$")
    "${HADOOP_HOME}/bin/hadoop" fs -mkdir -p  /spark/jars /spark/logs /spark/history
    "${HADOOP_HOME}/bin/hadoop" fs -put   -f  "${ROOT_DIR}/package/${folder}jars"/* /spark/jars/
    
    echo "    ************************ 启动 Spark 集群 *************************    "
    cp -fpr "${ROOT_DIR}/script/apache/spark.sh"  "${SPARK_HOME}/bin/"         # 复制 Spark 脚本
     
    # 启动 Spark 集群和历史服务器
    { "${SPARK_HOME}/sbin/start-all.sh"; "${SPARK_HOME}/sbin/start-history-server.sh"; } >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1                            
    
    echo "    ******************* 测试 Spark Standalone 集群 *******************    "
    "${SPARK_HOME}/bin/spark-submit" --class org.apache.spark.examples.SparkPi \
                                     --master local[*]                         \
                                     "${SPARK_HOME}/examples/jars/spark-examples_2.12-${spark_version}.jar" 100 \
                                     >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    grep -ni "pi is roughly" "${ROOT_DIR}/logs/${LOG_FILE}"
    
    "${SPARK_HOME}/bin/spark-submit" --class org.apache.spark.examples.SparkPi \
                                     --master      spark://master:7077         \
                                     --deploy-mode cluster                     \
                                     "${SPARK_HOME}/examples/jars/spark-examples_2.12-${spark_version}.jar" 100 \
                                     >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    grep -ni "caused by" "${ROOT_DIR}/logs/${LOG_FILE}"
    
    echo "    ********************** 测试 Spark Yarn 集群 **********************    "
    "${SPARK_HOME}/bin/spark-submit" --class org.apache.spark.examples.SparkPi \
                                     --master          yarn                    \
                                     --deploy-mode     cluster                 \
                                     --driver-memory   1G                      \
                                     --executor-memory 1G                      \
                                     --num-executors   3                       \
                                     --executor-cores  2                       \
                                     "${SPARK_HOME}/examples/jars/spark-examples_2.12-${spark_version}.jar" 100 \
                                     >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    grep -ni "pi is roughly" "${ROOT_DIR}/logs/${LOG_FILE}"
    
    "${SPARK_HOME}/bin/spark-submit" --class org.apache.spark.examples.SparkPi \
                                     --master          yarn                    \
                                     --deploy-mode     client                  \
                                     --driver-memory   1G                      \
                                     --executor-memory 1G                      \
                                     --num-executors   3                       \
                                     --executor-cores  2                       \
                                     "${SPARK_HOME}/examples/jars/spark-examples_2.12-${spark_version}.jar" 100 \
                                     >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    grep -ni "caused by" "${ROOT_DIR}/logs/${LOG_FILE}"
}


# 安装并初始化 Flink
function flink_install()
{
    echo "    ************************* 开始安装 Flink *************************    "
    local cpu_thread namenode_host_port zookeeper_hosts flink_version master_list worker_list host host_list folder
    
    FLINK_HOME=$(get_param "flink.home")                                       # 获取 flink 安装路径
    file_decompress "flink.url" "${FLINK_HOME}"                                # 解压 flink 安装包
    
    # 创建必要的目录
    mkdir -p "${FLINK_HOME}/data/execute-tmp" "${FLINK_HOME}/data/web-tmp" "${FLINK_HOME}/logs" 
    
    echo "    ********************** 修改 Flink 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/script/apache/flink.sh"  "${FLINK_HOME}/bin"          # 复制启停脚本
    cp -fpr "${ROOT_DIR}/conf/flink-conf.yaml"    "${FLINK_HOME}/conf/"        # 复制配置文件
    
    JAVA_HOME=$(get_param "java.home")                                         # 获取 Java     安装目录
    HADOOP_HOME=$(get_param "hadoop.home")                                     # 获取 Hadoop   安装目录
    cpu_thread=$(get_cpu_thread)                                               # 获取 CPU      线程数
    namenode_host_port=$(get_param "namenode.host.port")                       # 获取 NameNode 地址
    zookeeper_hosts=$(get_param "zookeeper.hosts" | awk '{gsub(/,/,":2181/kafka,");print $0}')
    
    sed -i "s|\${JAVA_HOME}|${JAVA_HOME}|g"                    "${FLINK_HOME}/conf/flink-conf.yaml" 
    sed -i "s|\${HADOOP_HOME}|${HADOOP_HOME}|g"                "${FLINK_HOME}/conf/flink-conf.yaml" 
    sed -i "s|\${FLINK_HOME}|${FLINK_HOME}|g"                  "${FLINK_HOME}/conf/flink-conf.yaml" 
    sed -i "s|\${cpu_thread}|${cpu_thread}|g"                  "${FLINK_HOME}/conf/flink-conf.yaml" 
    sed -i "s|\${namenode_host_port}|${namenode_host_port}|g"  "${FLINK_HOME}/conf/flink-conf.yaml" 
    sed -i "s|\${zookeeper_hosts}|${zookeeper_hosts}|g"        "${FLINK_HOME}/conf/flink-conf.yaml" 
    
    master_list=$(get_param "flink.job.managers"  | tr ',' ' ')
    worker_list=$(get_param "flink.task.managers" | tr ',' ' ')
    
    # 修改 masters 
    cat /dev/null > "${FLINK_HOME}/conf/masters"
    for host in ${master_list}
    do
        append_param "${host}:8083" "${FLINK_HOME}/conf/masters"
    done
     
    # 修改 workers 
    cat /dev/null > "${FLINK_HOME}/conf/workers"
    for host in ${worker_list}
    do
        append_param "${host}" "${FLINK_HOME}/conf/workers"
    done
    
    flink_version=$(get_version "flink.url")                                   # 获取 Flink 的版本
    append_env "flink.home" "${flink_version}"                                 # 添加环境变量
    distribute_file "${FLINK_HOME}"                                            # 分发到其它节点
    
    echo "    ********************* 修改 TaskManager 参数 **********************    "
    host_list=$(get_param "flink.hosts" | tr ',' ' ')
    for host in ${host_list}
    do
         ssh "${USER}@${host}" "sed -i 's|\${task_host}|${host}|g' '${FLINK_HOME}/conf/flink-conf.yaml'" 
    done
    
    echo "    ************************ 上传依赖到 HDFS *************************    "
    # 在 HDFS 上创建必要的目录
    "${HADOOP_HOME}/bin/hadoop" fs -mkdir -p  /flink/check-point  /flink/save-point    /flink/completed  \
                                              /flink/history      /flink/ha            /flink/libs/lib   \
                                              /flink/libs/opt     /flink/libs/plugins  /flink/libs/custom     
    # 将依赖 jar 上传到 HDFS
    "${HADOOP_HOME}/bin/hadoop" fs -put -f  "${FLINK_HOME}"/lib/*.jar        /flink/libs/lib
    "${HADOOP_HOME}/bin/hadoop" fs -put -f  "${FLINK_HOME}"/opt/*.jar        /flink/libs/opt
    "${HADOOP_HOME}/bin/hadoop" fs -put -f  "${FLINK_HOME}"/plugins/*/*.jar  /flink/libs/plugins
    
    echo "    ************************ 启动 Flink 集群 *************************    "
    "${FLINK_HOME}/bin/start-cluster.sh"
    # "${FLINK_HOME}/bin/flink.sh" start
    
    echo "    ********************** 测试 Standalone 集群 **********************    "
    "${FLINK_HOME}/bin/flink" run "${FLINK_HOME}/examples/batch/WordCount.jar"      \
                                   --input  "hdfs://${namenode_host_port}/flink/test/wc/input"  \
                                   --output "hdfs://${namenode_host_port}/flink/test/wc/output"
    
    echo "    ************************* 测试 Yarn 集群 *************************    "
    
}


# 安装并初始化 Zookeeper
function zookeeper_install()
{
    echo "    *********************** 开始安装 Zookeeper ***********************    "
    local zookeeper_version host_list host id
    
    ZOOKEEPER_HOME=$(get_param "zookeeper.home")                               # 获取 Zookeeper 安装路径
    file_decompress "zookeeper.url" "${ZOOKEEPER_HOME}"                        # 解压 Zookeeper 安装包
    mkdir -p "${ZOOKEEPER_HOME}/data" "${ZOOKEEPER_HOME}/logs"                 # 创建必要的目录
    
    echo "    ******************** 修改 zookeeper 配置文件 *********************    "
    cp -fpr "${ROOT_DIR}/script/apache/zookeeper.sh"         "${ZOOKEEPER_HOME}/bin"               # 复制启停脚本
    cp -fpr "${ROOT_DIR}/conf/zookeeper-zoo.cfg"             "${ZOOKEEPER_HOME}/conf/zoo.cfg"      # 复制配置文件
    sed -i "s|\${ZOOKEEPER_HOME}|${ZOOKEEPER_HOME}|g"        "${ZOOKEEPER_HOME}/conf/zoo.cfg"      # 修改配置文件中的参数
    
    host_list=$(get_param "zookeeper.hosts" | tr ',' ' ')
    
    # 添加 Zookeeper 服务器唯一标识
    id=1
    for host in ${host_list}
    do
        append_param "server.${id}=${host}:2888:3888" "${ZOOKEEPER_HOME}/conf/zoo.cfg"
        id=$((id + 1))
    done
    
    zookeeper_version=$(get_version "zookeeper.url")                           # 获取 zookeeper 的版本
    append_env "zookeeper.home" "${zookeeper_version}"                         # 添加环境变量
    distribute_file "${ZOOKEEPER_HOME}"                                        # 分发到其它节点
    
    echo "    ******************** 修改 zookeeper 唯一标识 *********************    "
    id=1
    for host in ${host_list}
    do
        ssh "${USER}@${host}" "source ~/.bashrc; source /etc/profile; sed -i 's|${host}:2888:3888|0.0.0.0:2888:3888|g' '${ZOOKEEPER_HOME}/conf/zoo.cfg' "
        ssh "${USER}@${host}" "source ~/.bashrc; source /etc/profile; echo '${id}' > ${ZOOKEEPER_HOME}/data/myid"
        id=$((id + 1))
    done
    
    echo "    ********************** 启动 zookeeper 集群 ***********************    "
    "${ZOOKEEPER_HOME}/bin/zookeeper.sh" start
}


# 安装并初始化 Kafka
function kafka_install()
{
    echo "    ************************* 开始安装 Kafka *************************    "
    local kafka_version host_list host id kafka_zookeeper_node bootstrap_servers
    
    KAFKA_HOME=$(get_param "kafka.home")                                       # 获取 Kafka 安装路径
    file_decompress "kafka.url" "${KAFKA_HOME}"                                # 解压 Kafka 安装包
    mkdir -p "${KAFKA_HOME}/data" "${KAFKA_HOME}/logs"                         # 创建必要的目录
    
    echo "    ********************** 修改 kafka 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/script/apache/kafka.sh"       "${KAFKA_HOME}/bin/"                        # 复制启停脚本
    cp -fpr "${ROOT_DIR}/conf/kafka-server.properties" "${KAFKA_HOME}/config/server.properties"    # 复制配置文件
    
    # 修改 Producer 参数
    bootstrap_servers=$(get_param "kafka.hosts" | awk '{gsub(/,/,":9092,");print $0}')
    sed -i "s|bootstrap.servers=.*|bootstrap.servers=${bootstrap_servers}|g" "${KAFKA_HOME}/config/producer.properties"
    sed -i "s|compression.type=.*|compression.type=gzip|g"                   "${KAFKA_HOME}/config/producer.properties"
    
    # 修改配 Broker 置文件参数
    kafka_zookeeper_node=$(get_param "zookeeper.hosts" | awk '{gsub(/,/,":2181/kafka,");print $0}')
    sed -i "s|\${KAFKA_HOME}|${KAFKA_HOME}|g"                     "${KAFKA_HOME}/config/server.properties"
    sed -i "s|\${kafka_zookeeper_node}|${kafka_zookeeper_node}|g" "${KAFKA_HOME}/config/server.properties"
    
    # 修改 Consumer 参数
    sed -i "s|bootstrap.servers=.*|bootstrap.servers=${bootstrap_servers}|g" "${KAFKA_HOME}/config/consumer.properties"
    
    kafka_version=$(get_version "kafka.url")                                   # 获取 Kafka 的版本
    append_env "kafka.home" "${kafka_version}"                                 # 添加环境变量
    distribute_file "${KAFKA_HOME}"                                            # 分发到其它节点
    
    echo "    ********************** 修改 Kafka 唯一标识 ***********************    "
    host_list=$(get_param "kafka.hosts" | tr ',' ' ')
    id=1
    for host in ${host_list}
    do
        ssh "${USER}@${host}" "source ~/.bashrc; source /etc/profile; sed -i 's|\${id}|${id}|g' '${KAFKA_HOME}/config/server.properties'"
        id=$((id + 1))
    done
    
    echo "    ************************ 启动 Kafka 集群 *************************    "
    "${KAFKA_HOME}/bin/kafka.sh" start
}


# 安装并初始化 Hive
function hive_install()
{
    echo "    ************************* 开始安装 Hive **************************    "
    local hive_version hive_src_url server2_host_port hive_password hive_user metastore_host_port
    local namenode_host_port mysql_home mysql_user mysql_password root_password sql hive_sql
    
    JAVA_HOME=$(get_param "java.home")                                         # 获取 java   安装路径
    HADOOP_HOME=$(get_param "hadoop.home")                                     # 获取 Hadoop 安装路径
    HIVE_HOME=$(get_param "hive.home")                                         # 获取 Hive 安装路径
    
    echo "    ******************* 获取 Hive 的源码并应用补丁 *******************    "
    mkdir -p "${ROOT_DIR}/src"                                                 # 创建源码保存目录
    cd "${ROOT_DIR}/src" || exit                                               # 进入目录
    
    hive_version=$(get_version "hive.url")
    
    # 将 Spark 源码克隆到本地
    hive_src_url=$(read_param "hive.resource.url")                             # 获取 Hive 源码路径
    if [ ! -e "${ROOT_DIR}/src/spark/.git" ]; then
        git clone "${hive_src_url}"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
    fi 
    
    cd hive || exit                                                            # 进入 Hive 源码路径
    git checkout "rel/release-${hive_version}"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1                  # 切换到 需要的分支
    git am --ignore-space-change --ignore-whitespace "${ROOT_DIR}/patch/hive-${hive_version}.patch"  # 应用补丁
    
    echo "    *************************** 编译 Hive ****************************    "
    mvn clean -DskipTests package -Pdist >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1          # 编译 Hive
    
    # 复制 Hive 安装包
    cp -fpr "${ROOT_DIR}/src/hive/packaging/target/apache-hive-3.1.3-bin.tar.gz"  "${ROOT_DIR}/package/"        
    file_decompress "hive.url"  "${HIVE_HOME}"                                           # 解压 Hive 并安装
    
    echo "    *********************** 修改 Hive 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/conf/hive-beeline-site.xml"  "${HIVE_HOME}/conf/beeline-site.xml"
    cp -fpr "${ROOT_DIR}/conf/hive-site.xml"          "${HIVE_HOME}/conf/"
    
    # 修改 beeline-site.xml 配置
    server2_host_port=$(get_param "hive.server2.host.port")
    hive_user=$(get_param "hive.user")
    hive_password=$(get_param "hive.password")
    sed -i "s|\${server2_host_port}|${server2_host_port}|g" "${HIVE_HOME}/conf/beeline-site.xml"
    sed -i "s|\${hive_user}|${hive_user}|g"                 "${HIVE_HOME}/conf/beeline-site.xml"
    sed -i "s|\${hive_password}|${hive_password}|g"         "${HIVE_HOME}/conf/beeline-site.xml"
    
    # 修改 hive-site.xml 配置
    mysql_user=$(get_param "mysql.user.name")
    mysql_password=$(get_param "mysql.root.password")
    metastore_host_port=$(get_param "hive.metastore.host.port")
    namenode_host_port=$(get_param "namenode.host.port")
    sed -i "s|\${mysql_user}|${mysql_user}|g"                   "${HIVE_HOME}/conf/hive-site.xml"
    sed -i "s|\${mysql_password}|${mysql_password}|g"           "${HIVE_HOME}/conf/hive-site.xml"
    sed -i "s|\${metastore_host_port}|${metastore_host_port}|g" "${HIVE_HOME}/conf/hive-site.xml"
    sed -i "s|\${hive_user}|${hive_user}|g"                     "${HIVE_HOME}/conf/hive-site.xml"
    sed -i "s|\${hive_password}|${hive_password}|g"             "${HIVE_HOME}/conf/hive-site.xml"
    sed -i "s|\${namenode_host_port}|${namenode_host_port}|g"   "${HIVE_HOME}/conf/hive-site.xml"
    
    cp -fpr "${SPARK_HOME}/conf/spark-defaults.conf"  "${HIVE_HOME}/conf/"     # 用于 Hive on Spark
    cp -fpr "${HIVE_HOME}/conf/hive-site.xml"         "${SPARK_HOME}/conf/"    # 用于 Hive on Spark
    cp -fpr "${ROOT_DIR}/script/apache/hive.sh"       "${HIVE_HOME}/bin/"      # 用于 Hive 的启停
    
    # 添加 Hive 相关环境信息
    append_param "HADOOP_HEAPSIZE=4096"                "${HIVE_HOME}/conf/hive-env.sh"
    append_param "HADOOP_HOME=${HADOOP_HOME}"          "${HIVE_HOME}/conf/hive-env.sh"
    append_param "HIVE_CONF_DIR=${HIVE_HOME}/conf"     "${HIVE_HOME}/conf/hive-env.sh"
    append_param "HIVE_AUX_JARS_PATH=${HIVE_HOME}/lib" "${HIVE_HOME}/conf/hive-env.sh"
    
    mkdir -p "${HIVE_HOME}/logs/"                                              # 创建日志存储目录
    "${HADOOP_HOME}/bin/hadoop" fs -mkdir -p /hive/data /hive/tmp /hive/logs   # 在 hdfs 上创建必要的目录 
    "${HADOOP_HOME}/bin/hadoop" fs -chmod -R 777 /hive/                        # 授权目录
    
    append_env "hive.home" "${hive_version}"                                   # 添加环境变量
    distribute_file "${HIVE_HOME}/"                                            # 分发目录
    
    echo "    ************************** 初始化 Hive ***************************    "
    cp -fpr "${ROOT_DIR}/conf/mysql-connector-java-8.0.32.jar"  "${HIVE_HOME}/lib"
    
    mysql_home=$(get_param "mysql.home") 
    root_password=$(get_param "mysql.root.password")
    "${mysql_home}/bin/mysql.sh" start >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  # 启动 mysql
    "${mysql_home}/bin/mysql" -h 127.0.0.1 -P 3306 -u root -p"${root_password}" -e "create database if not exists hive; grant all privileges on hive.* to '${mysql_user}'@'%'; flush privileges;"
    
    "${HIVE_HOME}/bin/schematool" -dbType mysql -initSchema -verbose >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  # 初始化元数据
    
    # 修改字段注释字符集
    sql="${sql} alter table hive.columns_v2       modify column comment             varchar(2048)  character set utf8mb4;"
    sql="${sql} alter table hive.table_params     modify column param_value         varchar(4096)  character set utf8mb4;"
    sql="${sql} alter table hive.partition_params modify column param_value         varchar(4096)  character set utf8mb4;"
    sql="${sql} alter table hive.partition_keys   modify column pkey_comment        varchar(4096)  character set utf8mb4;"
    sql="${sql} alter table hive.index_params     modify column param_value         varchar(4096)  character set utf8mb4;"
    sql="${sql} alter table hive.tbls             modify column view_expanded_text  mediumtext     character set utf8mb4;"
    sql="${sql} alter table hive.tbls             modify column view_original_text  mediumtext     character set utf8mb4;"
    sql="${sql} flush privileges;"
    "${mysql_home}/bin/mysql" -h 127.0.0.1 -P 3306 -u "${mysql_user}" -p"${mysql_password}" -e "${sql}"
    
    echo "    *************************** 测试 Hive ****************************    "
    "${HIVE_HOME}/bin/hive.sh" start                                           # 启动 Hive
    "${HIVE_HOME}/bin/hive.sh" start
    
    hive_sql=" 
        create database if not exists test;                                    -- 创建 test 数据库
        use test;                                                              -- 切换到 test 数据库
        create table if not exists student                                     -- 创建 test 数据库
        (
            id     int           comment '主键 ID',
            name   varchar(64)   comment '姓名',
            age    int           comment '年龄',
            gender int           comment '性别：-1，未知；0，女；1：男',
            hight  float         comment '身高：厘米',
            wight  float         comment '体重：千克',
            email  varchar(128)  comment '电子邮件',
            remark varchar(1024) comment '备注'
        ) comment '学生测试表';
    
        set mapreduce.map.java.opts='-Xmx4096m';                               -- 设置 map 堆内存
        set mapreduce.reduce.java.opts='-Xms4096m';                            -- 设置 reduce 堆内存
        
        -- 测试 mr 引擎
        set hive.execution.engine=mr;
        insert into student (id, name, age, gender, hight, wight, email, remark) values (1, '张三', 33, 1, 172.1, 48.9, 'zhangsan@qq.com', '学生');
        
        -- 测试 spark 引擎
        set hive.execution.engine=spark;
        insert into student (id, name, age, gender, hight, wight, email, remark) values (2, '李四', 23, 0, 165.1, 53.9, 'lisi@qq.com', '学生');
        insert into student (id, name, age, gender, hight, wight, email, remark) 
        values (3, '王五', 28, 1, 168.3, 52.7, 'wangwu@qq.com', '学生'), 
               (4, '赵六', 22, 0, 161.3, 46.7, 'zhaoliu@qq.com', '教师');
        
        -- 测试执行计划
        explain formatted select * from student;
        select * from student limit 10;
    "
    "${HIVE_HOME}bin/hive" -e "${hive_sql}" >> "${HIVE_HOME}/logs/test.log" 2>&1 
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
    local namenode_host_port zookeeper_hosts hbase_version master_list worker_list host host_list
    
    HBASE_HOME=$(get_param "hbase.home")                                       # 获取 HBase 安装路径
    file_decompress "hbase.url" "${HBASE_HOME}"                                # 解压 HBase 安装包
    mkdir -p "${HBASE_HOME}/data" "${HBASE_HOME}/logs"                         # 创建必要的目录 
    
    echo "    ********************** 修改 HBase 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/script/apache/hbase.sh"  "${HBASE_HOME}/bin"          # 复制启停脚本
    cp -fpr "${ROOT_DIR}/conf/hbase-site.xml"     "${HBASE_HOME}/conf/"        # 复制配置文件

    JAVA_HOME=$(get_param "java.home")                                         # 获取 Java      安装目录
    HADOOP_HOME=$(get_param "hadoop.home")                                     # 获取 Hadoop    安装目录    
    ZOOKEEPER_HOME=$(get_param "zookeeper.home")                               # 获取 Zookeeper 安装目录    
    append_param "export JAVA_HOME=${JAVA_HOME}"           "${HBASE_HOME}/conf/hbase-env.sh"
    append_param "export HBASE_HEAPSIZE=4G"                "${HBASE_HOME}/conf/hbase-env.sh"
    append_param "export HBASE_LOG_DIR=${HBASE_HOME}/logs" "${HBASE_HOME}/conf/hbase-env.sh"
    append_param "export HBASE_PID_DIR=${HBASE_HOME}/data" "${HBASE_HOME}/conf/hbase-env.sh"
    append_param "export HBASE_MANAGES_ZK=false"           "${HBASE_HOME}/conf/hbase-env.sh"
    
    zookeeper_hosts=$(get_param "zookeeper.hosts")
    sed -i "s|\${namenode_host_port}|${namenode_host_port}|g" "${HBASE_HOME}/conf/hbase-site.xml"
    sed -i "s|\${zookeeper_hosts}|${zookeeper_hosts}|g"       "${HBASE_HOME}/conf/hbase-site.xml"
    sed -i "s|\${ZOOKEEPER_HOME}|${ZOOKEEPER_HOME}|g"         "${HBASE_HOME}/conf/hbase-site.xml"
    
        
    hbase_version=$(get_version "hbase.url")                                   # 获取 zookeeper 的版本
    append_env "hbase.home" "${hbase_version}"                                 # 添加环境变量
    distribute_file "${HBASE_HOME}"                                            # 分发到其它节点
    
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
    local flume_version number count
    
    FLUME_HOME=$(get_param "flume.home")                                       # 获取 Flume 安装路径
    file_decompress "flume.url" "${FLUME_HOME}"                                # 解压 Flume 安装包
    mkdir -p "${FLUME_HOME}/logs"                                              # 创建必要的目录
    
    echo "    ********************** 修改 Flume 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/conf/flume-file-console.properties"  "${FLUME_HOME}/conf/"
    sed -i "s|\${FLUME_HOME}|${FLUME_HOME}|g"                 "${FLUME_HOME}/conf/file-console.properties"
    
    touch "${FLUME_HOME}/conf/flume-env.sh"
    append_param "export JAVA_HOME=${JAVA_HOME}"                                          "${FLUME_HOME}/conf/flume-env.sh"
    append_param "export JAVA_OPTS=\"-Xms256m -Xmx512m -Dcom.sun.management.jmxremote\""  "${FLUME_HOME}/conf/flume-env.sh"
    sed -i "s|^JAVA_OPTS=.*|JAVA_OPTS=\"-Xms256m -Xmx512m\"|g"                            "${FLUME_HOME}/bin/flume-ng"
    sed -i "s|>.<|>${FLUME_HOME}/logs<|g"                                                 "${FLUME_HOME}/conf/log4j2.xml"
    
    echo "    ****************** 解决 Flume 与 Hadoop 兼容性 *******************    "
    # 删除 flume 旧版本的 guava，和 hadoop 保持一致
    rm "${FLUME_HOME}/lib/guava-11.0.2.jar"
    cp -fpr "${HADOOP_HOME}/share/hadoop/common/lib/guava-27.0-jre.jar" "${FLUME_HOME}/lib/" 
    cp -fpr "${HADOOP_HOME}/etc/hadoop/core-site.xml"      "${FLUME_HOME}/conf/"
    cp -fpr "${HADOOP_HOME}/etc/hadoop/hdfs-site.xml"      "${FLUME_HOME}/conf/"
    
    flume_version=$(get_version "flume.url")                                   # 获取 Kafka 的版本
    append_env "flume.home" "${flume_version}"                                 # 添加环境变量
    distribute_file "${FLUME_HOME}"                                            # 分发到其它节点
    
    echo "    *************************** 测试 Flume ***************************    "
    touch "${FLUME_HOME}/logs/file-console.log"
    nohup "${FLUME_HOME}/bin/flume-ng" agent -c conf                                         \
                                             -f "${FLUME_HOME}/conf/file-console.properties" \
                                             -n a1 -Dflume.root.logger=INFO,console          \
                                             > /dev/null 2>&1 &
    number=10
    while [[ "${number}" -gt 0 ]] 
    do
        echo "Test whether the software is working"  >> "${FLUME_HOME}/logs/file-console.log"
        number=$((number - 1))
    done
    
    sleep 1
    ps -aux | grep -i "${USER}" | grep -i "${FLUME_HOME}/conf/file-console.properties" | grep -viE "grep|$0" | awk '{print $2}'  | xargs kill
    sleep 1
    
    count=$(grep -cin "Test whether the software is working" "${FLUME_HOME}/logs/file-console.log")
    
    if [[ ${count} -eq 10 ]]; then
        echo "    ************************* Flume 测试完成 *************************    "
    else
        echo "    ************************* Flume 测试失败 *************************    "
    fi
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
        echo "    脚本可传入一个参数，如下所示：             "
        echo "        +----------+-------------------------+ "
        echo "        |  参  数  |         描   述         | "
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
