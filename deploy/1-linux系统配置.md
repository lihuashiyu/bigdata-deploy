## 1. 修改 yum/dnf 或 apt 源（需要使用 root 权限）

### 1.1 debian 11/ubuntu（20.* 22.*）修改 阿里镜像源
```bash
    cp  /etc/apt/sources.list  /etc/apt/sources.list.bak
    
    deb https://mirrors.aliyun.com/debian/ bullseye main non-free contrib
    deb-src https://mirrors.aliyun.com/debian/ bullseye main non-free contrib
    
    deb https://mirrors.aliyun.com/debian-security/ bullseye-security main
    deb-src https://mirrors.aliyun.com/debian-security/ bullseye-security main
    
    deb https://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib
    deb-src https://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib
    
    deb https://mirrors.aliyun.com/debian/ bullseye-backports main non-free contrib
    deb-src https://mirrors.aliyun.com/debian/ bullseye-backports main non-free contrib
    
    deb http://mirrors.aliyun.com/debian-security/ squeeze/updates main non-free contrib
    deb-src http://mirrors.aliyun.com/debian-security/ squeeze/updates main non-free contrib
```

### 1.2 ubuntu（20.* 22.*）修改 阿里镜像源

```bash
    cp  /etc/apt/sources.list  /etc/apt/sources.list.bak
    
    sed -i 's/https:\/\/mirrors.aliyun.com/http:\/\/mirrors.cloud.aliyuncs.com/g' /etc/apt/sources.list
    
    deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
    deb-src https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
    
    deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
    deb-src https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
    
    deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
    deb-src https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
    
    # deb https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
    # deb-src https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
    
    deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
    deb-src https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
    
    apt clean all
    apt update
    apt upgrade
```

### 1.3 centos 7 系列修改 阿里镜像源

```bash
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
    wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    
    yum clean all
    yum makecache
    yum update
    yum upgrade
```

### 1.4 rocky 8/9 系列修改 阿里镜像源

```bash
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=https://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' -i.bak /etc/yum.repos.d/[Rr]ocky-*.repo
    
    dnf clean all
    dnf makecache
    dnf update
    dnf upgrade
```

### 1.5 almalinux 8/9 修改 阿里镜像源

```bash
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^# baseurl=https://repo.almalinux.org|baseurl=https://mirrors.aliyun.com|g' -i.bak /etc/yum.repos.d/almalinux*.repo
    
    dnf clean all
    dnf makecache  
    dnf update
    dnf upgrade
```

<br />

## 2. 修改主机名称

```bash
    hostname                                               # 查看当前系统的主机名
    hostname master                                        # 临时修改主机名为 master，会话关闭失效
    hostnamectl set-hostname master                        # 永久修改主机名为 master（重启生效）
    vim /etc/hostname                                      # 永久修改主机名为 master（重启生效）
```

<br />

## 3. 修改 hosts 映射

```bash
    # 方法一：vim 编辑器进行修改
    vim /etc/hosts                                         # 使用 vim 编辑器添加如下内容
        192.168.100.10      master
    
    # 方法二：使用重定向追加模式
    echo "192.168.100.100      master"  >> /etc/hosts      # master
    echo "192.168.100.111      slaver1" >> /etc/hosts      # slaver1
    echo "192.168.100.122      slaver2" >> /etc/hosts      # slaver2
    echo "192.168.100.133      slaver3" >> /etc/hosts      # slaver3
    
    # 以下内容适量添加
    echo "127.0.0.1            unix"    >> /etc/hosts      # unix
    echo "127.0.0.1            linux"   >> /etc/hosts      # linux
    echo "127.0.0.1            rocky"   >> /etc/hosts      # rocky
    echo "127.0.0.1            elastic" >> /etc/hosts      # elastic
```

<br />

## 4. 关闭防火墙

```bash
    # start：开启防火墙；stop：关闭防火墙；status：查看状态；enable：开机自启；disable：关闭开机自启
    systemctl status  firewalld.service                    # 查看防火墙状态，或者：firewall-cmd --state
    systemctl stop    firewalld.service                    # 关闭防火墙
    systemctl disable firewalld.service                    # 关闭防火墙开机自启
    
    # 将如下 ip 添加到防火墙（如果必须开启防火墙）
    firewall-cmd --permanent --add-source=192.168.100.100  # 添加到防火墙白名单
    firewall-cmd --permanent --add-source=192.168.100.111  # 添加到防火墙白名单
    firewall-cmd --permanent --add-source=192.168.100.122  # 添加到防火墙白名单
    firewall-cmd --permanent --add-source=192.168.100.133  # 添加到防火墙白名单
```

<br />

## 5. 关闭 selinux

```bash
    sudo apt install policycoreutils                       # ubuntu 安装策略包
    sudo yum install policycoreutils                       # redhat 安装策略包
    sestatus                                               # 检查系统 SELinux 状态
    setenforce 0                                           # 临时禁用 SELinux，或者：setenforce Permissive
    vim /etc/sysconfig/selinux                             # 编辑 SELinux 配置文件（需要重启系统）
        SELinux=disabled                                   # 注释 SELinux=enforcing，或命令：sed -i 's/SELinux=enforcing/SELinux=disabled/g' /etc/sysconfig/selinux
    sestatus                                               # 检查系统 SELinux 状态
```

