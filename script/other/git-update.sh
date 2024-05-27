#!/usr/bin/env bash

# ==================================================================================================
#    FileName      ：  git-update.sh
#    CreateTime    ：  2024-05-27 13:10
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  git-update.sh 被用于 ==> 更新 git 项目
# ==================================================================================================
    
SERVICE_DIR=$(dirname "$(readlink -e "$0")")                         # Shell 脚本目录
LOG_FILE="git-update-$(date +%F).log"                                # 程序操作日志文件名
    
    
# 更新 git 项目（$1：git 项目所在的目录）
function git_update()
{
    local project_list project                                       # 定义局域变量
    
    project_list=$(cd -P "$1" || exit; ls -da */)                    # 获取目录下的所有子目录
    for project in ${project_list}                                   # 循环遍历目录下的所有目录
    do
        if [ -d "$1/${project}.git" ]; then                          # 判断是否是 git 项目
            cd "$1/${project}" || exit                               # 进入项目路径
            echo "-----+-----+-----> $(date '+%T')：更新 $1/${project} "
                                
            {
                git fetch --all                                      # 与 git 远端进行信息同步
                git reset --hard                                     # 强制回退所有更改
                git pull                                             # 拉取最新项目内容
            }  >> "${SERVICE_DIR}/${LOG_FILE}" 2>&1
        fi    
    done
}
    

printf "\n================================================================================\n"
start=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)                  # 获取脚本执行开始时间
source /etc/profile && source "${HOME}/.bashrc"                      # 刷新环境变量
    
if [ "$#" -eq 0 ]; then                                              # 判断脚本输入参数的个数
    git_update "${SERVICE_DIR}"                                      # 更新当前文件夹下的所有 git
else                                                                 
    for project in "$@"                                              # 遍历所有参数
    do
        if [ -d "${project}" ]; then                                 # 判断参数是否是目录
            project_dir=$(cd -P "${project}" || exit; pwd -P)        # 获取目录的绝对路径
            git_update "${project_dir}"                              # 更新文件夹下的所有 git
        fi          
    done
fi
    
end=$(date -d "$(date +"%Y-%m-%d %H:%M:%S")" +%s)                    # 获取脚本执行的结束时间
echo "    脚本（$(basename "$0")）执行共消耗：$(( end - start ))s ...... "
printf "================================================================================\n\n"
exit 0
