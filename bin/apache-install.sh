#!/usr/bin/env bash
# shellcheck disable=SC2029,SC2120

# =========================================================================================
#    FileName      ：  apache-install
#    CreateTime    ：  2023-07-11 14:59:51
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  安装数据库相关软件：apache 相关大数据组件
# =========================================================================================


SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="apache-install-$(date +%F).log"                                      # 程序操作日志文件
USER=$(whoami)                                                                 # 当前登录使用的用户
JAVA_HOME="/opt/java/jdk"                                                      # Java      默认安装路径  
SCALA_HOME="/opt/java/scala"                                                   # Scala     默认安装路径  
HADOOP_HOME="/opt/apache/hadoop"                                               # Hadoop    默认安装路径 
SPARK_HOME="/opt/apache/spark"                                                 # Spark     默认安装路径 
FLINK_HOME="/opt/apache/flink"                                                 # Flink     默认安装路径 
ZOOKEEPER_HOME="/opt/apache/zookeeper"                                         # Zookeeper 默认安装路径 
KAFKA_HOME="/opt/apache/kafka"                                                 # Kafka     默认安装路径 
HIVE_HOME="/opt/apache/hive"                                                   # Hive      默认安装路径 
DORIS_HOME="/opt/apache/doris"                                                 # Doris     默认安装路径 
FLUME_HOME="/opt/apache/flume"                                                 # Flume     默认安装路径 
HBASE_HOME="/opt/apache/hbase"                                                 # HBase     默认安装路径 
PHOENIX_HOME="/opt/apache/phoenix"                                             # Phoenix   默认安装路径 