<br />

## 6. 修改系统限制

### 6.1 修改打开文件限制：etc/security/limits.conf

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

### 6.2 修改 /proc/sys/fs/file-max

```bash
    vim  /proc/sys/fs/file-max
    sudo echo "65536" >> /proc/sys/fs/file-max                                 # 系统限制的文件最大值
```

### 6.3 优化内核：/etc/sysctl.conf

```bash
    # 编辑配置文件，添加如下内容（注意，部分系统会导致重启报错）
    vm.max_map_count             = 655360
    kernel.shmmni                = 4096               # 这个内核参数用于设置系统范围内共享内存段的最大数量，该参数的默认值是 4096
    kernel.shmmax                = 2147483648         # 该参数定义了共享内存段的最大尺寸（以字节为单位），缺省为 32M
    kernel.shmall                = 2097152            # 该参数表示系统一次可以使用的共享内存总量（以页为单位），缺省值就是2097152，通常不需要修改。
    kernel.sem                   = 250 32000 100 128 
    fs.aio-max-nr                = 1048576
    fs.file-max                  = 65536              # 设置最大打开文件数
    fs.nr_open                   = 196680    
    vm.swappiness                = 40                 # 内存剩余 40% 的时候，开始使用虚拟内存
    net.ipv4.ip_local_port_range = 1024 65536         # 可使用的IPv4端口范围
    net.core.rmem_max            = 16777216
    net.core.wmem_max            = 16777216
    net.ipv4.tcp_rmem            = 4096 87380 16777216
    net.ipv4.tcp_wmem            = 4096 65536 16777216
    net.ipv4.tcp_fin_timeout     = 10
    net.ipv4.tcp_tw_recycle      = 1
    net.ipv4.tcp_timestamps      = 0
    net.ipv4.tcp_window_scaling  = 0
    net.ipv4.tcp_sack            = 0
    net.core.netdev_max_backlog  = 30000
    net.ipv4.tcp_no_metrics_save = 1
    net.core.somaxconn           = 22144
    net.ipv4.tcp_syncookies      = 0
    net.ipv4.tcp_max_orphans     = 262144
    net.ipv4.tcp_max_syn_backlog = 262144
    net.ipv4.tcp_synack_retries  = 2
    net.ipv4.tcp_syn_retries     = 2
    net.core.rmem_default        = 262144
    net.core.wmem_default        = 262144
    vm.overcommit_memory         = 1
```

### 6.4 设置虚拟内存

```bash
    swapon -s                                              # 查看当前 swap 的使用情况
    cat /proc/swaps                                        # 查看当前 swap 的使用情况
    swapoff /swap/swapfile                                 # 关闭相应的 swap_disk_name
    rm /swap/swapfile                                      # 删除 swapfile 文件
    /swap/swapfile swap swap defaults 0 0                  # vim 编辑器打开 /etc/fstab，删除此内容
    
    cd /tmp/                                               # 进入根路径
    dd if=/dev/zero of=/tmp/swap bs=1M count=16384         # 创建虚拟内存文件
    chmod 600 /tmp/swap                                    # 给文件添加授权
    du -sh /tmp/swap                                       # 查看 swap 文件
    mkswap /tmp/swap                                       # 将目标设置为 swap 分区文件
    swapon /tmp/swap                                       # 激活 swap 区，并立即启用交换区文件
    free -m                                                # 查看Swap 分区
    sysctl vm.swappiness=10                                # 临时修改启用虚拟内存时剩余的内存大小
    vim /etc/fstab                                         # vim 编辑器打开 /etc/fstab，添加此如下内容
        /tmp/swap swap swap defaults 0 0
    vim /etc/sysctl.conf                                   # 永久修改启用虚拟内存时剩余的内存大小，添加此如下内容
        vm.swappiness=25
```

<br />

## 7. 添加管理员帐号

```bash
    useradd -m issac                                       # 添加 issac 用户
    chmod u+w /etc/sudoers                                 # 添加可编辑权限
    vim /etc/sudoers                                       # 给 issac 添加管理员权限，添加如下内容
        issac   ALL=(ALL:ALL)   ALL
    chmod u-w /etc/sudoers                                 # 取消可编辑权限
    root                                                   # 重启服务器，并使用 issac 用户登录：shutdown -r now
```

<br />

## 8. 安装必要的软件包

### 8.1 redhat 系列安装必要的软件包

```bash
    sudo dnf install -y epel-release                       # 安装 红帽系 的操作系统提供额外的软件包
    sudo dnf install -y lrzsz                              # 安装 lrzsz 可用于文件传输
    sudo dnf install -y htop                               # 监控服务器
    sudo dnf install -y curl-devel expat-devel openssl-devel gcc gcc-c++ kernel-devel pcsc-lite-libs elfutils-libelf-devel make    # 安装编译器
```

### 8.2 ubuntu 系列安装必要的软件包

```bash
    sudo apt install -y lrzsz                              # 监控服务器
    sudo apt install -y htop                               # 监控服务器
    sudo apt install -y gcc gcc-c++ kernel-devel pcsc-lite-libs elfutils-libelf-devel make    # 安装编译器
```
