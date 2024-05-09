#!/usr/bin/env bash
# shellcheck disable=SC2139

# =========================================================================================
#    FileName      ：  zalias.sh
#    CreateTime    ：  2024-05-08 15:52
#    Author        ：  lihua shiyu
#    Email         ：  lihuashiyu@github.com
#    Description   ：  zalias.sh 被用于 ==> 给系统命令添加别名
# =========================================================================================

ALIAS_HOST=$(hostname)                                     # 本机主机名

# ================================================== ls =================================================== #
alias l.='ls     -d .*  --color=auto --time-style=long-iso' 2> /dev/null
alias la='ls     -Ah    --color=auto --time-style=long-iso' 2> /dev/null
alias ls='ls     -h     --color=auto --time-style=long-iso' 2> /dev/null
alias ll='ls     -lh    --color=auto --time-style=long-iso' 2> /dev/null
alias tree="tree -L 3   --sort=name  --ignore-case"

# ================================================= MySql ================================================= #
alias mysql="mysql --host=${ALIAS_HOST} --port=3306 " 2> /dev/null
alias mycli="mycli --host=${ALIAS_HOST} --port=3306 " 2> /dev/null
alias myit="mycli  --host=${ALIAS_HOST} --port=3306 --user=issac --password=111111 --database=test  " 2> /dev/null
alias myrm="mycli  --host=${ALIAS_HOST} --port=3306 --user=root  --password=111111 --database=mysql " 2> /dev/null

# ================================================= 查询 ================================================== #
alias netg="netstat -tunlp | grep -vi 'grep'          | grep -i " 2> /dev/null
alias psg="ps -aux         | grep -viE 'grep|ps -aux' | grep -i " 2> /dev/null
alias jps="jps -l          | sort -t ' ' -k 2         | grep -vi sun.tools.jps.Jps"

# ================================================== git ================================================== #
alias gfrp="git fetch --all  &&  git reset --hard  &&  git pull"

# ================================================= fuck ================================================== #
eval "$(thefuck --alias fuck)"

# ================================================= other ================================================= #
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
alias dir="dir     --color=auto"
alias vdir="vdir   --color=auto"
alias egrep="egrep --color=auto"
alias fgrep="fgrep --color=auto"
alias grep="grep   --color=auto"
