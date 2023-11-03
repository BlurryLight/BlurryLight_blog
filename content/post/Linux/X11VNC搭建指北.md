
---
title: "X11VNC搭建指北"
date: 2019-11-30T13:10:51+08:00
draft: false
# tags: [ "" ]
categories: [ "Linux"]
# keywords: [ ""]
lastmod: 2019-11-30T13:10:51+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "X11VNC搭建指北"
toc: true
---

`vnc`作为开源协议，实现的有很多，包括出名的`realVNC`,`tightVNC`以及它的fork `tigerVNC`，不同的vnc后端也不少，主要分为另起一个x和直接获取当前的x画面两种。

我的需求是从外网穿透学校的防火墙以及路由器NAT，访问位于实验室的笔记本，并且监视一些还没有完成的工作，所以我需要 1.穿透内网 2.获取当前的X画面
穿透内网的部分frp很好配置，而x11vnc配置起来要花点功夫，主要是在`systemed`中配置起来有点麻烦。

## 生成密码

`x11vnc -storepasswd`
生成后的密码默认在家目录，如果有root权限可以拷贝到/etc/下，这样方便systemd读取

## x11vnc的systemed配置

主要注意两点:

 - xfce4使用的dm是lightdm，所以要从/var/run/lightdm/root/:0中获取权限
 - 配置shared和forever,以允许多个vnc viewer访问
 - 不要开ncache,会导致不支持的客户端，比如手机上的realvnc客户端，获取到错误的分辨率
 - 要加`-repeat`标签，否则无法连续输入多个按键
 
```bash
[Unit]
Description=VNC Server for X11
Requires=display-manager.service

[Service]
ExecStart=/usr/bin/x11vnc -repeat -display :0 -auth /var/run/lightdm/root/:0  -rfbauth /etc/x11vnc.pwd -shared -forever -o /var/log/x11vnc.log
ExecStop=/usr/bin/x11vnc -R stop
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```


### 疑难杂症

* 在xfce4下x11vnc响应有个两三秒的延迟

> 参考：[How to get rid of the 3 second delay ? · Issue #102 · LibVNC/x11vnc](https://github.com/LibVNC/x11vnc/issues/102)
> 参考：[15927 – x11vnc is very laggy due to commit 8fbff6ce0c097897a1f909dd02f72f4160f23d99](https://bugzilla.xfce.org/show_bug.cgi?id=15927)

关闭xfce4的垂直同步(会重启xfce4)
```
xfconf-query -c xfwm4 -p /general/vblank_mode -s off ; pkill xfwm4$
```


* 在xfce4下笔记本合盖x11vnc失去响应

`xfce4-screensaver`和`x11vnc`有冲突。
可以换其他的锁屏软件。

```bash
ps -ef | grep -E 'saver|lock' | more  // 找到xfce4-screensaver的pid, kill掉
sudo apt remove xfce4-screensaver
```