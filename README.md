# 微服务应用的服务注册指南

## 1. 概述

该指南可以微服务应用在 DCE 上部署的最佳实践。

## 2. 解决的问题
1. 当容器运行的时候，会获得一个内部IP地址，外部无法访问
2. 当使用类似 MACVLAN 之类的技术的时候，一个容器会有多个IP地址，应用不知道使用哪个
3. 当使用类似端口映射之类的技术的时候，容器不能获得外部端口，也不能获得主机IP

## 3. 解决方案
基于 **预设环境变量** 的方式，用户仅仅需要统一使用我们提供的插件，即可以统一化的获得正确的IP地址

## 4. 解决原理
在启动镜像和具体应用之中，加入我们的插件，可以在运行应用之前设置固定的环境变量供应用使用

标准环境变量列表：

- DCE\_ADVERTISE\_IP=172.31.60.44 # 在MacVlan下是MacVlan IP，在Port Mapping下是host IP
- DCE\_ADVERTISE\_PORT=30004 # 在Port Mapping下是host 端口映射
- DCE\_ADVERTISE\_PORT\_3306=30005 # 当Port Mapping 有多个端口的时候，每个端口都有环境变量


## 5. 环境需求
> DCE管理员阅读

1. MACVLAN的方式无需任何改变
2. Port-Mapping，需要安装 metadata 插件

```bash
docker service create --name dce-metadata-agent --mode global   --mount type=bind,src=/var/run,dst=/var/run -l io.daocloud.dce.system=build-in daocloud.io/daocloud/dce-metadata-agent 
```

## 6. 插件使用
本插件是单一二进制文件 dce-app-entrypoint

执行 ./dce-app-entrypoint --help 可以获得其帮助说明

```bash
Usage of ./dce-app-entrypoint:
  -failure string
        Set failure action: exit | continue. The env variable is DAE_FAILURE. (default "exit")
        此参数决定本程序运行失败之后，具体的应用是否继续启动，默认是 exit，可以设置为 continue。如果采取环境变量传入此参数，请使用 DAE_FAILURE 作为 KEY。
  -network string
        Set network mode: port | mac. The env variable is DAE_NETWORK. (default "mac")
        此参数决定本程序运行的网络模式，默认是 mac，可以设置为 port。如果采取环境变量传入此参数，请使用 DAE_NETWORK 作为 KEY。
  -output string
        Set output file. If set this value, please source output.file. The env variable is DAE_OUTPUT.
        此参数决定本程序运行的输出文件。如果设置此参数，具体的应用将不由本程序启动，且在具体的应用启动之前需要手动 source 此输出文件来载入环境变量。如果采取环境变量传入此参数，请使用 DAE_OUTPUT 作为KEY。
  -segment string
        Set the segment regexp pattern. The env variable is DAE_SEGMENT. (only useful in mac mode)
        此参数决定本程序在 MACVLAN 网络模式下，查找 IP 的网段正则表达式。如果采取环境变量传入此参数，请使用 DAE_SEGMENT 作为 KEY。
  -timeout int
        Maximum time to allow the program to run. The env variable is DAE_TIMEOUT. (only useful in mac mode)(default 20)
        此参数决定本程序在 MACVlAN 网络模式下，查找 IP 的超时时间。如果采取环境变量传入此参数请使用 DAE_TIMEOUT 作为 KEY。
```


## 7. 开发使用说明
支持所有应用，支持 MACVlAN 网络和 Port-Mapping 网络，使用步骤分以下三步：

1. 修改程序
2. 打包镜像
3. 部署调试


### 7.1 修改程序
本章节针对不同的应用提供不同的文档，详细见下文

#### 7.1.1 Spring程序
Spring的启动yaml文件中修改为

```yaml
eureka:
  instance:
    ip-address: ${DCE_ADVERTISE_IP}
    prefer-ip-address: true
```

#### 7.1.2 普通Java程序 & 普通程序
获得环境变量 ${DCE\_ADVERTISE\_IP} 作为本机IP


### 7.2 打包镜像
基于本软件的使用方式，提供2种打包镜像的方式

1. 由本软件启动用户的应用
2. 用户自己启动应用不过需要手动source环境变量

#### 7.2.1 插件启动

```bash
FROM centos

COPY dce-app-entrypoint /work/dce-app-entrypoint
COPY echo.sh /work/echo.sh

ENV DAE_NETWORK='mac'
ENV DAE_SEGMENT='^172\.17\.\d{1,3}.\d{1,3}$'

ENTRYPOINT ["/work/dce-app-entrypoint"]
CMD ["sh" , "/work/echo.sh"]
```

