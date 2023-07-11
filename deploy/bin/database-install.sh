#!/usr/bin/env bash

# =========================================================================================
#    FileName      ：  database-install
#    CreateTime    ：  2023-07-07 10:15:35
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  安装数据库相关软件：Mysql、Redis
# =========================================================================================


SERVICE_DIR=$(cd "$(dirname "$0")" || exit; pwd)                               # Shell 脚本目录
ROOT_DIR=$(cd "${SERVICE_DIR}/../" || exit; pwd)                               # 组件安装根目录
CONFIG_FILE="server.conf"                                                      # 配置文件名称
LOG_FILE="database-install-$(date +%F).log"                                    # 程序操作日志文件
USER=$(whoami)                                                                 # 当前登录使用的用户
REDIS_HOME="/opt/db/redis"                                                     # Redis 默认安装路径 
MYSQL_URL="/opt/db/mysql"                                                     # Mysql 默认安装路径 
PGSQL_HOME="/opt/db/pgsql"                                                     # Mysql 默认安装路径 
MONGO_HOME="/opt/db/mongodb"                                                   # Mysql 默认安装路径 
ORACLE_HOME="/opt/db/oracle"                                                   # Mysql 默认安装路径 


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


# 卸载系统自带的 MariaDB
# shellcheck disable=SC2024
function uninstall_mariadb()
{
    local password software_list software pid_list pid
    
    password=$(get_password)
    
    echo "    ******************************* 停止 MariaDB 相关进程 *******************************    "
    echo "${password}" | sudo -S systemctl stop mariadb.service  >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    echo "${password}" | sudo -S systemctl stop mysqld.service   >> "${ROOT_DIR}/logs/${LOG_FILE}" 2>&1
    
    pid_list=$(echo "${password}" | sudo -S ps -aux | grep -v grep | grep -iE "mysql|maria" | awk '{print $2}')
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
    
    cp -fpr "${ROOT_DIR}/conf/mysql-my.cnf"     "${MYSQL_HOME}/support-files/my.cnf"
    sed -i  "s|\${mysql.home}|${MYSQL_HOME}|g"  "${MYSQL_HOME}/support-files/my.cnf"
    
    echo "    ******************************* 修改 Mysql 的执行脚本 *******************************    "
    # 修改 mysql.server
    sed -i "s|^basedir=$|basedir=${MYSQL_HOME}|g"                         "${MYSQL_HOME}/support-files/mysql.server"
    sed -i "s|^datadir=$|datadir=${MYSQL_HOME}\/data|g"                   "${MYSQL_HOME}/support-files/mysql.server"
    sed -i "s|sbindir=$|basedir\/sbin/sbindir=\$basedir\/bin|g"           "${MYSQL_HOME}/support-files/mysql.server"
    sed -i "s|libexecdir=\$basedir\/libexec|libexecdir=\$basedir\/bin|g"  "${MYSQL_HOME}/support-files/mysql.server"
    sed -i "s|^mysqld_pid_file_path=$|mysqld_pid_file_path=${MYSQL_HOME}\/tmp\/mysqld.pid|g" "${MYSQL_HOME}/support-files/mysql.server"
    
    mysql_home_parent=$(cd "${MYSQL_HOME}/../" || exit; pwd)
    sed -i "s|usr\/local|${mysql_home_parent}|g"                          "${MYSQL_HOME}/support-files/mysql.server"
    
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
    temporary_password=$(grep -ni "password" "${MYSQL_HOME}/logs/init.log" | awk '{print $NF}') 
    
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
    "${MYSQL_HOME}/bin/mysql" -h 127.0.0.1 -P 3306 -u root -p${temporary_password} -D mysql \
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
                              
    insert_sql="insert into test (id, name, mark) values (101, 'issac', 'qazwsx');"
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


printf "\n================================================================================\n"
mkdir -p "${ROOT_DIR}/logs"                                                    # 创建日志目录

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
        echo "    脚本可传入一个参数，如下所示：   "
        echo "        +----------+------------------+ "
        echo "        |  参  数  |      描  述      |  "
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
