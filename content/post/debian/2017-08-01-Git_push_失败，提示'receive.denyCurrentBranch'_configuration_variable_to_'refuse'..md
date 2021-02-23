---
layout: post
cid: 420
title: "Git push 失败，提示'receive.denyCurrentBranch' configuration variable to 'refuse'."
slug: 420
date: 2017-08-01
updated: 2017-08-01
status: publish
author: panda
categories: 
  - linux
tags: 
---


>在VPS上新建了一个Git仓库，本地开发测试完了以后直接通过Git Push上去，不用SCP传了

但是却提示`remote: error: 'receive.denyCurrentBranch' configuration variable to 'refuse'.`
查了一下，这是Git新建了仓库以后默认不允许push操作

可以使用
```bash
git config receive.denyCurrentBranch=ignore
```
即可解决