执行启动：
注意:  
1、以上DAE_SEGMENT参数需要根据具体情况选择网段。
2、如果使用 port 模式，需要将 /var/run/dce-metadata 挂入镜像。
```bash
docker build . -t. dce-app-entrypoint-sample
docker run -it -p 8082:8082 -v /var/run/dce-metadata:/var/run/dce-metadata dce-app-entrypoint-sample
```


#### 7.2.2 非插件启动

```bash
FROM centos

COPY dce-app-entrypoint /work/dce-app-entrypoint
COPY echo.sh /work/echo.sh

ENV DAE_NETWORK='mac'
ENV DAE_SEGMENT='^172\.17\.\d{1,3}.\d{1,3}$'
ENV DAE_OUTPUT='/tmp/env.sh'

CMD /work/dce-app-entrypoint && source /tmp/env.sh && /work/echo.sh
```

### 7.3 部署调试

在运行的过程中插件会打印详尽的日志，以供调试，如在MACVLAN 模式下日志如下：

```bash
DCE-APP-ENTRY-POINT 2017/06/16 09:41:04 network: [ mac ], timeout: [ 20 ], failure: [ exit ], segment: [ ^172\.17\.\d{1,3}.\d{1,3}$ ]
DCE-APP-ENTRY-POINT 2017/06/16 09:41:04 try set env in MACVLAN network
DCE-APP-ENTRY-POINT 2017/06/16 09:41:04 find ip address 127.0.0.1 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:04 find ip address ::1 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:04 find ip address 172.17.0.2 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:04 find ip address fe80::42:acff:fe11:2 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:09 try set env in MACVLAN network again
DCE-APP-ENTRY-POINT 2017/06/16 09:41:09 find ip address 127.0.0.1 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:09 find ip address ::1 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:09 find ip address 172.17.0.2 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:09 find ip address fe80::42:acff:fe11:2 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:14 try set env in MACVLAN network again
DCE-APP-ENTRY-POINT 2017/06/16 09:41:14 find ip address 127.0.0.1 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:14 find ip address ::1 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:14 find ip address 172.17.0.2 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:14 find ip address fe80::42:acff:fe11:2 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:19 try set env in MACVLAN network again
DCE-APP-ENTRY-POINT 2017/06/16 09:41:19 find ip address 127.0.0.1 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:19 find ip address ::1 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:19 find ip address 172.17.0.2 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:19 find ip address fe80::42:acff:fe11:2 , but not matched
DCE-APP-ENTRY-POINT 2017/06/16 09:41:24 try set env in MACVLAN network again
DCE-APP-ENTRY-POINT 2017/06/16 09:41:24 timeout can't get macvlan ip...
```
第一行是启动的参数，首先保证参数的正确性。每一次等待寻找IP都会提供详尽的日志。

#### 7.3.1 插件启动
在插件启动方式，在代码真正运行之间可以看见如下日志：

```bash
DCE-APP-ENTRY-POINT 2017/06/16 09:29:56 network: [ mac ], timeout: [ 20 ], failure: [ exit ], segment: [ ^172\.17\.\d{1,3}.\d{1,3}$ ]
DCE-APP-ENTRY-POINT 2017/06/16 09:29:56 try set env in MACVLAN network
DCE-APP-ENTRY-POINT 2017/06/16 09:29:56 find ip [ 172.17.0.2 ]
DCE-APP-ENTRY-POINT 2017/06/16 09:29:56 set DCE_ADVERTISE_IP to [ 172.17.0.2 ]
DCE-APP-ENTRY-POINT 2017/06/16 09:29:56 command [ sh ], args [/work/echo.sh] ,
    Environ [PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOSTNAME=876e5f8457d2 DAE_NETWORK=mac DAE_SEGMENT=^172\.17\.\d{1,3}.\d{1,3}$ HOME=/root DCE_ADVERTISE_IP=172.17.0.2]
172.17.0.2

```
最后一行会打印出所有传入程序的环境变量，确保变量的正确性。

#### 7.3.2 非插件启动
在 ENV 配置的 DAE\_OUTPUT 的输出文件中可以看见所有的环境变量。检查此文件可以确保变量的正确性。


## 8. 需要注意的问题

*问题*: 控制台进去执行 env 可能看不到那个 IP 的环境变量, 因为只有 entrypoint 下面(fock 出来)的 cmd 才看得到.

解决: ps axu 找到 java 的 pid , 然后 cat /proc/<pid>/environ 就可以看到 CMD 的环境变量.
