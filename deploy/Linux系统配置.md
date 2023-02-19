## 1. 修改 yum / dnf 或 apt 源

### 1.1 ubuntu 修改 阿里镜像源

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

### 1.2 centos7 修改 阿里镜像源

```bash
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
    wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    
    yum makecache
    dnf clean all
    yum update
    yum upgrade
```

### 1.3 rocky8 和 rocky9 修改 阿里镜像源

```bash 
    # rocky8
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=https://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
        -i.bak \
        /etc/yum.repos.d/[Rr]ocky-*.repo
    
    # rocky9
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
        -i.bak \
        /etc/yum.repos.d/[Rr]ocky-*.repo
    
    dnf clean all
    dnf makecache
    dnf update
    dnf upgrade
```

### 1.3 almalinux9 修改 阿里镜像源

```bash
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
          -e 's|^# baseurl=https://repo.almalinux.org|baseurl=https://mirrors.aliyun.com|g' \
          -i.bak \
          /etc/yum.repos.d/almalinux*.repo
    
    dnf clean all
    dnf makecache  
    dnf update
    dnf upgrade
```


## 2. 修改主机名称

```bash
    hostname                                               # 查看当前系统的主机名
    hostname master                                        # 临时修改主机名，会话关闭失效
    hostnamectl set-hostname master                        # 永久修改主机名（重启生效）
    vim /etc/hostname                                      # 修改主机名（重启生效）
```


## 3. 修改 hosts 映射

```bash
    vim /etc/hosts ==> 192.168.100.10      master          # 方法 1
     echo "192.168.100.100      master"  >> /etc/hosts     # master
     echo "192.168.100.111      slaver1" >> /etc/hosts     # slaver1
     echo "192.168.100.122      slaver2" >> /etc/hosts     # slaver2
     echo "192.168.100.133      slaver3" >> /etc/hosts     # slaver3
     
     echo "127.0.0.1            issac"   >> /etc/hosts     # issac
     echo "127.0.0.1            unix"    >> /etc/hosts     # ubuntu
     echo "127.0.0.1            linux"   >> /etc/hosts     # linux
     echo "127.0.0.1            centos"  >> /etc/hosts     # centos
     echo "127.0.0.1            ubuntu"  >> /etc/hosts     # ubuntu
     echo "127.0.0.1            unix"    >> /etc/hosts     # unix
     echo "127.0.0.1            hadoop"  >> /etc/hosts     # hadoop
     echo "127.0.0.1            spark"   >> /etc/hosts     # spark
     echo "127.0.0.1            flink"   >> /etc/hosts     # flink
     echo "127.0.0.1            elastic" >> /etc/hosts     # elastic
```


## 4. 关闭防火墙

```bash
    # start：开启防火墙；stop：关闭防火墙；status：查看状态；enable：开机自启；disable：关闭开机自启
    systemctl status  firewalld.service                    # 查看防火墙状态，或者： firewall-cmd --state             
    systemctl stop    firewalld.service                    # 关闭防火墙
    systemctl disable firewalld.service                    # 关闭防火墙开机自启
```


## 5. 关闭 selinux

```bash
    sudo apt install policycoreutils                                           # ubuntu 安装策略包
    sudo yum install policycoreutils                                           # redhat 安装策略包
    sestatus                                                                   # 检查系统 SELinux 状态
    setenforce 0                                                               # 临时禁用 SELinux，或者：setenforce Permissive
    vim /etc/sysconfig/selinux                                                 # 编辑 SELinux 配置文件
        SELinux=disabled                                                       # 注释 SELinux=enforcing，需要重启系统
    sestatus                                                                   # 检查系统 SELinux 状态
```


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
    sudo echo "65536" >> /proc/sys/fs/file-max                                 # 
```

### 6.3 优化内核：/etc/sysctl.conf

```bash
    # 编辑配置文件，添加如下内容
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

### 6.4 


## 7. 添加管理员帐号

```bash
    useradd -m issac                                       # 添加 issac 用户
    passwd issac                                           # 添加 issac 用户的密码：111111
    vim /etc/sudoers                                       # 给 issac 添加管理员权限，添加如下内容
        issac    ALL=(ALL:ALL) ALL         
```


## 8. 安装必要的软件包

### 8.1 redhat 系列安装必要的软件包

```bash
    # redhat 系列
    sudo yum install -y lrzsz                              # 安装 lrzsz 可用于文件传输
    sudo yum install -y binutils compat-libcap1 compat-libstdc++-33 compat-libstdc++-33*i686 compat-libstdc++-33*.devel compat-libstdc++-33 compat-libstdc++-33*.devel gcc gcc-c++ glibc glibc*.i686 glibc-devel glibc-devel*.i686 ksh libaio libaio*.i686 libaio-devel libaio-devel*.devel libgcc libgcc*.i686 libstdc++ libstdc++*.i686 libstdc++-devel libstdc++-devel*.devel libXi libXi*.i686 libXtst libXtst*.i686 make sysstat unixODBC unixODBC*.i686 unixODBC-devel unixODBC-devel*.i686
    sudo yum install -y htop                               # 监控服务器
    sudo yum install -y curl-devel expat-devel openssl-devel gcc gcc-c++ kernel-devel pcsc-lite-libs elfutils-libelf-devel make    # 安装编译器
```

### 8.2 debian 系列安装必要的软件包

```bash
    # 
    sudo apt install -y lrzsz                              # 监控服务器
    sudo apt install -y gcc gcc-c++ kernel-devel pcsc-lite-libs elfutils-libelf-devel make    # 安装编译器
```

