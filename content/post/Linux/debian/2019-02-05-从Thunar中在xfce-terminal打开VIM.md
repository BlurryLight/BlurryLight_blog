---
layout: post
cid: 437
title: "从Thunar中在xfce-terminal打开VIM"
slug: 437
date: 2019-02-05
updated: 2019-02-05
status: publish
author: panda
categories: 
  - linux
tags: 
---


VIM在xfce的默认设置中,如果用图形化调用,则是默认打开Xterm来显示,Xterm显示效果比xfce-terminal效果差很多.


<!--more-->

所以可以修改thunar调用vim的方式.
打开`/usr/share/applications/vim.desktop`
找到`Exec`行,改成
`Exec=xfce4-terminal -e "vim %F"`
然后把下一行的`terminal`从`true`改成`false`.

