## 1. 修改 yum/dnf 或 apt 源（需要使用 root 权限）

### 1.1 debian（11.* 12.*）修改 阿里镜像源
```bash
    # 需要使用 root 用户，或 sudo 进行提权
    cp  /etc/apt/sources.list  /etc/apt/sources.list.bak
    
    deb      https://mirrors.aliyun.com/debian/           bullseye           main non-free contrib
    deb-src  https://mirrors.aliyun.com/debian/           bullseye           main non-free contrib
    deb      https://mirrors.aliyun.com/debian-security/  bullseye-security  main
    deb-src  https://mirrors.aliyun.com/debian-security/  bullseye-security  main
    deb      https://mirrors.aliyun.com/debian/           bullseye-updates   main non-free contrib
    deb-src  https://mirrors.aliyun.com/debian/           bullseye-updates   main non-free contrib
    deb      https://mirrors.aliyun.com/debian/           bullseye-backports main non-free contrib
    deb-src  https://mirrors.aliyun.com/debian/           bullseye-backports main non-free contrib
    
    apt clean all                                                              # 清空缓存
    apt update                                                                 # 获取源更新
    apt upgrade                                                                # 更新软件
```

### 1.2 ubuntu（20.* 22.*）修改 阿里镜像源

```bash
    # 需要使用 root 用户，或 sudo 进行提权
    cp  /etc/apt/sources.list  /etc/apt/sources.list.bak
        
    deb     https://mirrors.aliyun.com/ubuntu/  focal            main restricted universe multiverse
    deb-src https://mirrors.aliyun.com/ubuntu/  focal            main restricted universe multiverse
    
    deb     https://mirrors.aliyun.com/ubuntu/  focal-security   main restricted universe multiverse
    deb-src https://mirrors.aliyun.com/ubuntu/  focal-security   main restricted universe multiverse
    
    deb     https://mirrors.aliyun.com/ubuntu/  focal-updates    main restricted universe multiverse
    deb-src https://mirrors.aliyun.com/ubuntu/  focal-updates    main restricted universe multiverse
    
    # deb     https://mirrors.aliyun.com/ubuntu/  focal-proposed  main restricted universe multiverse
    # deb-src https://mirrors.aliyun.com/ubuntu/  focal-proposed  main restricted universe multiverse
    
    deb     https://mirrors.aliyun.com/ubuntu/  focal-backports  main restricted universe multiverse
    deb-src https://mirrors.aliyun.com/ubuntu/  focal-backports  main restricted universe multiverse
    
    apt clean all                                                              # 清空缓存
    apt update                                                                 # 获取源更新
    apt upgrade                                                                # 更新软件
```

### 1.3 centos 7 系列修改 阿里镜像源

```bash
    # 需要使用 root 用户，或 sudo 进行提权
    mv       /etc/yum.repos.d/CentOS-Base.repo  /etc/yum.repos.d/CentOS-Base.repo.bak
    
    # wget -O  /etc/yum.repos.d/CentOS-Base.repo  https://mirrors.aliyun.com/repo/Centos-7.repo
    curl -o  /etc/yum.repos.d/CentOS-Base.repo  https://mirrors.aliyun.com/repo/Centos-7.repo
    
    yum clean all                                                              # 清空缓存
    yum makecache                                                              # 生成缓存源
    yum update                                                                 # 获取源更新
    yum upgrade                                                                # 更新软件
```

### 1.4 rocky（8.* 9.*）系列修改 阿里镜像源

```bash
    # 需要使用 root 用户，或 sudo 进行提权
    sed -e 's|^mirrorlist=|#mirrorlist=|g'                                                                      \
        -e 's|^#baseurl=http://dl.rockylinux.org/\$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g'  \
        -e 's|^#baseurl=https://dl.rockylinux.org/\$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
        -i.bak /etc/yum.repos.d/[Rr]ocky*.repo
        
    dnf clean all                                                              # 清空缓存
    dnf makecache                                                              # 生成缓存源
    dnf update                                                                 # 获取源更新
    dnf upgrade                                                                # 获取源更新
```

### 1.5 almalinux（8.* 9.*）修改 阿里镜像源

```bash
    # 需要使用 root 用户，或 sudo 进行提权
    sed -e 's|^mirrorlist=|#mirrorlist=|g'                                                \
        -e 's|^# baseurl=http://repo.almalinux.org|baseurl=https://mirrors.aliyun.com|g'  \
        -e 's|^# baseurl=https://repo.almalinux.org|baseurl=https://mirrors.aliyun.com|g' \
        -i.bak /etc/yum.repos.d/almalinux*.repo
            
    dnf clean all                                                              # 清空缓存
    dnf makecache                                                              # 生成缓存源
    dnf update                                                                 # 获取源更新
    dnf upgrade                                                                # 获取源更新
```

