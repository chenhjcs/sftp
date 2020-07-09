# SFTP

# 提升共享文件系统的安全性

本镜像时基于 atmoz/sftp 镜像，构建的 centos 版本。支持以下功能：

- 将容器 `\data` 目录做为 sftp 的根目录
- 指定用户访问的目录
- 密码加密存储
- 挂载 obs 至文件系统



以下功能未经验证：

- 使用 SSH keys 登陆
- 使用自定义 SSH host key
- Execute custom scripts or applications
- Bindmount dirs from another location

# 用法

- sftp 账号有三种定义方式：(1) 命令参数，(2) `SFTP_USERS` 环境变量，(3)  `/etc/sftp/users.conf` 配置文件。语法: `user:pass[:e][:uid[:gid[:dir1[,dir2]...]]] ...`，具体详见后面实例。
  - 自动创建用户账号和密码
  - 自动创建用户目录，并分配具体的权限
- 指定共享目录：( 默认为：/data)
  - 本项目以 /data 目录为sftp den
  - 想要实现 /home/user/**mounted-directory** 访问效果的是使用被 fork 原始项目。

# 实例演示

## 简单 sftp 运行实例

```bash
docker run -p 20022:22 -d sftp foo:pass:::foo_dir
```

创建 foo 用户 密码为 pass，具有 foo_dir 文件夹完整访问权限。宿主机器使用 20022 端口

## 挂载 obs

```bash
docker run -it -p 20025:22 --privileged=true --name sftp3 \
-e OBS_URL=obs.cn-east-2.myhuaweicloud.com \
-e AK=FHH****************O \
-e SK=0**************************************6 \
-e BUCKET_NAME=bucket-demo \
-e MOUNT_PATH=/obs_data
sftp foo:pass:::foo_dir


docker run -it -p 20025:22 --privileged=true --name sftp3 \
sftp foo:pass:::foo_dir


# 测试时使用 --privileged=true，权限过大，建议使用以下方式：

# 注意rhel上可能还会用到selinux,也可以做一些类似的设置。--device /dev/fuse就是说把host上的/dev/fuse设备挂载到容器中，--cap-add SYS_ADMIN允许容器中运行的进程执行系统管理任务,如挂载/卸载文件系统,设置磁盘配额,开/关交换设备和文件等。

docker run -it --rm --device /dev/fuse --security-opt seccomp:unconfined --cap-add SYS_ADMIN image-registry:5000/ubuntu:16.04-sshfs /bin/bash

# --privileged=true 权限太大，推荐使用以下方式
docker run -it -p 20025:22 --name sftp3 \
--device /dev/fuse --security-opt seccomp:unconfined --cap-add SYS_ADMIN \
-e OBS_URL=obs.cn-east-2.myhuaweicloud.com \
-e AK=FHH****************O \
-e SK=0**************************************6 \
-e BUCKET_NAME=bucket-demo \
sftp foo:pass:::foo_dir

docker run -it -p 20026:22 --name sftp4 \
--device /dev/fuse --cap-add SYS_ADMIN \
-e OBS_URL=obs.cn-east-2.myhuaweicloud.com \
-e AK=FHH****************O \
-e SK=0**************************************6 \
-e BUCKET_NAME=bucket-demo \
sftp foo2:pass:::foo_dir2


docker run -it -p 20025:22 --privileged=true --name sftp3 \
-e OBS_URL=obs.cn-east-2.myhuaweicloud.com \
-e AK=FHH****************O \
-e SK=0**************************************6 \
-e BUCKET_NAME=bucket-demo \
sftp foo3:pass:::foo_dir3
```



## 共享宿主机器上的文件系统

并挂载一个文件系统并设置用户组

```
docker run \
    -v /host/upload:/home/foo/upload \
    -p 2222:22 -d atmoz/sftp \
    foo:pass:1001
```

### 采用 Docker Compose部署

```
sftp:
    image: atmoz/sftp
    volumes:
        - /host/upload:/home/foo/upload
    ports:
        - "2222:22"
    command: foo:pass:1001
```



### 远程登陆命令

 OpenSSH 默认端口 22，本例将容器端口 22 映射至宿主机端口 2222。采用以下命令登陆 sftp:  `sftp -P 2222 foo@<host-ip>`



## FTP 账号存储在配置文件

```
docker run \
    -v /host/users.conf:/etc/sftp/users.conf:ro \
    -v mySftpVolume:/home \
    -p 2222:22 -d atmoz/sftp
```

/host/users.conf:

```
foo:123:1001:100
bar:abc:1002:100
baz:xyz:1003:100
```



## 密码加密存储

在密码后面添加 `:e` 表明密码是加密的，在命令行中使用单引号存放账号信息。

```
docker run \
    -v /host/share:/home/foo/share \
    -p 2222:22 -d atmoz/sftp \
    'foo:$1$0G2g0GSt$ewU0t6GXG15.0hWoOX8X9.:e:1001'
```

TIP: 你可以使用 [atmoz/makepasswd](https://hub.docker.com/r/atmoz/makepasswd/) 生成加密密码  
`echo -n "your-password" | docker run -i --rm atmoz/makepasswd --crypt-md5 --clearfrom=-`

在centos 中可以使用 openssl passwd 命令生成加密密码。

```bash
openssl passwd -1 "your-password"
```



## 使用 SSH keys 登陆

Mount public keys in the user's `.ssh/keys/` directory. All keys are automatically appended to `.ssh/authorized_keys` (you can't mount this file directly, because OpenSSH requires limited file permissions). In this example, we do not provide any password, so the user `foo` can only login with his SSH key.

```
docker run \
    -v /host/id_rsa.pub:/home/foo/.ssh/keys/id_rsa.pub:ro \
    -v /host/id_other.pub:/home/foo/.ssh/keys/id_other.pub:ro \
    -v /host/share:/home/foo/share \
    -p 2222:22 -d atmoz/sftp \
    foo::1001
```

## 使用自定义 SSH host key

新建容器时会创建新的SSH host key，容器重新创建生成新的 host key，用户继续访问 sftp 服务时会产生 MITM warning，需要进入`~/.ssh/known_hosts`  文件将已信任的 host key 删除。建议用户自己生成 host key 文件，并挂载至容器。

```
docker run \
    -v /host/ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key \
    -v /host/ssh_host_rsa_key:/etc/ssh/ssh_host_rsa_key \
    -v /host/share:/home/foo/share \
    -p 2222:22 -d atmoz/sftp \
    foo::1001
```

Tip: 生成 host key 命令如下

```
ssh-keygen -t ed25519 -f ssh_host_ed25519_key < /dev/null
ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key < /dev/null
```

## Execute custom scripts or applications

Put your programs in `/etc/sftp.d/` and it will automatically run when the container starts.
See next section for an example.

## Bindmount dirs from another location

If you are using `--volumes-from` or just want to make a custom directory available in user's home directory, you can add a script to `/etc/sftp.d/` that bindmounts after container starts.

```
#!/bin/bash
# File mounted as: /etc/sftp.d/bindmount.sh
# Just an example (make your own)

function bindmount() {
    if [ -d "$1" ]; then
        mkdir -p "$2"
    fi
    mount --bind $3 "$1" "$2"
}

# Remember permissions, you may have to fix them:
# chown -R :users /data/common

bindmount /data/admin-tools /home/admin/tools
bindmount /data/common /home/dave/common
bindmount /data/common /home/peter/common
bindmount /data/docs /home/peter/docs --read-only
```

**NOTE:** Using `mount` requires that your container runs with the `CAP_SYS_ADMIN` capability turned on. [See this answer for more information](https://github.com/atmoz/sftp/issues/60#issuecomment-332909232).


