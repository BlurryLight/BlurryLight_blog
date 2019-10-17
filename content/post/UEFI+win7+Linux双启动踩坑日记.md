
--- 
title: "UEFI+win7+Linux双启动踩坑日记"
date: 2019-10-17T13:40:01+08:00
draft: false
# tags: [ "" ]
categories: [ "默认分类"]
# keywords: [ ""]
lastmod: 2019-10-17T13:40:01+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "UEFI+win7+Linux双启动踩坑日记"
toc: true
---
# 启动黑屏

在服务器上装了一个Ubuntu server，安装盘启动黑屏，其实就应该想到是驱动有问题，因为服务器的显卡是Quadro M4000,但是没有想那块去，排查了一段时间以后才想起来我之前的笔记本也出现过启动黑屏。
在grub的启动菜单时，按e进入编辑模式，在boot一栏加入`nomodeset`，成功启动。

进入系统以后，可以编辑`/etc/default/grub`,修改`GRUB_CMDLINE_LINUX_DEFAULT`一栏，一般这里有`ro quiet`等参数，加入`nomodeset`以后，启动就没问题了。

# windows覆盖grub问题

重点想谈谈这个，以前用MBR的时候还没有发现windows这么蠢，后来发现换成UEFI以后，windows更霸道了，强制覆盖grub不说，MBR时代的时候也覆盖，用Live CD修一下就消停了，UEFI重启一次就覆盖一次，有点意思。

查了一下Ubuntu的论坛，刚好有人提到如何解决启动项被覆盖的方法。

## 第一种 修改Windows BCD 来让Ubuntu默认启动
```
bcdedit /set {bootmgr} path \EFI\ubuntu\grubx64.efi
```
powershell里面{bootmgr}要加引号括起来

## 第二种 修改windows的启动项指向的EFI文件
```
with efibootmgr's default of sda1 for ESP, additional parameters required if not sda1:
sudo efibootmgr -c -L "Windows Boot Manager" -l "\EFI\ubuntu\shimx64.efi"
If you have Windows to restore Windows boot entry:
sudo efibootmgr -c -L "Windows Boot Manager" -l "\EFI\Microsoft\Boot\bootmgfw.efi"
```

## 第三种 替换windows的EFI(不推荐)
上面那种方式的变种，但是windows升级可能会重新覆盖efi，有点麻烦
```
mountvol z: /s  #映射ESP分区到Z盘
用管理员权限打开explorer或者用管理员命令行 备份\EFI\Microsoft\Boot\bootmgfw.efi,然后吧\EFI\ubuntu\grubx64.efi复制过去，重命名为bootmgfw.efi
mountvol z: /d  #结束映射
```

## 第四种 新建一个UEFI启动项(Most Recommended)
```
# if your ESP is not sda1 change this to correct partition
sudo mount /dev/sda1 /mnt
only if /EFI/Boot not already existing, run the mkdir command,
sudo mkdir /mnt/EFI/Boot
sudo cp /mnt/EFI/ubuntu/* /mnt/EFI/Boot
# If new folder created, the bootx64.efi will not exist, skip backup command
sudo mv /mnt/EFI/Boot/bootx64.efi /mnt/EFI/Boot/bootx64.efi.backup
# make grub be hard drive boot entry in UEFI. Then boot hard drive entry in UEFI menu.
sudo mv /mnt/EFI/Boot/grubx64.efi /mnt/EFI/Boot/bootx64.efi
# You may need new hard drive entry (uses default of sda1 for ESP):
sudo efibootmgr -c -L "UEFI Hard drive" -l "\EFI\Boot\bootx64.efi"
# if not sda1 you must specify drive X with -d and partition Y with - p , see also man efibootmgr
sudo efibootmgr -c -g -d /dev/sdX -p Y -w -L "UEFI hard drive" -l '\EFI\Boot\bootx64.efi'
```

参考来源:https://ubuntuforums.org/showthread.php?t=2147295