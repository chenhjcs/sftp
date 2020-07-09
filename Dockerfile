###################################################################################################
# version : chenhuajie/obssftp:v1
# desc : 在CentOS Linux release 7 (Core)官方版本安装 sftp 服务端和 Huawei obs 客户端软件。
###################################################################################################

FROM centos:7
MAINTAINER chenhuajie "chenhuajie@deri.energy"

RUN yum -y update
RUN yum install -y passwd openssl openssh-server
RUN yum install -y openssl-devel fuse fuse-devel compat-openssl10-1

RUN sed -i "s/UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ''
RUN ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''
RUN ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
RUN mkdir -p /var/run/sshd

WORKDIR /root
ADD files/obsfs_CentOS7.6_amd64.tar.gz .
ADD files/mount_obs /usr/local/bin/


COPY files/sshd_config /etc/ssh/sshd_config
COPY files/create-sftp-user /usr/local/bin/
COPY files/entrypoint /

EXPOSE 22

ENTRYPOINT ["/entrypoint"]
