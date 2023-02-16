#!/usr/bin/env bash
# shellcheck disable=SC2009


SERVICE_DIR=$(cd "$(dirname "$0")/../" || exit; pwd)
SERVICE_NAME=Mysql
MYSQL_SAFE=mysqld_safe
MYSQLD=mysqld

SERVICE_PORT=3306
RUN=running
STOP=is


printf "\n=========================================================================\n"
#    匹配输入参数
case "$1" in
    # 1. 运行程序：running
    start)
        # 1.1 统计正在运行程序的 pid 的个数
        mysql_status=$("${SERVICE_DIR}/support-files/mysql.server" status | awk '{print $3}')
        mysql_pid=$(ps -aux | grep -i ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}')
        
        # 1.2 若 Mysql 运行状态为停止，则运行程序，否则打印程序正在运行
        if [ "${mysql_status}" = "${STOP}" ] && [ ! "${mysql_pid}" ]; then
            echo "    程序 ${SERVICE_NAME} 正在加载中 ......"
            "${SERVICE_DIR}/support-files/mysql.server" start > /dev/null 2>&1
            sleep 5

            # 1.3 判断程序 Mysqld_Safe 启动是否成功
            safe_pid=$(ps -aux | grep -i ${MYSQL_SAFE} |grep -vi "$0" | grep -v grep | awk '{print $2}')
            if [ ! "${safe_pid}" ]; then
                echo "    程序 mysqld_safe 启动失败 ...... "
            fi

            # 1.4 判断程序 Mysqld 启动是否成功
            mysqld_pid=$(ps -aux | grep -i ${MYSQLD} |grep -vi "$0" | grep -v grep | awk '{print $2}')
            if [ ! "${mysqld_pid}" ]; then
                echo "    程序 mysqld 启动失败 ...... "
            fi

            # 1.5 判断所有程序启动是否成功
            pid_count=$(ps -aux | grep -i ${SERVICE_NAME} |grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
            new_status=$("${SERVICE_DIR}/support-files/mysql.server" status | awk '{print $3}')
            if [ "${pid_count}" -ge 2 ] && [ "${new_status}" = "${RUN}" ]; then
                echo "    程序 ${SERVICE_NAME} 启动成功 ...... "
            else
                echo "    程序 ${SERVICE_NAME} 启动失败 ...... "
            fi
        else
            echo "    程序 ${SERVICE_NAME} 正在运行当中 ...... "
        fi
    ;;

    # 2. 停止
    stop)
        pid_count=$(ps -aux | grep -i ${SERVICE_NAME} |grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        new_status=$("${SERVICE_DIR}/support-files/mysql.server" status | awk '{print $3}')
        # 2.1 判断程序状态
        if [ "${pid_count}" -eq 0 ] && [ "${new_status}" = "${STOP}" ]; then
            echo "    ${SERVICE_NAME} 的进程不存在，程序没有运行 ...... "
        # 2.2 杀死进程，关闭程序
        elif [ "${pid_count}" -eq 2 ]; then
            echo "    程序 ${SERVICE_NAME} 正在停止 ......"
            "${SERVICE_DIR}/support-files/mysql.server" stop > /dev/null 2>&1
            sleep 5

            # 2.3 若还未关闭，则强制杀死进程，关闭程序
            pid_count=$(ps -aux | grep -i ${SERVICE_NAME} |grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${pid_count}" -ge 1 ]; then
                temp=$(ps -aux | grep -i ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | xargs kill -9)
            fi

            echo "    程序 ${SERVICE_NAME} 已经停止成功 ......"
        else
            echo "    程序 ${SERVICE_NAME} 运行出现问题 ......"
        fi
        ;;

    # 3. 状态查询
    status)
        # 3.1 查看正在运行程序的 pid
        pid_count=$(ps -aux | grep -i ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        new_status=$("${SERVICE_DIR}/support-files/mysql.server" status | awk '{print $3}')
        
        # 3.2 判断 Mysql 运行状态
        if [ "${pid_count}" -eq 0 ] && [ "${new_status}" = "${STOP}" ]; then
            echo "    程序 ${SERVICE_NAME} 已经停止 ...... "
        elif [ "${pid_count}" -eq 2 ] && [ "${new_status}" = "${RUN}" ]; then
            echo "    程序 ${SERVICE_NAME} 正在运行中 ...... "
        else
            echo "    程序 ${SERVICE_NAME} 运行出现问题 ...... "
        fi
    ;;

    # 4. 重启程序
    restart)
        # 3.1 重启 Mysql
        echo "    程序 ${SERVICE_NAME} 正在重启 ...... "
        "${SERVICE_DIR}/support-files/mysql.server" restart > /dev/null 2>&1
        sleep 5

        # 3.2 判断 Mysql 运行状态
        pid_count=$(ps -aux | grep -i ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        new_status=$("${SERVICE_DIR}/support-files/mysql.server" status | awk '{print $3}')

        if [ "${pid_count}" -eq 0 ] && [ "${new_status}" = "${STOP}" ]; then
            echo "    程序 ${SERVICE_NAME} 重启失败 ...... "
        elif [ "${pid_count}" -eq 2 ] && [ "${new_status}" = "${RUN}" ]; then
            echo "    程序 ${SERVICE_NAME} 重启成功 ...... "
        else
            echo "    程序 ${SERVICE_NAME} 运行出现问题 ...... "
        fi
        ;;

    # 5. 重启加载配置文件
    reload)
        # 3.1 判断 Mysql 状态
        pid_count=$(ps -aux | grep -i ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        new_status=$("${SERVICE_DIR}/support-files/mysql.server" status | awk '{print $3}')

        if [ "${pid_count}" -eq 2 ] && [ "${new_status}" = "${RUN}" ]; then
            echo "    程序 ${SERVICE_NAME} 正在重新加载配置文件 ...... "
            "${SERVICE_DIR}/support-files/mysql.server" reload > /dev/null 2>&1
            sleep 5

            pid_count=$(ps -aux | grep -i ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
            new_status=$("${SERVICE_DIR}/support-files/mysql.server" status | awk '{print $3}')

            if [ "${pid_count}" -eq 2 ] && [ "${new_status}" = "${RUN}" ]; then
                echo "    程序 ${SERVICE_NAME} 重新加载配置文件成功 ...... "
            else
                echo "    程序 ${SERVICE_NAME} 重新加载配置文件启失败 ...... "
            fi
        else
            echo "    程序 ${SERVICE_NAME} 已经停止，请先启动 ${SERVICE_NAME} ...... "
        fi
    ;;

    # 6. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：                       "
        echo "        +--------------------------------------------+ "
        echo "        |  start | stop | restart | status | reload  | "
        echo "        +--------------------------------------------+ "
        echo "        |          start      ：    启动服务         | "
        echo "        |          stop       ：    关闭服务         | "
        echo "        |          restart    ：    重启服务         | "
        echo "        |          status     ：    查看状态         | "
        echo "        |          reload     ：    重新加载         | "
        echo "        +---------------------------------------------+ "
    ;;
esac
printf "=========================================================================\n\n"

