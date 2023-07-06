#!/usr/bin/env bash
    
    
SERVICE_DIR=$(cd "$(dirname "$0")/../" || exit; pwd)
SERVICE_NAME=Doris
    
FE_NAME=org.apache.doris.PaloFe
BE_NAME=lib/palo_be
    
FE_PORT=8030
FE_QUERY_PORT=9030
BE_PORT=9060
BE_WEB_PORT=8040
    
    
printf "\n=========================================================================\n"
#  匹配输入参数
case "$1" in
    #  1. 运行程序
    start)
        # 1.1 查找程序的 pid
        pid_fe=$(ps -aux | grep -i ${FE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}' | awk -F "_" '{print $1}')
        pid_be=$(ps -aux | grep -i ${BE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}' | awk -F "_" '{print $1}')
        
        #  1.2 若 pid 不存在，则运行程序，否则打印程序运行状态
        if [ ! "${pid_fe}" ] && [ ! "${pid_be}" ]; then
            echo "    程序（${SERVICE_NAME}）正在加载中 ......"
            "${SERVICE_DIR}/fe/bin/start_fe.sh" --daemon > /dev/null 2>&1
            sleep 3
            "${SERVICE_DIR}/be/bin/start_be.sh" --daemon > /dev/null 2>&1
            sleep 7
             
            # 1.3 判断程序 fe 启动是否成功
            fe=$(ps -aux | grep -i ${FE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}')
            if [ ! "${fe}" ]; then
                echo "    程序 FE 启动失败 ...... "
            fi
            
            # 1.4 判断程序 be 启动是否成功
            be=$(ps -aux | grep -i ${BE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}')
            if [ ! "${be}" ]; then
                echo "    程序 BE 启动失败 ...... "
            fi
            
            # 1.5 判断所有程序启动是否成功
            if [ "${fe}" ] && [ "${be}" ]; then
                echo "    程序（${SERVICE_NAME}）启动成功 ...... "
            else 
                echo "    程序（${SERVICE_NAME}）启动失败 ...... "
            fi
        elif [ "${pid_fe}" ] && [ "${pid_be}" ]; then
            echo "    程序（${SERVICE_NAME}）正在运行当中 ...... "
        else
            echo "    程序（${SERVICE_NAME}）运行出现问题 ...... "
        fi
    ;;
    
    #  2. 停止
    stop)
        # 2.1 根据程序的 pid 查询程序运行状态
        pid_fe=$(ps -aux | grep -i ${FE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}' | wc -l)
        pid_be=$(ps -aux | grep -i ${BE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}' | wc -l)
        
        if [ "${pid_fe}" -eq 0 ] && [ "${pid_be}" -eq 0 ]; then
            echo "    程序（${SERVICE_NAME}）的进程不存在，程序没有运行 ...... "
        elif [ "${pid_fe}" -eq 1 ] && [ "${pid_be}" -eq 1 ]; then
            # 2.2 杀死进程，关闭程序
            "${SERVICE_DIR}/be/bin/stop_be.sh" > /dev/null 2>&1
            sleep 2
            "${SERVICE_DIR}/fe/bin/stop_fe.sh" > /dev/null 2>&1
            sleep 5
            
            # 2.3 若还未关闭，则强制杀死进程，关闭程序
            be=$(ps -aux | grep -i ${BE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}' | wc -l)
            if [ "${be}" -ge 1 ]; then
                fet=$(ps -aux | grep -i ${FE_NAME} | grep -v grep | awk '{print $2}' | xargs kill -9)
            fi
            
            fe=$(ps -aux | grep -i ${FE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}' | wc -l)
            if [ "${fe}" -ge 1 ]; then
                bet=$(ps -aux | grep -i ${BE_NAME} | grep -v grep | awk '{print $2}' | xargs kill -9)
            fi
            
            echo "    程序（${SERVICE_NAME}）已经停止成功 ......"
        else
            echo "    程序（${SERVICE_NAME}）运行出现问题 ......"
        fi
     ;;
    
    #  3. 状态查询
    status)
        # 3.1 查看正在运行程序的 
        pid_fe=$(ps -aux | grep -i ${FE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}' | wc -l)
        pid_be=$(ps -aux | grep -i ${BE_NAME} | grep -v grep | grep -v "$0" | awk '{print $2}' | wc -l)
        
        if [ "${pid_fe}" -eq 0 ] && [ "${pid_be}" -eq 0 ]; then
            echo "    程序（${SERVICE_NAME}）已经停止 ...... "
        elif [ "${pid_fe}" -eq 1 ] && [ "${pid_be}" -eq 1 ]; then            
            echo "    程序（${SERVICE_NAME}）正在运行中 ......"
        else
            echo "    程序（${SERVICE_NAME}）运行出现问题 ......"
        fi
    ;;
        
    #  4. 重启程序
    restart)
        "$0" stop
        "$0" start
    ;;
        
    #  5. 其它情况
    *)
        echo "    脚本可传入一个参数，如下所示：              "
        echo "        +-----------------------------------+ "
        echo "        |  start | stop | restart | status  | "
        echo "        +-----------------------------------+ "
        echo "        |        start    ：  启动服务      | "
        echo "        |        stop     ：  关闭服务      | "
        echo "        |        restart  ：  重启服务      | "
        echo "        |        status   ：  查看状态      | "
        echo "        +-----------------------------------+ "
    ;;
esac
printf "=========================================================================\n\n"

