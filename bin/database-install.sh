#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  database-install
#    CreateTime    ：  2023-07-07 10:15:35
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  安装数据库相关软件：Mysql、Redis
# =========================================================================================


SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 项目根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="database-install-$(date +%F).log"                                    # 程序操作日志文件
USER=$(whoami)                                                                 # 当前登录使用的用户
REDIS_HOME="/opt/db/redis"                                                     # Redis 默认安装路径 
MYSQL_HOME="/opt/db/mysql"                                                     # Mysql 默认安装路径 
PGSQL_HOME="/opt/db/pgsql"                                                     # Mysql 默认安装路径 
MONGO_HOME="/opt/db/mongodb"                                                   # Mysql 默认安装路径 
ORACLE_HOME="/opt/db/oracle"                                                   # Mysql 默认安装路径 


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


# 卸载系统自带的 MariaDB
function uninstall_mariadb()
{
    local password software_list software pid_list pid
    
    password=$(get_password)
    
    echo "    ******************************* 停止 MariaDB 相关进程 *******************************    "
    echo "${password}" | sudo -S systemctl stop mariadb.service  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    echo "${password}" | sudo -S systemctl stop mysqld.service   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    pid_list=$(echo "${password}" | sudo -S ps -aux | grep -vE "grep|$0" | grep -iE "mysql|maria" | awk '{print $2}')
    for pid in ${pid_list}; 
    do
        echo "${password}" | sudo -S kill -9 "${pid}"
    done
    
    echo "    ******************************* 检查系统自带 MariaDB *******************************    "
    # 获取系统安装的 MariaDB
    software_list=$(echo "${password}" | sudo -S rpm -qa | grep -iE "maria|mysql")
    if [ ${#software_list[@]} -eq 0 ]; then
        return
    fi
    
    echo "    ******************************* 卸载系统自带 MariaDB *******************************    "
    # 卸载系统安装的 MariaDB
    for software in ${software_list}
    do
         echo "${password}" | sudo -S rpm -e --nodeps "${software}" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    done 
    
    echo "    ******************************* 删除 MariaDB 配置文件 *******************************    "
    echo "${password}" | sudo -S rm -rf /etc/mysql/ /etc/my.cnf /etc/my.cnf.d/ /var/lib/mysql
}


# 修改 Mysql 的配置文件，创建必要的目录，添加启停脚本
function mysql_modify_config()
{
    local mysql_home_parent 
    echo "    ******************************* 修改 Mysql 的配置文件 *******************************    "
    
    cp -fpr "${ROOT_DIR}/conf/mysql-my.cnf"     "${MYSQL_HOME}/my.cnf"
    sed -i  "s|\${mysql.home}|${MYSQL_HOME}|g"  "${MYSQL_HOME}/my.cnf"
    
    echo "    ******************************* 修改 Mysql 的执行脚本 *******************************    "
    # 修改 mysql.server
    mysql_home_parent=$(cd "${MYSQL_HOME}/../" || exit; pwd)
    sed -i "s|^basedir=$|basedir=${MYSQL_HOME}|g"        "${MYSQL_HOME}/support-files/mysql.server"
    sed -i "s|^datadir=$|datadir=${MYSQL_HOME}\/data|g"  "${MYSQL_HOME}/support-files/mysql.server"
    sed -i "s|basedir\/sbin|basedir\/bin|g"              "${MYSQL_HOME}/support-files/mysql.server"
    sed -i "s|basedir\/libexec|basedir\/bin|g"           "${MYSQL_HOME}/support-files/mysql.server"
    sed -i "s|\/etc/my.cnf|\$basedir\/my.cnf|g"          "${MYSQL_HOME}/support-files/mysql.server"
    sed -i "s|\/usr\/local|${mysql_home_parent}|g"       "${MYSQL_HOME}/support-files/mysql.server"
    
    # 修改 mysqld_multi.server
    sed -i "s/usr\/local/opt\/db/g"  "${MYSQL_HOME}/support-files/mysqld_multi.server"
    
    # 修改 mysqld_multi.server
    sed -i "s/usr\/local/opt\/db/g"  "${MYSQL_HOME}/support-files/mysql-log-rotate"
    
    echo "    ******************************* 创建 Mysql 必要的文件夹 *******************************    "
    mkdir -p     "${MYSQL_HOME}/data/"                                      # 创建 Mysql 数据存储目录
    mkdir -p     "${MYSQL_HOME}/bin-log/"                                   # 创建 Mysql bin-log 数据存储目录
    mkdir -p     "${MYSQL_HOME}/tmp/"                                       # 创建 Mysql 临时文件目录
    mkdir -p     "${MYSQL_HOME}/logs/"                                      # 创建 Mysql 日志存储目录
    chmod -R 771 "${MYSQL_HOME}/data/"                                      # 修改 数据存储目录 权限
    chmod -R 771 "${MYSQL_HOME}/bin-log/"                                   # 修改 bin-log 数据存储目录 权限
    chmod -R 777 "${MYSQL_HOME}/tmp/"                                       # 修改 临时文件目录 权限
    
    echo "    ******************************* 解决动态链接库缺失问 *******************************    "
    
    if [ ! -f /usr/lib64/libtinfo.so.5 ]; then
        get_password | sudo -S ln -s /usr/lib64/libtinfo.so.6.2 /usr/lib64/libtinfo.so.5
    fi
    
    append_env "mysql.home" "8.0.32"
    
    echo "    ******************************* 添加 Mysql 的启停脚本 *******************************    "
    cp -fpr "${ROOT_DIR}/script/database/mysql.sh"  "${MYSQL_HOME}/bin/"
    chmod +x "${MYSQL_HOME}/bin/mysql.sh"
}


# 初始化 Msql，重置 root 密码，并创建用户，数据库
function mysql_init()
{
    local temporary_password root_password set_sql alter_root_pass_sql alter_root_host_sql flush_sql mysql_user mysql_password database_list database
    cd "${MYSQL_HOME}" || exit
    
    echo "    ******************************* Mysql 初始化 *******************************    "
    "${MYSQL_HOME}/bin/mysqld" --initialize --console >> "${MYSQL_HOME}/logs/init.log" 2>&1 
    
    # 获取临时密码
    temporary_password=$(grep -ni "password" "${MYSQL_HOME}/logs/error.log" | awk '{print $NF}') 
    
    # 启动 Mysql 服务
    "${MYSQL_HOME}/support-files/mysql.server" start  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
    sleep 2
    
    echo "    ******************************* 修改 root 访问 *******************************    "
    root_password=$(get_param "mysql.root.password")
     
    set_sql="set global validate_password.policy=LOW; set global validate_password.length=6;"      # 修改密码复杂度、长度，需要安装 validate_password 插件
    alter_root_pass_sql="alter user 'root'@'localhost' identified by '${root_password}';"          # 修改 root 账户 密码 
    alter_root_host_sql="update mysql.user set host = '%' where user = 'root';"                    # 使 root 能在任何 host 访问
    flush_sql="flush privileges;"                                                                  # 刷新权限，使得修改生效
    # 执行 sql
    "${MYSQL_HOME}/bin/mysql" -h localhost -P 3306 -u root -p${temporary_password} -D mysql    \
                              -e "${alter_root_pass_sql} ${alter_root_host_sql} ${flush_sql}" \
                              --connect-expired-password
    
    echo "    ******************************* 创建 Mysql 用户 *******************************    "
    mysql_user=$(get_param "mysql.user.name")
    mysql_password=$(get_param "mysql.user.password")
    
    "${MYSQL_HOME}/bin/mysql" -h 127.0.0.1 -P 3306 -u root -p"${root_password}" \
                              -e "create user if not exists '${mysql_user}'@'%' identified by '${mysql_password}'; ${flush_sql}"
    
    echo "    ******************************* 创建数据库并授权给用户 *******************************    "
    database_list=$(get_param "mysql.database" | tr ',' ' ')
    for database in ${database_list}
    do  
        "${MYSQL_HOME}/bin/mysql" -h 127.0.0.1 -P 3306 -u root -p"${root_password}" \
                              -e "create database if not exists ${database}; grant all privileges on ${database}.* to '${mysql_user}'@'%'; ${flush_sql}"
        sleep 1                      
    done
}


# 测试 Mysql 安装情况
function mysql_test()
{
    echo "    ************************* 开始安装 Mysql *************************    "
    local mysql_user mysql_password create_sql show_sql insert_sql select_sql
    
    MYSQL_HOME=$(get_param "mysql.home")                                       # 获取 Mysql 安装路径
    uninstall_mariadb                                                          # 卸载系统自带的 MariaDB
    file_decompress "mysql.url" "${MYSQL_HOME}"                                # 解压 mysql 安装包
    mysql_modify_config                                                        # 修改配置文件
    mysql_init                                                                 # 初始化 mysql，并进行初始化，修改 root 密码
    
    mysql_user=$(get_param "mysql.user.name")
    mysql_password=$(get_param "mysql.user.password")
    
    create_sql="create table if not exists test(id int primary key, name varchar(64) not null default '', mark varchar(255) not null default '未知') engine = InnoDB;"  
    "${MYSQL_HOME}/bin/mysql" -u "${mysql_user}" -p"${mysql_password}" -D test -e "${create_sql}"
    
    show_sql="show create table test;"
    "${MYSQL_HOME}/bin/mysql" -u "${mysql_user}" -p"${mysql_password}" -D test -e "${show_sql}"
                              
    insert_sql="insert into test (id, name, mark) values (101, 'XiaoWang', 'qazwsx');"
    "${MYSQL_HOME}/bin/mysql" -u "${mysql_user}" -p"${mysql_password}" -D test -e "${insert_sql}"
                              
    select_sql="select * from test;"
    "${MYSQL_HOME}/bin/mysql" -u "${mysql_user}" -p"${mysql_password}" -D test -e "${select_sql}"                          
}


function resource_compile()
{
    local src_folder
    src_folder=$(cd "$(ls -F "${ROOT_DIR}/package" | grep "/$")" || exit; pwd) # 获取源码目录
    
    echo "    ******************** 进行源码编译 ********************    "
    cd "${src_folder}" || exit                                                 # 进入源码目录
    make           >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1                      # 编译源码  
    make PREFIX="$1" install >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 # 安装到指定路径
    
    echo "    ******************** 创建必要的目录 ********************    "
    mkdir -p "$1/data" "$1/conf" "$1/bin" "$1/logs"     # 创建必要的目录 
}


function redis_install()
{
    echo "    ************************* 开始安装 Redis *************************    "
    REDIS_HOME=$(get_param "redis.home")                                       # 获取 Redis 安装路径
    file_decompress  "redis.url"                                               # 解压 redis 源码包
    resource_compile "${REDIS_HOME}"                                           # 编译 Redis 源码
    
    echo "    ******************** 修改 Redis 配置文件 ********************    "
    cp -fpr "${ROOT_DIR}/script/database/redis.sh"  "${REDIS_HOME}/bin/"       # 复制 Redis 启停脚本
    chmod +x "${REDIS_HOME}/bin/redis.sh"                                      # 授予 Redis 启停脚本执行权限
    
    cp -fpr "${ROOT_DIR}/conf/redis-redis.conf"    "${REDIS_HOME}/conf/redis.conf"       # 复制 Redis 的配置文件
    cp -fpr "${ROOT_DIR}/conf/redis-sentinel.conf" "${REDIS_HOME}/conf/sentinel.conf"    # 复制 哨兵 的配置文件
    sed -i "s|\${REDIS_HOME}|${REDIS_HOME}|g"      "${REDIS_HOME}/conf/redis.conf"       # 修改配置文件中的路径
    sed -i "s|\${REDIS_HOME}|${REDIS_HOME}|g"      "${REDIS_HOME}/conf/sentinel.conf"    # 修改配置文件中的路径
    
    echo "    ******************** 添加启动 Redis 环境变量********************    "
    append_env "redis.home" "6.2.12"
    
    echo "    ************************* 启动 Redis *************************    "
    "${REDIS_HOME}/bin/redis.sh" start
}


function pgsql_install()
{
    echo "    ************************* 开始安装 PostGreSQL *************************    "
}


function mongodb_install()
{
    echo "    ************************* 开始安装 MongoDB *************************    "
}


function oracle_install()
{
    echo "    ************************* 开始安装 Oracle *************************    "
}


if [ "$#" -gt 0 ]; then
    mkdir -p "${ROOT_DIR}/logs"                                                # 创建日志目录
    # shellcheck source=./common.sh
    source "${SERVICE_DIR}/common.sh" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1   # 获取公共函数    
fi

printf "\n================================================================================\n"
if [ "$#" -gt 0 ]; then
    flush_env                                                                  # 刷新环境变量    
fi

# 匹配输入参数
case "$1" in
    # 1. 安装 Mysql 并进行测试
    mysql | -m)
        mysql_test
    ;;
    
    # 2. 安装 Redis 
    redis | -r)
        redis_install 
    ;;
    
    # 3. 安装 PostGreSQL 并进行测试
    pgsql | -p)
        pgsql_install
    ;;
    
    # 4. 安装 MongoDB 并进行测试
    mongodb | -g)
        mongodb_install
    ;;
    
    # 4. 安装 Oracle 并进行测试
    oracle | -o)
        oracle_install
    ;;
    
    # 4. 安装 所有数据库软件
    all | -a)
        mysql_test
        redis_install
        pgsql_install
        mongodb_install
        oracle_install
    ;;
    
    # 10. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：      "
        echo "        +----------+------------------+ "
        echo "        |  参  数  |      描  述      | "
        echo "        +----------+------------------+ "
        echo "        |    -m    |   安装 mysql     | "
        echo "        |    -r    |   安装 redis     | "
        echo "        |    -p    |   安装 pgsql     | "
        echo "        |    -g    |   安装 mongodb   | "
        echo "        |    -o    |   安装 oracle    | "
        echo "        |    -a    |   安装 all       | "
        echo "        +----------+------------------+ "
    ;;
esac
printf "================================================================================\n\n"
exit 0