<br />


## 2. 修改网络

### 2.1 修改主机名称

```bash
    hostname                                                                   # 查看当前系统的主机名
    hostname    master                                                         # 临时修改主机名为 master，会话关闭失效
    hostnamectl set-hostname master                                            # 永久修改主机名为 master（重启生效）
    vim /etc/hostname                                                          # 永久修改主机名为 master（重启生效）
```

<br />

### 2.2 修改 hosts 映射

```bash
    # 方法一：vim 编辑器进行修改
    vim /etc/hosts                                                             # 使用 vim 编辑器添加如下内容
        192.168.100.10      master
    
    # 方法二：使用重定向追加模式
    echo "192.168.100.100      master"  >> /etc/hosts                          # master
    echo "192.168.100.111      slaver1" >> /etc/hosts                          # slaver1
    echo "192.168.100.122      slaver2" >> /etc/hosts                          # slaver2
    echo "192.168.100.133      slaver3" >> /etc/hosts                          # slaver3
    
    # 以下内容适量添加
    echo "127.0.0.1            unix"    >> /etc/hosts                          # unix
    echo "127.0.0.1            linux"   >> /etc/hosts                          # linux
    echo "127.0.0.1            rocky"   >> /etc/hosts                          # rocky
    echo "127.0.0.1            alma"    >> /etc/hosts                          # alma
    echo "127.0.0.1            elastic" >> /etc/hosts                          # elastic
```

### 2.3 网络 IP 配置

```bash
    systemctl status NetworkManager                                            # 检查网卡状态
    
    # 使用 vim 修改网卡信息
    vim /etc/sysconfig/Network-Scripts/ens160.nmconnection                     # Rocky 8.*
    vim /etc/NetworkManager/system-connections/ens160.nmconnection             # Rocky 9.*
        [ipv4]
        method=manual
        adress1=192.168.100.100/24,192.168.100.1
        dns=192.168.100.1;114.114.114.114;8.8.8.8
        
    # 使用命令修改网卡信息
    nmcli con mod   'ens160' ifname   ens160 ipv4.method manual ipv4.addresses 192.168.100.100/24 gw4 192.168.100.1
    nmcli con mod   'ens160' ipv4.dns 192.168.100.1;114.114.114.114;8.8.8.8
    nmcli con down  'ens160'
    nmcli con up    'ens160'
    
    # 使用命令修改网卡信息
    nmcli connection modify ens160 ipv4.gateway '192.168.100.1'                # 配置 IPv4 地址
    nmcli connection modify ens160 ipv4.address '192.168.100.100'              # 配置 网关 地址
    nmcli connection modify ens160 ipv4.method  manual                         # 配置 网卡 状态


    nmcli connection reload                                                    # 重启网卡
    nmcli connection down   ens160                                             # 下线网卡
    nmcli connection up     ens160                                             # 上线网卡
```
<br>

## 3. 关闭安全防护

### 3.1 关闭防火墙

```bash
    # start：开启防火墙；stop：关闭防火墙；status：查看状态；enable：开机自启；disable：关闭开机自启
    systemctl status  firewalld.service                                        # 查看防火墙状态，或者：firewall-cmd --state
    systemctl stop    firewalld.service                                        # 关闭防火墙
    systemctl disable firewalld.service                                        # 关闭防火墙开机自启
    
    # 将如下 ip 添加到防火墙（如果必须开启防火墙）
    firewall-cmd --permanent --add-source=192.168.100.100                      # 添加到防火墙白名单
    firewall-cmd --permanent --add-source=192.168.100.111                      # 添加到防火墙白名单
    firewall-cmd --permanent --add-source=192.168.100.122                      # 添加到防火墙白名单
    firewall-cmd --permanent --add-source=192.168.100.133                      # 添加到防火墙白名单
```

### 3.2 关闭 selinux

```bash
    # 安装策略包
    sudo apt install policycoreutils                                           # debian/ubuntu
    sudo yum install policycoreutils                                           # redhat/centos/rocky/alma
    
    sestatus                                                                   # 检查系统 SELinux 状态
    setenforce 0                                                               # 临时禁用 SELinux，或者：setenforce Permissive
    
    # 使用 vim 修改策略
    vim /etc/sysconfig/selinux                                                 # 编辑 SELinux 配置文件（需要重启系统）
        SELinux=disabled                                                       # 注释 SELinux=enforcing，或命令：sed -i 's/SELinux=enforcing/SELinux=disabled/g' /etc/sysconfig/selinux
    
    # 使用 命令 修改策略
    sed -i "s|SELINUX=enforcing|# SELINUX=enforcing\nSELINUX=disabled|g" /etc/sysconfig/selinux
    
    sestatus                                                                   # 再次检查系统 SELinux 状态
```

