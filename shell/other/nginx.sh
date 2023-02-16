#!/usr/bin/env bash


SERVICE_DIR=$(cd "$(dirname "$0")/../" || exit; pwd)
SERVICE_NAME=nginx
CONFIG_FILE=conf/nginx.conf

SERVICE_PORT1=8090
SERVICE_PORT2=10800

MASTER="nginx: master process"
WORKER="nginx: worker process"


printf "\n=========================================================================\n"
#  匹配输入参数
case "$1" in
    #  1. 运行程序
    start)
        # 1.1 统计正在运行程序的 pid 的个数
        nginx_pid=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | awk -F "_" '{print $1}')
                
        #  1.2 若 pid 个数为 0，则运行程序，否则打印程序正在运行
        if [ ! "${nginx_pid}" ]; then
            echo "    程序（${SERVICE_NAME}）正在加载 ......"
            "${SERVICE_DIR}/bin/${SERVICE_NAME}" -c "${SERVICE_DIR}/${CONFIG_FILE}" > /dev/null
            sleep 2

            # 1.3 判断程序 Master 启动是否成功
            master_pid=$(ps -aux | grep -i "${MASTER}" | grep -vi "$0" | grep -v grep | awk '{print $2}')
            if [ ! "${master_pid}" ]; then
                echo "    程序 Master 启动失败 ...... "
            fi
            
            # 1.4 判断程序 Worker 启动是否成功
            worker_pid=$(ps -aux | grep -i "${WORKER}" | grep -vi "$0" | grep -v grep | awk '{print $2}')
            if [ ! "${worker_pid}" ]; then
                echo "    程序 Worker 启动失败 ...... "
            fi
            
            # 1.5 判断程序启动是否成功
            pid_count=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${pid_count}" -ge 2 ]; then
                echo "    程序（${SERVICE_NAME}）启动成功 ...... "
            else
                echo "    程序（${SERVICE_NAME}）启动失败 ...... "
            fi
        else
            echo "    程序（${SERVICE_NAME}）正在运行 ...... "
        fi
    ;;

  
    # 2. 停止
    stop)
        # 2.1 统计正在运行程序的 pid 的个数
        pid_count=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        
        #  2.2 若 pid 个数大有等于 2，则停止程序，否则打印程序正在运行
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序（${SERVICE_NAME}）已经停止运行 ...... "
        elif [ "${pid_count}" -gt 0 ] && [ "${pid_count}" -lt 2 ]; then
            echo "    程序（${SERVICE_NAME}）运行出错 ...... "            
        else
            echo "    程序（${SERVICE_NAME}）停止中 ...... "
            "${SERVICE_DIR}/bin/${SERVICE_NAME}" -s quit > /dev/null
            sleep 1
            
            # 2.3 判断程序启动是否成功
            new_count=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${new_count}" -gt 0 ]; then
                temp=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | xargs kill -9)
                sleep 2
            fi
            
            echo "    程序（${SERVICE_NAME}）停止成功 ...... "
        fi
    ;;

    #  3. 状态查询
    status)
        # 2.1 统计正在运行程序的 pid 的个数
        pid_count=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序（${SERVICE_NAME}）已经停止运行 ...... "
        elif [ "${pid_count}" -eq 2 ]; then
            echo "    程序（${SERVICE_NAME}）正在运行 ...... "            
        else
            echo "    程序（${SERVICE_NAME}）运行出错 ...... "
        fi
    ;;

    #  4. 重启程序
    restart)
        # 4.1 统计正在运行程序的 pid 的个数
        pid_count=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
        
        #  4.2 若 pid 个数大有等于 2，则重启程序，否则打印程序正在运行
        if [ "${pid_count}" -eq 0 ]; then
            echo "    程序（${SERVICE_NAME}）已经停止运行 ...... "
        elif [ "${pid_count}" -gt 0 ] && [ "${pid_count}" -lt 2 ]; then
            echo "    程序（${SERVICE_NAME}）运行出错 ...... "            
        else
            echo "    程序（${SERVICE_NAME}）正在重启 ...... "
            "${SERVICE_DIR}/bin/${SERVICE_NAME}" -s reload > /dev/null
            sleep 2
            # 4.3 判断程序启动是否成功
            new_count=$(ps -aux | grep ${SERVICE_NAME} | grep -vi "$0" | grep -v grep | awk '{print $2}' | wc -l)
            if [ "${new_count}" -ge 2 ]; then
                echo "    程序（${SERVICE_NAME}）重启成功 ...... "
            else
                echo "    程序（${SERVICE_NAME}）重启失败 ...... "
            fi
        fi
    ;;

    #  5. 测试配置文件
    test)
        "${SERVICE_DIR}/bin/${SERVICE_NAME}" -t
    ;;

    #  6. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：                 "
        echo "        +----------------------------------------+ "
        echo "        | start | stop | restart | status | test | "
        echo "        +----------------------------------------+ "
        echo "        |        start    ：  启动服务           | "
        echo "        |        stop     ：  关闭服务           | "
        echo "        |        restart  ：  重启服务           | "
        echo "        |        status   ：  查看状态           | "
        echo "        |        test     ：  测试配置文件       | "
        echo "        +----------------------------------------+ "
    ;;
esac
printf "=========================================================================\n\n"