# 刷新环境变量
function flush_env()
{
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    
    echo "    ************************** 刷新环境变量 **************************    "
    if [ -e "${HOME}/.bash_profile" ]; then
        source "${HOME}/.bash_profile"
    elif [ -e "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"
    fi
    
    source "/etc/profile"
    
    echo "    ************************** 获取公共函数 **************************    "
    # shellcheck source=./common.sh
    source "${ROOT_DIR}/bin/common.sh"
    
    export -A PARAM_LIST=()
    read_param "${ROOT_DIR}/conf/${CONFIG_FILE}"
}


# 离线安装 maven jar （$1：jar 文件名，$2：Maven 坐标 GroupId 值，$3：Maven 坐标 ArtifactId 值，$4：Maven 坐标 Version 值）
function maven_jar_install()
{
    local file_name 
    
    file_name=$(echo "$1" | awk -F '--' '{print $NF}')                         # 切割文件名
    cp -fpr  "${ROOT_DIR}/lib/$1" "${ROOT_DIR}/package/${file_name}"           # 复制到指定路径
    echo "====================> $file_name"
    mvn install:install-file -DgroupId="$2"                             \
                             -DartifactId="$3"                          \
                             -Dversion="$4"                             \
                             -Dpackaging=jar                            \
                             -Dfile="${ROOT_DIR}/package/${file_name}"  \
                             >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    echo "    jar：${file_name} 安装完成 ...... "
}


# 安装并初始化 Hadoop
function hadoop_install()
{
    echo "    ************************ 开始安装 Hadoop *************************    "
    local host_list user hadoop_version password host host_name zookeeper_host_port namenode_host_port 
    local history_hosts resource_manager_hosts cpu_thread
    
    JAVA_HOME=$(get_param "java.home")                                     # 获取 java   安装路径
    HADOOP_HOME=$(get_param "hadoop.home")                                 # 获取 Hadoop 安装路径
    file_decompress "hadoop.url" "${HADOOP_HOME}"                          # 解压 Hadoop 安装包
    
    echo "    ********************* 修改 Hadoop 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/script/apache/hadoop.sh"     "${HADOOP_HOME}/bin/"
    
    cp -fpr "${ROOT_DIR}/conf/hadoop-core-site.xml"   "${HADOOP_HOME}/etc/hadoop/core-site.xml"
    cp -fpr "${ROOT_DIR}/conf/hadoop-hdfs-site.xml"   "${HADOOP_HOME}/etc/hadoop/hdfs-site.xml"
    cp -fpr "${ROOT_DIR}/conf/hadoop-mapred-site.xml" "${HADOOP_HOME}/etc/hadoop/mapred-site.xml"
    cp -fpr "${ROOT_DIR}/conf/hadoop-yarn-site.xml"   "${HADOOP_HOME}/etc/hadoop/yarn-site.xml"
    
    namenode_host_port=$(get_param "namenode.host.port")                       # NameNode Web UI 主机和端口号
    zookeeper_host_port=$(get_param "zookeeper.hosts" | awk '{gsub(/,/,":2181/kafka,");print $0}')
    cpu_thread=$(get_cpu_thread)                                               # 获取 CPU 线程数
    history_hosts=$(get_param "hadoop.history.hosts")                          # 历史服务器所在的节点
    resource_manager_hosts=$(get_param "hadoop.yarn.resource.manager.hosts")   # Yarn ResourceManager 所在的节点
    
    sed -i "s|# export JAVA_HOME=|export JAVA_HOME=${JAVA_HOME}|g"        "${HADOOP_HOME}"/etc/hadoop/*-env.sh
    sed -i "s|# export HADOOP_HOME=|export HADOOP_HOME=${HADOOP_HOME}|g"  "${HADOOP_HOME}"/etc/hadoop/*-env.sh
    sed -i "s|\${HADOOP_HOME}|${HADOOP_HOME}|g"                           "${HADOOP_HOME}"/etc/hadoop/*-site.xml
    sed -i "s|\${zookeeper_host_port}|${zookeeper_host_port}|g"           "${HADOOP_HOME}"/etc/hadoop/*-site.xml
    sed -i "s|\${namenode_host_port}|${namenode_host_port}|g"             "${HADOOP_HOME}"/etc/hadoop/*-site.xml
    sed -i "s|\${cpu_thread}|${cpu_thread}|g"                             "${HADOOP_HOME}"/etc/hadoop/*-site.xml
    sed -i "s|\${hadoop_history_hosts}|${history_hosts}|g"                "${HADOOP_HOME}"/etc/hadoop/*-site.xml
    sed -i "s|\${resource_manager_hosts}|${resource_manager_hosts}|g"     "${HADOOP_HOME}"/etc/hadoop/*-site.xml
    
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
    local hadoop_version spark_version spark_src_url folder host_list host host_name password name master_hosts namenode_host_port
    
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
    git apply --ignore-space-change --ignore-whitespace "${ROOT_DIR}/patch/spark-${spark_version}-hadoop-${hadoop_version}.patch"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    # git am "${ROOT_DIR}/patch/spark-${spark_version}-hadoop-${hadoop_version}.patch"
    
    echo "    ************************ 编译 Spark-${spark_version} ************************    "
    rm -rf "${ROOT_DIR}/src/spark/spark-${spark_version}-bin-build.tgz"
    
    source /etc/profile                                                        # 生效当前环境变量
    "${ROOT_DIR}/src/spark/dev/make-distribution.sh" --name build --tgz                               \
                                                     -Phive-3.1 -Phive-thriftserver -Phadoop-3.2      \
                                                     -Phadoop-provided -Pyarn -Pscala-2.12            \
                                                     "-Dhadoop.version=${hadoop_version}" -DskipTests \
                                                     >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    echo "    ************************* 解压安装 Spark *************************    "
    name=$(get_name "spark.url")
    cp -fpr "${ROOT_DIR}/src/spark/spark-${spark_version}-bin-build.tgz"  "${ROOT_DIR}/package/${name}"
    file_decompress "spark.url" "${SPARK_HOME}"
    
    echo "    *********************** 修改 Spark 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/conf/spark-env.sh"                    "${SPARK_HOME}/conf/"
    cp -fpr "${ROOT_DIR}/conf/spark-defaults.conf"             "${SPARK_HOME}/conf/"
    
    master_hosts=$(get_param "spark.master.hosts")
    namenode_host_port=$(get_param "namenode.host.port")
    sed -i "s|\${JAVA_HOME}|${JAVA_HOME}|g"                    "${SPARK_HOME}/conf/spark-env.sh"
    sed -i "s|\${SCALA_HOME}|${SCALA_HOME}|g"                  "${SPARK_HOME}/conf/spark-env.sh"
    sed -i "s|\${HADOOP_HOME}|${HADOOP_HOME}|g"                "${SPARK_HOME}/conf/spark-env.sh"
    sed -i "s|\${SPARK_HOME}|${SPARK_HOME}|g"                  "${SPARK_HOME}/conf/spark-env.sh"
    sed -i "s|\${spark_master_hosts}|${master_hosts}|g"        "${SPARK_HOME}/conf/spark-env.sh"
    sed -i "s|\${namenode_host_port}|${namenode_host_port}|g"  "${SPARK_HOME}/conf/spark-env.sh"
    sed -i "s|\${namenode_host_port}|${namenode_host_port}|g"  "${SPARK_HOME}/conf/spark-defaults.conf"
    
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
    local cpu_thread namenode_host_port zookeeper_hosts flink_version master_list worker_list host host_list history_list
    
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
    history_list=$(get_param "flink.history.hosts" | tr ',' ' ')
    sed -i "s|\${master_list}|${master_list}|g"    "${FLINK_HOME}/bin/flink.sh"
    sed -i "s|\${worker_list}|${worker_list}|g"    "${FLINK_HOME}/bin/flink.sh"
    sed -i "s|\${history_list}|${history_list}|g"  "${FLINK_HOME}/bin/flink.sh"
    
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
         ssh "${USER}@${host}" "source ~/.bashrc; source /etc/profile; sed -i 's|\${task_host}|${host}|g' '${FLINK_HOME}/conf/flink-conf.yaml'" 
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
    "${FLINK_HOME}/bin/start-cluster.sh"        >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    "${FLINK_HOME}/bin/historyserver.sh" start  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
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
    kafka_zookeeper_node=$(get_param "zookeeper.hosts" | sed -e 's|$|,|g' | awk '{gsub(/,/,":2181/kafka,");print $0}' | sed -e 's|,$||g' )
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
    local spark_version hive_version hive_src_url server2_host_port hive_password hive_user metastore_host_port
    local namenode_host_port mysql_host mysql_port mysql_home mysql_user mysql_password root_password hive_mysql_host
    local test_result
    
    JAVA_HOME=$(get_param "java.home")                                         # 获取 java   安装路径
    HADOOP_HOME=$(get_param "hadoop.home")                                     # 获取 Hadoop 安装路径
    HIVE_HOME=$(get_param "hive.home")                                         # 获取 Hive 安装路径
    
    echo "    ******************* 获取 Hive 的源码并应用补丁 *******************    "
    mkdir -p "${ROOT_DIR}/src"                                                 # 创建源码保存目录
    cd "${ROOT_DIR}/src" || exit                                               # 进入目录
    
    # 将 Spark 源码克隆到本地
    hive_src_url=$(get_param "hive.resource.url")                              # 获取 Hive 源码路径
    if [ ! -e "${ROOT_DIR}/src/spark/.git" ]; then
        git clone "${hive_src_url}"   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   # 克隆代码到本地
    fi 
    
    cd "${ROOT_DIR}/src/hive" || exit                                          # 进入 Hive 源码路径
    spark_version=$(get_version "spark.nohadoop.url")                          # 获取 Spark 版本
    
    # 更新代码
    hive_version=$(get_version "hive.url")                                     # 获取 Hive 版本号
    { 
        git fetch --all                                                        # 重置所有本地更改 
        git reset --hard                                                       # 强制重置所有本地提交 
        git pull                                                               # 将代码与远端保持一致
        sleep 3                                                                
        git checkout "rel/release-${hive_version}"                             # 检出 特定版本的 Hive 分支
        git fetch --all                                                        # 重置所有本地更改
        git reset --hard                                                       # 强制重置所有本地提交 
    }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    # 复制缺失的代码，应用 git 补丁
    cp -fpr   "${ROOT_DIR}/patch/ColumnsStatsUtils.java" "${ROOT_DIR}/src/hive/standalone-metastore/src/main/java/org/apache/hadoop/hive/metastore/columnstats/"
    git apply --ignore-space-change --ignore-whitespace  "${ROOT_DIR}/patch/hive-${hive_version}-spark-${spark_version}.patch" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   
    
    echo "    ************************** 离线安装依赖 **************************    "
    source /etc/profile                                                        # 生效当前环境变量
    maven_jar_install "pentaho-aggdesigner--pentaho-aggdesigner-algorithm-5.1.5-jhyde.jar"           "org.pentaho" "pentaho-aggdesigner"           "5.1.5-jhyde"
    maven_jar_install "pentaho-aggdesigner-algorithm--pentaho-aggdesigner-algorithm-5.1.5-jhyde.jar" "org.pentaho" "pentaho-aggdesigner-algorithm" "5.1.5-jhyde"
    
    echo "    *************************** 编译 Hive ****************************    "
    mvn clean -DskipTests package -Pdist >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1          # 编译 Hive
    
    # 复制 Hive 安装包
    cp -fpr "${ROOT_DIR}/src/hive/packaging/target/apache-hive-${hive_version}-bin.tar.gz"  "${ROOT_DIR}/package/"        
    file_decompress "hive.url"  "${HIVE_HOME}"                                 # 解压 Hive 并安装
    
    echo "    *********************** 修改 Hive 配置文件 ***********************    "
    # 复制配置文件和启停脚本
    cp -fpr "${ROOT_DIR}/script/apache/hive.sh"       "${HIVE_HOME}/bin/"      # 用于 Hive 的启停
    cp -fpr "${ROOT_DIR}/conf/hive-beeline-site.xml"  "${HIVE_HOME}/conf/beeline-site.xml"
    cp -fpr "${ROOT_DIR}/conf/hive-site.xml"          "${HIVE_HOME}/conf/"     # Hive 主要配置文件
    cp -fpr "${SPARK_HOME}/conf/spark-defaults.conf"  "${HIVE_HOME}/conf/"     # 用于 Hive on Spark
    
    # 修改 beeline-site.xml 配置
    server2_host_port=$(get_param "hive.server2.host.port")                    # Hive server2 的节点和端口
    hive_user=$(get_param "hive.user")                                         # Hive 使用的用户名
    hive_password=$(get_param "hive.password")                                 # Hive 使用用户名的密码
    sed -i "s|\${server2_host_port}|${server2_host_port}|g" "${HIVE_HOME}/conf/beeline-site.xml"
    sed -i "s|\${hive_user}|${hive_user}|g"                 "${HIVE_HOME}/conf/beeline-site.xml"
    sed -i "s|\${hive_password}|${hive_password}|g"         "${HIVE_HOME}/conf/beeline-site.xml"
    
    # 修改 hive-site.xml 配置
    hive_mysql_host=$(get_param "hive.mysql.host.port")                        # Hive 使用的 Mysql 主机名和端口号
    mysql_user=$(get_param "mysql.user.name")                                  # Hive 使用的 Mysql 用户名
    mysql_password=$(get_param "mysql.root.password")                          # Hive 使用的 Mysql 用户密码
    metastore_host_port=$(get_param "hive.metastore.host.port")                # MetaStore 主机和端口
    namenode_host_port=$(get_param "namenode.host.port")                       # NameNode  主机和端口
    sed -i "s|\${hive_mysql_host}|${hive_mysql_host}|g"         "${HIVE_HOME}/conf/hive-site.xml"
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
    touch "${HIVE_HOME}/conf/hive-env.sh"
    append_param "HADOOP_HEAPSIZE=4096"                "${HIVE_HOME}/conf/hive-env.sh"
    append_param "HADOOP_HOME=${HADOOP_HOME}"          "${HIVE_HOME}/conf/hive-env.sh"
    append_param "HIVE_CONF_DIR=${HIVE_HOME}/conf"     "${HIVE_HOME}/conf/hive-env.sh"
    append_param "HIVE_AUX_JARS_PATH=${HIVE_HOME}/lib" "${HIVE_HOME}/conf/hive-env.sh"
    
    # 创建必要的目录
    mkdir -p "${HIVE_HOME}/logs/"                                              # 创建日志存储目录
    "${HADOOP_HOME}/bin/hadoop" fs -mkdir -p /hive/data /hive/tmp /hive/logs   # 在 hdfs 上创建必要的目录 
    "${HADOOP_HOME}/bin/hadoop" fs -chmod -R 777 /hive/                        # 授权目录
    
    append_env "hive.home" "${hive_version}"                                   # 添加环境变量
    distribute_file "${HIVE_HOME}/"                                            # 分发目录
    
    echo "    ************************** 初始化 Hive ***************************    "
    cp -fpr "${ROOT_DIR}/lib/mysql-connector-java-8.0.32.jar"  "${HIVE_HOME}/lib"
    
    mysql_home=$(get_param "mysql.home")                                       # 获取 Mysql 安装路径
    root_password=$(get_param "mysql.root.password")                           # 获取 Mysql root 账户密码
    
    # 启动 Mysql 并创建必要的数据库
    mysql_host=$(echo "${hive_mysql_host}" | awk -F ':' "{print $1}")
    mysql_port=$(echo "${hive_mysql_host}" | awk -F ':' "{print $2}")
    "${mysql_home}/support-files/mysql.server" start  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
    "${mysql_home}/bin/mysql" --host="${mysql_host}" --port="${mysql_port}" --user=root --password="${root_password}" \
                              --execute="create database if not exists hive; grant all privileges on hive.* to '${mysql_user}'@'%'; flush privileges;"
    
    # 初始化元数据
    "${HIVE_HOME}/bin/schematool" -dbType mysql -initSchema -verbose >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  
    
    # 修改字段注释字符集
    "${mysql_home}/bin/mysql" --host="${mysql_host}" --port="${mysql_port}" --user="${mysql_user}" --password="${mysql_password}" \
                              < "${ROOT_DIR}/conf/hive-character.sql"  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    echo "    *************************** 测试 Hive ****************************    "
    "${HIVE_HOME}/bin/hive.sh" start                                           # 启动 Hive
    
    # 打印测试 sql
    {    
        echo "create database if not exists test;                                   -- 创建 test 数据库"
        echo ""
        echo "create table if not exists test.test                                  -- 创建 test 表"
        echo "( "
        echo "    id     int           comment '主键 ID', "
        echo "    name   varchar(64)   comment '姓名', "
        echo "    age    int           comment '年龄', "
        echo "    gender int           comment '性别：-1，未知；0，女；1：男', "
        echo "    hight  float         comment '身高：厘米', "
        echo "    wight  float         comment '体重：千克', "
        echo "    email  varchar(128)  comment '电子邮件', "
        echo "    remark varchar(1024) comment '备注' "
        echo ") comment '学生测试表'; "
        echo ""
        echo "set mapreduce.map.java.opts='-Xmx4096m';                              -- 设置 map 堆内存"
        echo "set mapreduce.reduce.java.opts='-Xms4096m';                           -- 设置 reduce 堆内存"
        echo ""
        echo "set hive.execution.engine=mr;                                         -- 设置 MR 引擎"
        echo "insert into test.test (id, name, age, gender, hight, wight, email, remark) values (1, '张三', 33, 1, 172.1, 48.9, 'zhangsan@qq.com', '学生');"
        echo ""
        echo "set hive.execution.engine=spark;                                      -- 设置 Spark 引擎"
        echo "insert into test.test (id, name, age, gender, hight, wight, email, remark) values (2, '李四', 23, 0, 165.1, 53.9, 'lisi@qq.com', '学生');"
        echo ""
        echo "insert into test.test (id, name, age, gender, hight, wight, email, remark) values (3, '王五', 28, 1, 168.3, 52.7, 'wangwu@qq.com', '学生');"
        echo ""
        echo "explain formatted select * from student;                              -- 测试执行计划"
        echo ""
        echo "select * from test.test limit 10;"
    }  > "${HIVE_HOME}/logs/test.sql"
    
    "${HIVE_HOME}/bin/hive" -f "${HIVE_HOME}/logs/test.sql" >> "${HIVE_HOME}/logs/test.log" 2>&1 
    
    test_result=$(grep -nic "王五" "${HIVE_HOME}/logs/test.log")
    if [[ ${test_result} -eq 1 ]]; then
        echo "    **************************** 测试成功 ****************************    "
    else    
        echo "    **************************** 测试失败 ****************************    "
    fi
}


# 安装并初始化 HBase
function hbase_install()
{
    echo "    ************************* 开始安装 HBase *************************    "
    local namenode_host_port zookeeper_hosts hbase_version region_list region backup_list backup fail_count
    
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
    
    # zookeeper 集群
    zookeeper_hosts=$(get_param "zookeeper.hosts" | sed -e 's|$|,|g' | awk '{gsub(/,/,":2181,");print $0}' | sed -e 's|,$||g' ) 
    region_list=$(get_param "hbase.hregion.hosts" | tr ',' ' ')                # 获取 region 节点
    backup_list=$(get_param "hbase.backup.host"   | tr ',' ' ')                # 获取 backup 备份节点
    namenode_host_port=$(get_param "namenode.host.port")                       # 获取 NameNode 地址
    sed -i "s|\${namenode_host_port}|${namenode_host_port}|g"       "${HBASE_HOME}/conf/hbase-site.xml"
    sed -i "s|\${zookeeper_hosts}|${zookeeper_hosts}|g"             "${HBASE_HOME}/conf/hbase-site.xml"
    sed -i "s|\${ZOOKEEPER_HOME}|${ZOOKEEPER_HOME}|g"               "${HBASE_HOME}/conf/hbase-site.xml"
    sed -i "s|hbase.log.dir=.*|hbase.log.dir=${HBASE_HOME}/logs|g"  "${HBASE_HOME}/conf/log4j.properties"
    
    # 修改修改 RegionServer 节点配置
    cat /dev/null > "${HBASE_HOME}/conf/regionservers" 
    for region in ${region_list}
    do 
        append_param "${region}"  "${HBASE_HOME}/conf/regionservers"
    done    
    
    # 修改修改 HMaster Backup 节点配置
    cat /dev/null > "${HBASE_HOME}/conf/backup-masters"
    if [ -z "${backup_list}" ]; then
        for backup in $(echo "${backup_list}" | tr ',' ' ')
        do
            append_param "${backup}"  "${HBASE_HOME}/conf/backup-masters"
        done    
    fi
    
    echo "    *********************** 解决与 Hadoop 依赖 ***********************    "
    rm -rf   "${HBASE_HOME}/lib/guava-11.0.2.jar"                               # 删除 hbase 旧版本的 guava
    cp -fpr  "${HADOOP_HOME}/share/hadoop/common/lib/guava-27.0-jre.jar" "${HBASE_HOME}/lib/"      # 和 hadoop 保持一致
    cp -fpr  "${HADOOP_HOME}/etc/hadoop/core-site.xml"                   "${HBASE_HOME}/conf/"     # 获取 NameNode 配置
    cp -fpr  "${HADOOP_HOME}/etc/hadoop/hdfs-site.xml"                   "${HBASE_HOME}/conf/"     # 获取 HDFS     配置
    
    hbase_version=$(get_version "hbase.url")                                   # 获取 HBase 的版本
    append_env "hbase.home" "${hbase_version}"                                 # 添加环境变量
    distribute_file "${HBASE_HOME}"                                            # 分发到其它节点
    
    echo "    **************************** 启动集群 ****************************    "
    "${HBASE_HOME}/bin/start-hbase.sh" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  # 启动集群的 HMaster 和所有的 HRegionServer
    "${HBASE_HOME}/bin/hbase.sh" status                                        # 查看集群信息
    
    echo "    **************************** 测试集群 ****************************    "    
    { 
        echo "create_namespace 'test'"
        echo "list_namespace"
        echo "create 'test:test', 'info', 'address'"
        echo "list_namespace_tables 'test'"
        echo "put 'test:test','1','info:age','22'"
        echo "put 'test:test','1','info:name','zhao'"
        echo "put 'test:test','1','info:class','2'"
        echo "put 'test:test','1','address:city','shanghai'"
        echo "put 'test:test','1','address:area','pudong'"
        echo "put 'test:test','2','info:age','21'"
        echo "put 'test:test','2','info:name','yang'"
        echo "put 'test:test','2','info:class','1'"    
        echo "put 'test:test','2','address:city','beijing'"
        echo "put 'test:test','2','address:area','CBD'"
        echo "scan 'test:test'"
        echo "exit" 
    } > "${HBASE_HOME}/data/test.txt" 
    
    "${HBASE_HOME}/bin/hbase" shell "${HBASE_HOME}/data/test.txt" > "${HBASE_HOME}/logs/test.log" 2>&1
    
    fail_count=$(grep -nic "ERROR:" "${PHOENIX_HOME}/logs/test.log")
    if [[ "${fail_count}" -eq 0 ]]; then
        echo "    *************************** 测试成功 *****************************    "
    else
        echo "    *************************** 测试失败 *****************************    "
    fi
}


# 安装并初始化 Phoenix
function phoenix_install()
{
    echo "    ************************ 开始安装 Phoenix ************************    "
    local hbase_version phoenix_version zookeeper_hosts sql_count success_count fail_count
    
    PHOENIX_HOME=$(get_param "phoenix.home")                                   # 获取 Phoenix 安装路径
    file_decompress "phoenix.url" "${PHOENIX_HOME}"                            # 解压 Phoenix 安装包
    
    echo "    ********************* 修改 Phoenix 配置文件 **********************    "
    HBASE_HOME=$(get_param "hbase.home")                                       # 获取 HBase   安装路径
    hbase_version=$(get_version "hbase.url")                                   # 获取 HBase   的版本
    phoenix_version=$(get_version "phoenix.url")                               # 获取 Phoenix 的版本
    
    cp -fpr  "${HBASE_HOME}/conf/hbase-site.xml"       "${PHOENIX_HOME}/bin/"  # 复制 HBase 配置文件到 Phoenix 
    cp -fpr  "${HADOOP_HOME}/etc/hadoop/core-site.xml" "${PHOENIX_HOME}/bin/"  # 复制 Hadoop 的 core 配置文件到 Phoenix 
    cp -fpr  "${HADOOP_HOME}/etc/hadoop/hdfs-site.xml" "${PHOENIX_HOME}/bin/"  # 复制 Hadoop 的 hdfs 配置文件到 Phoenix    
    
    cp -fpr  "${PHOENIX_HOME}"/phoenix-server-hbase-*-"${phoenix_version}".jar "${HBASE_HOME}/lib/"          # 复制 驱动
    mkdir -p "${PHOENIX_HOME}/logs"
            
    echo "    *********************** 分发 Phoenix 目录 ************************    "        
    append_env "phoenix.home" "${phoenix_version}"                                 # 添加环境变量
    distribute_file "${PHOENIX_HOME}"                                            # 分发到其它节点
    
    echo "    ************************* 测试 Phoenix  **************************    "    
    { 
        echo "create schema if not exists test;"
        echo "use test;"
        echo "create table if not exists student ( id bigint primary key, name varchar(64), age bigint, gender bigint );"
        echo "upsert into student (id, name, age, gender) values(1001, '张三', 25, 0);"
        echo "upsert into student (id, name, age, gender) values(1002, '李四', 36, 1);"
        echo "select * from student;"
        echo "upsert into student (id, name, age, gender) values(1001, '王五', 27, 1);"
        echo "select * from student;"
        echo "delete from student where id = 1001;"
        echo "select * from student;"
        echo "select * from system.catalog;"
        echo "!exit"
    } > "${PHOENIX_HOME}/logs/test.sql" 
    
    zookeeper_hosts=$(get_param "zookeeper.hosts" | sed -e 's|$|:2181|g' )
    "${PHOENIX_HOME}/bin/sqlline.py"  "${zookeeper_hosts}" "${PHOENIX_HOME}/logs/test.sql" > "${PHOENIX_HOME}/logs/test.log" 2>&1
    
    sql_count=$(wc -l "${PHOENIX_HOME}/logs/test.sql" | awk '{print $1}')
    success_count=$(grep -nic "${sql_count}/${sql_count}" "${PHOENIX_HOME}/logs/test.log")
    fail_count=$(grep -nic "command failed" "${PHOENIX_HOME}/logs/test.log")
    if [[ "${fail_count}" -eq 0 ]] && [[ "${success_count}" -eq 1 ]]; then
        echo "    *************************** 测试成功 *****************************    "
    else
        echo "    *************************** 测试失败 *****************************    "
    fi
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


# 安装并初始化 Doris
function doris_install()
{
    echo "    ************************* 开始安装 Doris *************************    "
    local doris_version priority_networks fe_list be_list host broker_list observer_list broker_list
    local leader_host doris_set_sql fe_count be_count broker_count
    local MYSQL_HOME doris_user doris_password doris_database_list db doris_root_password test_result
    
    DORIS_HOME=$(get_param "doris.home")                                       # 获取 Doris 安装路径
    file_decompress "doris.url" "${DORIS_HOME}"                                # 解压 Doris 安装包
    
    # 移动目录到指定路径
    mv "${DORIS_HOME}/extensions/apache_hdfs_broker"  "${DORIS_HOME}/broker"
    mv "${DORIS_HOME}/extensions/audit_loader"        "${DORIS_HOME}/"
    rm -rf  "${DORIS_HOME}/extensions/"
    
    # 创建必要的目录    
    mkdir -p  "${DORIS_HOME}/fe/data/meta" "${DORIS_HOME}/fe/data/tmp" "${DORIS_HOME}/fe/log"
    mkdir -p  "${DORIS_HOME}/be/data" "${DORIS_HOME}/be/log" "${DORIS_HOME}/broker/log"
    
    echo "    ********************** 修改 Doris 配置文件 ***********************    "
    cp -fpr "${ROOT_DIR}/conf/doris-fe.conf" "${DORIS_HOME}/fe/conf/fe.conf"   # fe 配置文件
    cp -fpr "${ROOT_DIR}/conf/doris-be.conf" "${DORIS_HOME}/be/conf/be.conf"   # be 配置文件
    cp -fpr "${ROOT_DIR}/script/apache/doris.sh" "${DORIS_HOME}/"              # 集群启停脚本
    
    priority_networks=$(get_param "server.gateway" | awk -F '.' '{print $1,$2}' | tr ' ' '.' | sed -e 's|$|\.0\.0/16|g')
    fe_list=$(get_param "doris.fe.hosts" | tr ',' ' ')                         # 获取 FE 集群节点
    be_list=$(get_param "doris.be.hosts" | tr ',' ' ')                         # 获取 BE 集群节点
    broker_list=$(get_param "doris.broker.hosts" | tr ',' ' ')                 # 获取 Broker 集群节点
    sed -i "s|\${fe_list}|${fe_list}|g"                      "${DORIS_HOME}/doris.sh"
    sed -i "s|\${be_list}|${be_list}|g"                      "${DORIS_HOME}/doris.sh"
    sed -i "s|\${broker_list}|${broker_list}|g"              "${DORIS_HOME}/doris.sh"
    sed -i "s|\${DORIS_HOME}|${DORIS_HOME}|g"                "${DORIS_HOME}/fe/conf/fe.conf"
    sed -i "s|\${DORIS_HOME}|${DORIS_HOME}|g"                "${DORIS_HOME}/be/conf/be.conf"
    sed -i "s|\${priority_networks}|${priority_networks}|g"  "${DORIS_HOME}/fe/conf/fe.conf"
    sed -i "s|\${priority_networks}|${priority_networks}|g"  "${DORIS_HOME}/be/conf/be.conf"
    
    doris_version=$(get_version "doris.url")                                   # 获取 Doris 的版本
    append_env "doris.home" "${doris_version}"                                 # 添加环境变量
    distribute_file "${DORIS_HOME}"                                            # 分发到其它节点
    
    echo "    **************************** 启动节点 ****************************    "
    # 启动 FE 集群
    for host in ${fe_list}
    do
        ssh "${USER}@${host}" "source ~/.bashrc; source /etc/profile; ${DORIS_HOME}/fe/bin/start_fe.sh --daemon"
    done
    
    # 启动 BE 集群
    for host in ${be_list}
    do
        ssh "${USER}@${host}" "source ~/.bashrc; source /etc/profile; ${DORIS_HOME}/be/bin/start_be.sh --daemon"
    done
    
    # 启动 broker 集群
    for host in ${broker_list}
    do
        ssh "${USER}@${host}" "source ~/.bashrc; source /etc/profile; ${DORIS_HOME}/broker/bin/start_broker.sh --daemon"
    done
    sleep 60                                                                   # 暂停 2 min 确保所有节点启动正常
    
    echo "    **************************** 构建集群 ****************************    "
    MYSQL_HOME=$(get_param "mysql.home")                                       # 获取 Mysql 安装路径
    leader_host=$(get_param "doris.fe.hosts" | awk -F ',' '{print $1}')        # 获取 leader
    sleep 65                                                                   # 暂停 2 min 确保所有节点启动正常
    
    # 添加 flower 
    for host in ${fe_list}
    do
        if [[ ${host} != "${leader_host}" ]]; then
            "${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root \
                --execute="alter system add follower '${host}:9010';" \
                >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        fi 
    done
    
    # 添加 observer     
    observer_list=$(get_param "doris.observer.hosts" | tr ',' ' ')
    for host in ${observer_list}
    do
        "${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root \
            --execute="alter system add observer '${host}:9010';" \
            >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    done
    
    # 添加 be 
    for host in ${be_list}
    do
        "${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root \
            --execute="alter system add backend '${host}:9050';" \
            >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    done
    
    # 添加 broker
    for host in ${broker_list}
    do
        "${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root \
            --execute="alter system add broker broker_name '${host}:8000';" \
            >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    done
    
    echo "    ************************** 查看集群状态 **************************    "
    # 查看 FE 状态
    fe_count=$("${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root --execute="show PROC '/frontends';" | wc -l)
    if [[ ${fe_count} -gt ${#fe_list[@]} ]]; then
        echo "    FE 集群构建成功 ...... "
    else
        echo "    FE 集群构建失败 ...... "
    fi
    
    # 查看 BE 状态
    be_count=$("${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root --execute="show PROC '/backends';" | wc -l)
    if [[ ${be_count} -gt ${#be_list[@]} ]]; then
        echo "    BE 集群构建成功 ...... "
    else
        echo "    FE 集群构建失败 ...... "
    fi
    
    # 查看 Broker 状态
    broker_count=$("${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root --execute="show PROC '/brokers';" | wc -l)
    if [[ ${broker_count} -gt ${#broker_list[@]} ]]; then
        echo "    Broker 集群构建成功 ...... "
    else
        echo "    FE 集群构建失败 ...... "
        return 1
    fi
    
    echo "    *************************** 配置数据库 ***************************    "
    doris_user=$(get_param "doris.user.name")                                  # 获取 Doris 用户
    doris_password=$(get_param "doris.user.password")                          # 获取 Doris 密码
    
    # 添加 用户
    "${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root --execute="create user if not exists '${doris_user}' identified by '${doris_password}';"
    
    # 添加数据库并授权给已添加的用户
    doris_database_list=$(get_param "doris.database" | tr ',' ' ')             # 获取 Doris 数据库
    for db in ${doris_database_list}
    do
        doris_set_sql="create database if not exists ${db}; grant all on ${db}.* to ${doris_user};"
        "${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root --execute="${doris_set_sql}"
    done
    
    # 重置 root 密码
    doris_root_password=$(get_param "doris.root.password")                     # 获取 doris root 密码
    "${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root --execute="set password for 'root' = password('${doris_root_password}');"
    
    echo "    **************************** 测试集群 ****************************    "
    {   
        echo "create database if not exists test;"
        echo ""
        echo "create table if not exists test.test "
        echo "( "
        echo "    id   int, "
        echo "    name varchar(255) replace_if_not_null null, "
        echo "    age  int          replace_if_not_null null, "
        echo "    mark text         replace_if_not_null null"
        echo ") aggregate key(id) distributed by hash(id) buckets 2 "
        echo "    properties ('replication_allocation' = 'tag.location.default: 1'); "
        echo ""
        echo "insert into test.test (id, name, age, mark) "
        echo "values (11, '张三', 22, '教师'), (12, '李四', 25, '学生'), (13, '王五', 28, null);"
        echo ""
        echo "select * from test.test order by id;"
        echo ""
        echo "insert into test.test (id, name, age, mark) values (19, '赵六', 30, '校长');"
        echo ""
        echo "select * from test.test order by id;"
        echo ""
        echo "insert into test.test (id, name, age, mark) values (19, '田七', 30, '校长');"
        echo ""
        echo "select * from test.test order by id;"                             
    }  > "${DORIS_HOME}/fe/log/test.sql"
    
    sleep 30
    "${MYSQL_HOME}/bin/mysql" --host="${leader_host}" --port=9030 --user=root --password="${doris_root_password}" \
                             < "${DORIS_HOME}/fe/log/test.sql" > "${DORIS_HOME}/fe/log/test.log" 2>&1
    
    test_result=$(grep -nic "田七" "${DORIS_HOME}/fe/log/test.log")
    if [[ ${test_result} -eq 1 ]]; then
        echo "    **************************** 测试成功 ****************************    "
    else    
        echo "    **************************** 测试失败 ****************************    "
    fi
}


printf "\n================================================================================\n"
if [ "$#" -gt 0 ]; then
    flush_env                                                                    # 刷新环境变量   
fi

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