<br />

## 4. 修改系统限制

### 4.1 修改打开文件限制：/etc/security/limits.conf

```bash
    *    soft    nproc      65536
    *    hard    nproc      65536
    *    soft    nofile     65536
    *    hard    nofile     65536
    *    soft    stack      20480
    *    hard    stack      20480
    
    *    soft    memlock    134217728
    *    hard    memlock    134217728
    *    soft    data       unlimited
    *    hard    data       unlimited
```

### 4.2 修改系统限制的文件最大值 /proc/sys/fs/file-max

```bash
    vim  /proc/sys/fs/file-max
    sudo echo "12993683"            >> /proc/sys/fs/file-max   # RedHat 7 系列
    sudo echo "9223372036854775807" >> /proc/sys/fs/file-max   # RedHat 8/9 系列
```

### 4.3 优化内核参数：/etc/sysctl.conf

```bash
    vm.max_map_count             = 262144                      # 限制一个进程可以拥有的VMA(虚拟内存区域)的数量
    vm.overcommit_memory         = 1                           # 内存分配策略：0：内核将检查是否有足够的可用内存供应用进程使用；如果有，申请允许；否则，申请失败，并把错误返回给应用进程；1：内核允许分配所有的物理内存，而不管当前的内存状态如何；2：内核允许分配超过所有物理内存和交换空间总和的内存
    vm.swappiness                = 40                          # 内存剩余 40% 的时候，开始使用虚拟内存
    
    kernel.shmmni                = 4096                        # 系统范围内共享内存段的最大数量（默认4096）
    kernel.shmmax                = 18446744073692774399        # 共享内存段的最大尺寸（以字节为单位，默认 32M）
    kernel.shmall                = 18446744073692774399        # 系统一次可以使用的共享内存总量（以页为单位，默认 2097152）
    kernel.sem                   = 32000	1024000000	500	32000 # 每个信号集的最大信号数量、系统中信号（而不是信号集）的最大数、每个 semop 系统调用可以执行的信号操作的数量、信号集的最大数量
    
    fs.aio-max-nr                = 1048576                     # 所允许的并发请求的最大个数（64KB，用来对异步 I/O 的性能进行优化)
    fs.file-max                  = 9223372036854775807         # 整个系统可以打开的最大文件数的限制
    fs.nr_open                   = 1073741816                  # 单个进程可分配的最大文件数
    
    net.ipv4.ip_local_port_range = 4096 65535                  # 表示向外连接的 IPv4 端口范围
    net.core.rmem_default        = 262144                      # TCP 数据接收缓冲默认大小
    net.core.rmem_max            = 4194304                     # 最大的 TCP 数据接收缓冲
    net.core.wmem_default        = 262144                      # TCP 数据发送缓冲默认大小
    net.core.wmem_max            = 2097152                     # 最大的 TCP 数据发送缓冲
    net.ipv4.tcp_rmem            = 4096 131072 16777216        # TCP 接收缓冲区的最小值、默认初始值、最大值
    net.ipv4.tcp_wmem            = 4096 65536 8388608          # TCP 发送缓冲区的最小值、默认初始值、最大值
    
    net.ipv4.tcp_keepalive_time  = 120                         # TCP 发送 keepalive 消息的频度
    net.ipv4.tcp_keepalive_probes = 3                          # 如果对方不予应答，探测包的发送次数
    net.ipv4.tcp_keepalive_intvl = 15                          # keepalive探测包的发送间隔
    net.ipv4.tcp_fin_timeout     = 10                          # 表示如果套接字由本端要求关闭，这个参数决定了它保持在 FIN-WAIT-2 状态的时间
    net.ipv4.tcp_max_tw_buckets  = 8192                        # 同时保持 TIME_WAIT 套接字的最大数量
    net.ipv4.tcp_timestamps      = 1                           # 开启TCP时间戳
    net.ipv4.tcp_window_scaling  = 0                           # 关闭 tcp_window_scaling
    net.ipv4.route.gc_timeout    = 100                         # 路由缓存刷新频率，当一个路由失败后多长时间跳到另一个路由
    net.ipv4.tcp_syncookies      = 1                           # 开启SYN Cookies：当出现 SYN 等待队列溢出时，启用 cookies 来处理，可防范少量 SYN 攻击
    net.ipv4.tcp_max_orphans     = 8192                        # 最大孤儿连接的数量，超过时连接就会直接释放
    net.ipv4.tcp_sack            = 1                           # 启用 sack
    net.ipv4.tcp_no_metrics_save = 1                           # 新建立相同连接时，使用保存的参数来初始化连接
    net.ipv4.tcp_max_syn_backlog = 262144                      # SYN 队列长度，越大，容纳的等待连接的网络连接数越多
    net.ipv4.tcp_synack_retries  = 3                           # 控制 sync + ack 包的重传次数
    net.ipv4.tcp_syn_retries     = 2                           # 在内核放弃建立连接之前发送 SYN 包的数量
    net.core.somaxconn           = 65535                       # socket 监听的 backlog(监听队列)上限
    net.core.netdev_max_backlog  = 262144                      # 网络设备接收数据包的速率比内核处理这些包的速率快时，允许送到队列的数据包的最大数目
    net.core.optmem_max          = 8192000                     # 每个套接字所允许的最大缓冲区的大小
```

