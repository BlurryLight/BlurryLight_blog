---
layout: post
cid: 423
title: "Debian利用Squid3搭建Pac代理，端口25"
slug: 423
date: 2017-08-12
updated: 2018-12-19
status: hidden
author: panda
categories: 
  - linux
tags: 
  - panda
---


虽然平时都是用shadowsocks，但是偶尔在没有条件的时候也会用到Pac来救急（通常是在我的chromebook上）,在网上找PAC不是个办法（也不安全），于是就萌生了搭建个PAC的想法。
顺着代码来，一行行复制
`Debian`
```bash
sudo apt install squid3
curl www.cutinlove.com/squid.conf > /etc/squid3/squid.conf
mkdir -p /var/cache/squid
chmod -R 777 /var/cache/squid
service squid3 stop
squid3 -z
service squid3 restart
```
这样`squid3`的服务就搭建完了，接下来只需要配置上pac就好了
可以直接下载到本地,将第一行的地址填上服务器的IP
`https://raw.githubusercontent.com/rptec/squid-PAC/master/1.pac`

也可以在服务端的网站可访问的目录配置好PAC，直接填上网站路径的PAC就可以了

如果不能正常工作，请在防火墙将25端口放行，或者检查VPS提供商是否封杀了25端口（25端口是电子邮件端口，部分VPS商为了防止垃圾邮件封杀了）