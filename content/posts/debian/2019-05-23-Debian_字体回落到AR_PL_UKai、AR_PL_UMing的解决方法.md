---
layout: post
cid: 457
title: "Debian 字体回落到AR PL UKai、AR PL UMing的解决方法"
slug: 457
date: 2019-05-23
updated: 2019-05-23
status: publish
author: panda
categories: 
  - debian
tags: 
---


Debian现在中文经过社区的不断努力已经解决的很好了，但是Firefox在浏览某些网页中，偶尔会见到不和谐的字体。

比如在这种 [A Brief Introduction to DDD][1] 网页中，在没有CSS规定样式，或者CSS没有规定字体的时候，会显示的很丑。用Firefox的审查元素看了下，字体被回落到了`AR PL UKai`。可能是安装TexLive或者Sougou Pinyin的时候apt自动装上的。

解决办法
1.直接删除
`sudo apt-get remove fonts-arphic-ukai fonts-arphic-uming`
2.如果想保留字体
到/etc/fonts/conf.d中，将含有`fonts-arphic-*`的配置文件全部删除。这些都是软连接，指向`/etc/fonts/conf.avail`，需要用的时候可以重新将`conf.avail/`里的配置链接到`conf.d/`



  [1]: http://knuth.luther.edu/~leekent/tutorials/ddd.html