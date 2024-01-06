#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  execute-sql.sh
#    CreateTime    ：  2024-01-04 21:25
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  execute-sql.sh 被用于 ==>  执行 sql、sql 文件、目录中的 sql 文件
# ==================================================================================================

SERVICE_DIR=$(dirname "$(readlink -e "$0")")                                   # 脚本的绝对目录
MYSQL_HOME=$(cd  -P "${SERVICE_DIR}/../" || exit; pwd -P)                      # Mysql 安装目录
MYSQL_HOST="localhost"                                                         # Mysql 主机名称
MYSQL_PORT="3306"                                                              # Mysql 端口号
MYSQL_USER="test"                                                              # Mysql 用户名
MYSQL_PASSWORD="111111"                                                        # Mysql 用户密码
MYSQL_DATABASE="test"                                                          # Mysql 数据库
LOG_FILE="execute-sql-$(date +%F).log"                                         # 操作日志文件


# 执行 SQL（$1：sql 文件的路径或所在目录或 sql）
function execute()
{
    local file_folder file_name file_path                                      # 定义局部变量

    if [ -z "$1" ]; then
        echo "    输入的路径为空 ...... "
        echo "    脚本使用格式为：$(basename "$0") 参数：  "
        echo "        支持执行 sql、sql 文件、sql 目录、数据的导入导出 ......  "
        echo "    "
    elif [ ! -e "$1" ]; then
        execute_sql  "$1"
    elif [ -d "$1" ]; then
        file_path=$(cd -P "$(readlink -e "$1")" || exit; pwd -P)
        execute_folder "${file_path}"
    elif [ -f "$1" ]; then
        file_name=$(basename "$(readlink -e "$1")")
        file_folder=$(cd -P "$(dirname "$(readlink -e "$1")")" || exit; pwd -P)
        execute_file "${file_folder}/${file_name}"
    else
        echo "    参数错误：arg = $1 ...... "
    fi
}


# 执行 sql 文件（$1：sql 文件的绝对路径）
function execute_file()
{
    echo "    ******************** $(date '+%T')：sql = $(basename "$1") 开始执行 ********************    "
    
    # 执行 sql 文件
    "${MYSQL_HOME}/bin/mysql" --host="${MYSQL_HOST}"         --port="${MYSQL_PORT}"         \
                              --user="${MYSQL_USER}"         --password="${MYSQL_PASSWORD}" \
                              --database="${MYSQL_DATABASE}" < "$1"                         \
                              >> "${MYSQL_HOME}/logs/${LOG_FILE}" 2>&1
    
    echo "    ******************** $(date '+%T')：sql = $(basename "$1") 执行完成 ********************    "
}


# 执行 sql 目录（$1：sql 文件所在的目录）
function execute_folder()
{
    local file_list file_path suffix                                           # 定义局部变量
    file_list=$(find "$1" -iname "*")                                          # 获取目录下所有的 sql 文件
    
    # 遍历文件，执行文件
    for file_path in ${file_list}
    do
        suffix=$(echo "${file_path##*.}" | tr [A-Z] [a-z])                     # 获取文件后缀
        
        if [ "${suffix}" = "sql" ]; then
            execute_file "${file_path}"                                        # 执行 Sql 文件
        else
            load_data "${file_path}"                                           # 向 Mysql 中导入数据
        fi
    done
}


# 执行 sql（$1：sql）
function execute_sql()
{
    "${MYSQL_HOME}/bin/mysql" --host="${MYSQL_HOST}"          --port="${MYSQL_PORT}"         \
                              --user="${MYSQL_USER}"          --password="${MYSQL_PASSWORD}" \
                              --database="${MYSQL_DATABASE}"  --execute="$1"                 \
                              2>> "${MYSQL_HOME}/logs/${LOG_FILE}"
}


# 向 Mysql 中导入数据（$1：文件绝对路径，$2：导入的表名）
function load_data()
{
    local suffix table_name load_sql field_sql line_sql separator enclose_escape="\"" line_format="\n"       # 定义局部变量    
    suffix=$(echo "$1" | awk -F '.' '{print $NF}' | tr [A-Z] [a-z])            # 获取文件后缀
    table_name=$(echo "${file_path%.*}" | xargs basename | tr '-' '_')         # 获取表名
    
    if [ "${suffix}" = "csv" ]; then
        separator=","
    elif [ "${suffix}" = "psv" ]; then
        separator="|"
    elif [ "${suffix}" = "psv" ]; then
        separator="|"
    elif [ "${suffix}" = "tsv" ]; then
        separator="\t"
    elif [ "${suffix}" = "ssv" ]; then
        separator=";"
    elif [ "${suffix}" = "hsv" ]; then
        separator="-"
    else
        separator=" "
    fi
    
    echo "    ******************** $(date '+%T')：file = $(basename "$1") 开始导入 ********************    "
    
    load_sql="load data infile '$1' into table ${table_name} character set utf-8"
    field_sql="fields terminated by '${separator}' optionally enclosed by '${enclose_escape}' escaped by '${enclose_escape}'"
    line_sql="lines terminated by '${line_format}'; "
    
    sed -i "s|\r||g"  "$1"                                                               # 修改所有的换行符
    
    "${MYSQL_HOME}/bin/mysql" --host="${MYSQL_HOST}"          --port="${MYSQL_PORT}"         \
                              --user="${MYSQL_USER}"          --password="${MYSQL_PASSWORD}" \
                              --database="${MYSQL_DATABASE}"  --local-infile                 \
                              --execute="${load_sql} ${field_sql} ${line_sql};"              \
                              2>> "${MYSQL_HOME}/logs/${LOG_FILE}"
                              
    echo "    ******************** $(date '+%T')：file = $(basename "$1") 导入完成 ********************    "
}


# 将 Mysql 中的数据导出到文件（$1：存放文件的路径）
function export_data()
{
    local file_path                                                            # 定义局部变量
    file_path=$(echo "$1" | awk -F '=' '{ print $NF}')                         # 获取文件路径
    echo "    ******************** $(date '+%T')：${MYSQL_DATABASE} 开始导出 ********************    "        
    
    "${MYSQL_HOME}/bin/mysqldump" --host="${MYSQL_HOST}"           --port="${MYSQL_PORT}"         \
                                  --user="${MYSQL_USER}"           --password="${MYSQL_PASSWORD}" \
                                  --databases "${MYSQL_DATABASE}"  --add-drop-database            \
                                  --add-drop-table                 --add-drop-trigger             \
                                  --comments                       --insert-ignore                \
                                  --skip-quote-names               --skip-set-charset             \
                                  > "${file_path}"                 2>> "${MYSQL_HOME}/logs/${LOG_FILE}"
                                  
    echo "    ******************** $(date '+%T')：${MYSQL_DATABASE} 导出完成 ********************    "                              
}


printf "\n================================================================================\n"
# 1. 刷新环境变量
source "${HOME}/.bash_profile" || source "${HOME}/.bashrc"; source /etc/profile

# 2. 匹配输入参数
for argument in "$@"
do
    case "${argument}" in
        -i* | --input*)
            file_path=$(echo "$1" | awk -F '=' '{ print $NF}')                 # 获取文件路径
            load_data "${file_path}"
        ;;
        
        -o* | --output*)                                                       # 将数据导出为 sql
            export_data "${argument}"
        ;;
        
        *)
            execute "${argument}"                                              # 执行参数
    esac
done

printf "================================================================================\n\n"
exit 0
