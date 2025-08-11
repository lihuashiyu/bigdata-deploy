#!/usr/bin/env bash
    
# =========================================================================================
#    FileName      ：  conda-source.sh
#    CreateTime    ：  2025-08-11 16:19:57
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  conda 环境初始化
# =========================================================================================

__CONDA_HOME="${conda_home}"                                            # conda 安装目录

# 获取 conda 环境初始化脚本的输出结果
__conda_setup="$("${__CONDA_HOME}/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"

# 如果获取初始化脚本成功，则将获取的输出结果保存在 __conda_setup 变量中
if [ $? -eq 0 ]; then
    eval "${__conda_setup}"
else
    # 如果获取初始化脚本失败，尝试加载 conda 的 profile.d 脚本
    if [ -f "${__CONDA_HOME}/etc/profile.d/conda.sh" ]; then
        . "${__CONDA_HOME}/etc/profile.d/conda.sh"
    else
        # 如果 profile.d 脚本也不存在，则直接将 conda 的 bin 目录添加到 PATH 环境变量中
        export PATH="${__CONDA_HOME}/bin:$PATH"
    fi
fi

# 清理临时变量
unset  __conda_setup
unset  __CONDA_HOME

