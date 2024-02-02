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


# 卸载系统自带的 MariaDB
function uninstall_mariadb()
{
    local password software_list software pid_list pid                         # 定义局部变量
    password=$(get_password)                                                   # 获取管理员密码
    
    echo "    ********************* 停止 MariaDB 相关进程 **********************    "
    {
        echo "${password}" | sudo -S systemctl stop mariadb.service            # 停止 MariaDB 服务
        echo "${password}" | sudo -S systemctl stop mysqld.service             # 停止 Mysql 服务       
    }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    pid_list=$(echo "${password}" | sudo -S ps -aux | grep -vE "grep|$0" | grep -iE "mysql|maria" | awk '{print $2}')
    for pid in ${pid_list}; 
    do
        echo "${password}" | sudo -S kill -9 "${pid}"                          # 强制杀死进程
    done
    
    echo "    ********************** 检查系统自带 MariaDB **********************    "
    # 获取系统安装的 MariaDB
    software_list=$(echo "${password}" | sudo -S rpm -qa | grep -iE "maria|mysql")
    if [ ${#software_list[@]} -eq 0 ]; then
        return 1
    fi
    
    echo "    ********************** 卸载系统自带 MariaDB **********************    "
    # 卸载系统安装的 MariaDB
    for software in ${software_list}
    do
         echo "${password}" | sudo -S rpm -e --nodeps "${software}" >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    done 
    
    echo "    ********************* 删除 MariaDB 配置文件 **********************    "
    echo "${password}" | sudo -S rm -rf /etc/mysql/ /etc/my.cnf /etc/my.cnf.d/ /var/lib/mysql
}


# 修改 Mysql 的配置文件，创建必要的目录，添加启停脚本
function mysql_install()
{
    echo "    ************************* 开始安装 Mysql *************************    "
    local mysql_list mysql_version mysql_home_parent                           # 定义局部变量
    
    MYSQL_HOME=$(get_param "mysql.home")                                       # 获取 Mysql 安装路径
    mysql_list=$(get_param "mysql.hosts" | tr "," " ")                         # 获取 Mysql 安装节点
    mysql_version=$(get_param "mysql.url")                                     # 获取 Mysql 安装节点
    
    file_decompress "mysql.url" "${MYSQL_HOME}"                                # 解压 Mysql 安装包
    
    echo "    ********************** 修改 Mysql 配置文件 ***********************    "
    # 创建 Mysql 数据存储目录、bin-log 数据存储目录、临时文件目录、日志存储目
    mkdir -p  "${MYSQL_HOME}/data" "${MYSQL_HOME}/bin-log" "${MYSQL_HOME}/tmp" "${MYSQL_HOME}/logs"
    chmod -R 771 "${MYSQL_HOME}/data/"                                         # 修改 数据存储目录 权限
    chmod -R 771 "${MYSQL_HOME}/bin-log/"                                      # 修改 bin-log 数据存储目录 权限
    chmod -R 777 "${MYSQL_HOME}/tmp/"                                          # 修改 临时文件目录 权限
    
    cp -fpr "${ROOT_DIR}/script/database/mysql.sh"  "${MYSQL_HOME}/bin/"       # 复制 Mysql 启停脚本
    cp -fpr "${ROOT_DIR}/conf/mysql-my.cnf"         "${MYSQL_HOME}/my.cnf"     # 复制 Mysql 配置文件
    
    sed -i  "s|\${mysql_list}|${mysql_list}|g"  "${MYSQL_HOME}/bin/mysql.sh"   # 修改 Mysql 启停脚本节点
    sed -i  "s|\${mysql.home}|${MYSQL_HOME}|g"  "${MYSQL_HOME}/my.cnf"         # 修改 Mysql 配置文件
    
    echo "    ********************* 修改 Mysql 的执行脚本 **********************    "
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
    
    echo "    ********************** 解决动态链接库缺失问 **********************    "
    if [ ! -f /usr/lib64/libtinfo.so.5 ]; then
        get_password | sudo -S ln -s /usr/lib64/libtinfo.so.6.2 /usr/lib64/libtinfo.so.5
    fi
    
    append_env "mysql.home" "${mysql_version}"
}


# 初始化 Msql，重置 root 密码，并创建用户，数据库
function mysql_init()
{
    local temporary_password root_password set_sql alter_root_pass_sql alter_root_host_sql flush_sql 
    local mysql_user mysql_password database_list database test_count
    cd "${MYSQL_HOME}" || exit
    
    echo "    ************************** Mysql 初始化 **************************    "
    "${MYSQL_HOME}/bin/mysqld" --initialize --console >> "${MYSQL_HOME}/logs/init.log" 2>&1 
    
    # 获取临时密码
    temporary_password=$(grep -ni "password" "${MYSQL_HOME}/logs/error.log" | awk '{print $NF}') 
    
    # 启动 Mysql 服务
    "${MYSQL_HOME}/support-files/mysql.server" start  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1 
    sleep 2
    
    echo "    ************************* 修改 root 访问 *************************    "
    root_password=$(get_param "mysql.root.password")                           # root 账户密码
     
    set_sql="set global validate_password.policy=LOW; set global validate_password.length=6;"      # 修改密码复杂度、长度，需要安装 validate_password 插件
    alter_root_pass_sql="alter user 'root'@'localhost' identified by '${root_password}';"          # 修改 root 账户 密码 
    alter_root_host_sql="update mysql.user set host = '%' where user = 'root';"                    # 使 root 能在任何 host 访问
    flush_sql="flush privileges;"                                                                  # 刷新权限，使得修改生效
    
    # 执行 sql
    "${MYSQL_HOME}/bin/mysql" --host=localhost --port=3306 --user=root --password="${temporary_password}"             \
                              --database=mysql --execute="${alter_root_pass_sql} ${alter_root_host_sql} ${flush_sql}" \
                              --connect-expired-password  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    echo "    ************************ 创建 Mysql 用户 *************************    "
    mysql_user=$(get_param "mysql.user.name")                                  # 新建账户名称
    mysql_password=$(get_param "mysql.user.password")                          # 新建账户密码
    
    "${MYSQL_HOME}/bin/mysql" --host=localhost --port=3306 --user=root --password="${root_password}" --database=mysql                   \
                              --execute="create user if not exists '${mysql_user}'@'%' identified by '${mysql_password}'; ${flush_sql}" \
                              >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
                              
    echo "    ********************* 创建数据库并授权给用户 *********************    "
    database_list=$(get_param "mysql.database" | tr ',' ' ')                   # 获取所有需要新建的的数据库
    for database in ${database_list}
    do  
        "${MYSQL_HOME}/bin/mysql" --host=localhost --port=3306 --user=root --password="${root_password}"  --database=mysql                                          \
                                  --execute="create database if not exists ${database}; grant all privileges on ${database}.* to '${mysql_user}'@'%'; ${flush_sql}" \
                                  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
        sleep 1                      
    done
    
    echo "    ************************ 测试 Mysql 安装 *************************    "
    # 打印测试 sql
    {
        echo "create table if not exists test.test                                  -- 创建 test 表"
        echo "( "
        echo "    id     int           comment '主键 ID', "
        echo "    name   varchar(64)   comment '姓名', "
        echo "    age    int           comment '年龄', "
        echo "    email  varchar(128)  comment '电子邮件', "
        echo "    remark varchar(1024) comment '备注' "
        echo ") comment '学生测试表'; "
        echo ""
        echo "insert into test.test (id, name, age, email, remark) values (1, '张三', 33, 'zhangsan@qq.com', '学生');"
        echo "insert into test.test (id, name, age, email, remark) values (2, '李四', 23, 'lisi@qq.com',     '学生');"
        echo "insert into test.test (id, name, age, email, remark) values (3, '王五', 28, 'wangwu@qq.com',   '学生');"
        echo ""
        echo "select * from test.test limit 10;"
    }  > "${MYSQL_HOME}/logs/test.sql"
    
    "${MYSQL_HOME}/bin/mysql"  --host=localhost --port=3306 --user="${mysql_user}" --password="${mysql_password}"  \
                               < "${MYSQL_HOME}/logs/test.sql"   >> "${MYSQL_HOME}/logs/test.log" 2>&1
                              
    test_count=$(grep -nic "学生" "${MYSQL_HOME}/logs/test.log")                 # 获取数据
    if [ "${test_count}" -eq 3 ]; then
        echo "    **************************** 测试成功 ****************************    "
    else    
        echo "    **************************** 测试失败 ****************************    "
    fi
} 


function redis_install()
{
    echo "    ************************* 开始安装 Redis *************************    "
    local redis_version src_folder redis_list test_count                       # 定义局部变量
    
    REDIS_HOME=$(get_param "redis.home")                                       # 获取 Redis 安装路径
    redis_version=$(get_version "redis.url")                                   # 获取 Redis 版本
    
    file_decompress  "redis.url"                                               # 解压 Redis 源码包
    src_folder=$(find "${ROOT_DIR}/package"/*  -maxdepth 0 -type d -print)     # 获取 Redis 源码的绝对路径
    
    echo "    **************************** 源码编译 ****************************    "
    cd "${src_folder}" || exit                                                 # 进入源码目录
    {
        make                                                                   # 编译源码  
        make PREFIX="${REDIS_HOME}" install                                    # 安装到指定路径        
    }  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1  
    
    echo "    ************************** 修改配置文件 **************************    "
    redis_list=$(get_version "redis.hosts" | tr "," " ")                       # Redis 安装节点
    
    mkdir -p "${REDIS_HOME}/data" "${REDIS_HOME}/conf" "${REDIS_HOME}/bin" "${REDIS_HOME}/logs"     # 创建必要的目录 
    cp -fpr "${ROOT_DIR}/script/database/redis.sh"  "${REDIS_HOME}/bin/"                 # 复制 Redis 启停脚本
    cp -fpr "${ROOT_DIR}/conf/redis-redis.conf"     "${REDIS_HOME}/conf/redis.conf"      # 复制 Redis 的配置文件
    cp -fpr "${ROOT_DIR}/conf/redis-sentinel.conf"  "${REDIS_HOME}/conf/sentinel.conf"   # 复制 哨兵 的配置文件
    
    sed -i "s|\${host_list}|${redis_list}|g"        "${REDIS_HOME}/bin/redis.sh"         # 修改启停脚本的节点
    sed -i "s|\${REDIS_HOME}|${REDIS_HOME}|g"       "${REDIS_HOME}/conf/redis.conf"      # 修改配置文件中的路径
    sed -i "s|\${REDIS_HOME}|${REDIS_HOME}|g"       "${REDIS_HOME}/conf/sentinel.conf"   # 修改配置文件中的路径
    
    append_env "redis.home" "${redis_version}"                                 # 添加环境变量
    
    echo "    ************************* 测试 Redis 安装 *************************    "
    "${REDIS_HOME}/bin/redis-server" "${REDIS_HOME}/conf/redis.conf"           # 启动 Redis
    test_count=$(ps -aux | grep -i "${USER}" | grep -vi grep | grep -ci "redis-server")
    if [ "${test_count}" -eq 1 ]; then
        echo "    **************************** 安装成功 ****************************    "
    else    
        echo "    **************************** 安装失败 ****************************    "
    fi
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


printf "\n================================================================================\n"
# 1. 获取脚本执行开始时间
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)

# 2. 刷新变量
if [ "$#" -gt 0 ]; then
    export REDIS_HOME MYSQL_HOME PGSQL_HOME MONGO_HOME ORACLE_HOME 
    flush_env                                                                  # 刷新环境变量    
fi

# 3. 匹配输入参数
case "$1" in
    # 3.1 安装 Mysql 并进行测试
    mysql | -m)
        uninstall_mariadb                                                      # 卸载系统自带的 MariaDB
        mysql_install                                                          # 安装   mysql
        mysql_init                                                             # 初始化 mysql
    ;;
    
    # 3.2 安装 Redis 
    redis | -r)
        redis_install 
    ;;
    
    # 3.3 安装 PostGreSQL 并进行测试
    pgsql | -p)
        pgsql_install
    ;;
    
    # 3.4 安装 MongoDB 并进行测试
    mongodb | -g)
        mongodb_install
    ;;
    
    # 3.5 安装 Oracle 并进行测试
    oracle | -o)
        oracle_install
    ;;
    
    # 3.6 安装 所有数据库软件
    all | -a)
        uninstall_mariadb                                                      # 卸载系统自带的 MariaDB
        mysql_install                                                          # 安装   mysql
        mysql_init                                                             # 初始化 mysql
        redis_install
        pgsql_install
        mongodb_install
        oracle_install
    ;;
    
    # 3.7 其它情况
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

# 4. 获取脚本执行结束时间，并计算脚本执行时间
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)
if [ "$#" -ge 1 ]; then
    echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
fi

printf "================================================================================\n\n"
exit 0