### 4.4 设置虚拟内存

```bash
    swapon -s                                                                  # 查看当前 swap 的使用情况
    cat /proc/swaps                                                            # 查看当前 swap 的使用情况
    swapoff /swap/swapfile                                                     # 关闭相应的 swap_disk_name
    rm /swap/swapfile                                                          # 删除 swapfile 文件
    /swap/swapfile swap swap defaults 0 0                                      # vim 编辑器打开 /etc/fstab，删除此内容
    
    cd /tmp/                                                                   # 进入根路径
    dd if=/dev/zero of=/tmp/swap bs=1M count=16384                             # 创建虚拟内存文件
    chmod 600 /tmp/swap                                                        # 给文件添加授权
    du -sh /tmp/swap                                                           # 查看 swap 文件
    mkswap /tmp/swap                                                           # 将目标设置为 swap 分区文件
    swapon /tmp/swap                                                           # 激活 swap 区，并立即启用交换区文件
    free -m                                                                    # 查看Swap 分区
    sysctl vm.swappiness=40                                                    # 临时修改启用虚拟内存时剩余的内存大小
    
    vim /etc/fstab                                                             # vim 编辑器打开 /etc/fstab，添加此如下内容
        /tmp/swap swap swap defaults 0 0
    vim /etc/sysctl.conf                                                       # 永久修改启用虚拟内存时剩余的内存大小
        vm.swappiness=40
```

<br />

## 5. 添加管理员帐号

```bash
    useradd -m issac                                                           # 添加 issac 用户
    passwd --stdin 111111                                                      # 修改 issac 用户的密码为：111111
    
    chmod u+w /etc/sudoers                                                     # 添加可编辑权限
    vim /etc/sudoers                                                           # 给 issac 添加管理员权限，添加如下内容
        issac   ALL=(ALL:ALL)   ALL
    sed -i 's|^root.*|root    ALL=\(ALL\)    ALL\nissac    ALL=\(ALL\)    ALL|g' /etc/sudoers
    chmod u-w /etc/sudoers                                                     # 取消可编辑权限
    
    reboot                                                                     # 重启服务器，并使用 issac 用户登录：shutdown -r now
```

<br />

## 5. 安装必要的软件包

### 5.1 redhat 系列安装必要的软件包

```bash
    sudo dnf install -y epel-release                       # 安装 红帽系 的操作系统提供额外的软件包
    sudo dnf install -y lrzsz                              # 安装 lrzsz 可用于文件传输
    sudo dnf install -y htop                               # 监控服务器
    sudo dnf install -y curl-devel,expat-devel,openssl-devel,gcc,gcc-c++,kernel-devel,pcsc-lite-libs,elfutils-libelf-devel,make,zlib-devel,bzip2-devel,ncurses-devel,sqlite-devel,readline-devel,tk-devel,gdbm-devel,db4-devel,libpcap-devel,xz-devel,libffi-devel,zlib1g-dev,zlib*,git,python3-devel,python3-pip,dos2unix,expect,telnet
```

### 5.2 ubuntu 系列安装必要的软件包

```bash
    sudo apt install -y lrzsz                              # 监控服务器
    sudo apt install -y htop                               # 监控服务器
    sudo apt install -y gcc gcc-c++ kernel-devel pcsc-lite-libs elfutils-libelf-devel make    # 安装编译器
```
