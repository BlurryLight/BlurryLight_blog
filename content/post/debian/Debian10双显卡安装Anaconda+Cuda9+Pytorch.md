
---
title: "Debian10双显卡安装Anaconda+Cuda9+Pytorch"
date: 2019-06-11T16:46:04+08:00
draft: false
# tags: [ "" ]
categories: [ "debian","Python"]
# keywords: [ ""]
lastmod: 2019-06-11T16:46:04+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Debian10双显卡安装Anaconda+Cuda9+Pytorch"
---

在笔记本上搭建Pytorch的环境还算比较麻烦的,我的笔记本带核显和独显，在Linux下配置起来要稍微麻烦点，主要要解决的问题包括三个：

- 在Debian10上安装显卡驱动和cuda，正确驱动独显和核显
- 安装Anaconda管理Python的虚拟环境，避免污染系统默认的Python环境（可以使用Docker替代
- 安装对应版本的Pytorch

## Nvidia驱动的安装

Linux下双显卡驱动是老大难问题了。不外乎三种方案。

1. BIOS直接屏蔽核显，启用独显，装官方的显卡驱动，这种情况最简单，但是独显会一直启用，导致笔记本续航下降。

2. `Nvidia-prime`， 这应该是C社与Nvidia合作的结果。采用`prime-select intel|nvidia`切换独显和核显，缺点是每次切换必须要注销或者重启来使切换生效。

3. `Bumblebee`或`Nvidia xrun`。默认使用集显工作，独显电源被关闭。需要使用独显的时候`optirun/nvidia-xrun application`手动调用独显运行。

优点是无缝调用集显独显，缺点是大黄蜂有性能损失，`Nvidia xrun`比大黄蜂配置更加复杂。

这里选用`Bumblebee`方案，一个是Debian配大黄蜂很快，包管理器直接装就好了，二个是调用cuda计算实际上并不需要`Bumblebee`来运行`cuda`，只需要借用
`Bumblebee`的控制显卡开闭的功能即可，因此理论上(我猜的)不存在性能损失。

安装只需要两条命令

```bash
sudo apt-get install bumblebee-nvidia primus libgl1-nvidia-glx
sudo adduser $USER bumblebee
```

装完后重启即可。如果想要测试`Bumblebee`是否装好，可以用`glxgears`来测试

```bash
sudo apt install mesa-utils
optirun glxgears -info | grep GL_RENDERER
```

如果看到类似**GL_RENDERER   = GeForce GTX 960M/PCIe/SSE2**的输出，就算安装成功了。
`cuda`在debian的包管理器也有，可以直接安装,现在版本源里的cuda是9.2版，如果想要更低版本的可以手动指定版本，更高的（10+）就只能官网了。

```bash
sudo apt install nvidia-cuda-toolkit
```

安装完成后可以测试以下

```bash
nvcc --version
```

如果输出是 **nvcc: NVIDIA (R) Cuda compiler driver**的话，安装完成了。
在实际使用中，我们**不需要使用optirun**，而只是借用大黄蜂的`bbswitch`模块来进行显卡的开关。调用cuda程序的之前一定要手动启动显卡。

查看显卡状态

```bash
sudo cat /proc/acpi/bbswtich #查看显卡状态
```

打开显卡

```bash
sudo tee /proc/acpi/bbswitch <<<ON #打开显卡
```

关闭显卡

```bash
sudo rmmod nvidia_uvm
sudo rmmod nvidia
sudo tee /proc/acpi/bbswitch <<<OFF #关闭显卡
```

写出第一个cuda计算的例子来验证cuda + Bumblebee已经正确安装了

新建一个`hello.cu`文件

```cpp
// 1 + 1 = 2
// hello.cu
#include "stdio.h"
__global__ void add(int a, int b, int *c)
{
*c = a + b;
}
int main()
{
int a,b,c;
int *dev_c;
a=1;
b=1;
cudaMalloc((void**)&dev_c, sizeof(int));
add<<<1,1>>>(a,b,dev_c);
cudaMemcpy(&c, dev_c, sizeof(int), cudaMemcpyDeviceToHost);
printf("%d + %d is %d\n", a, b, c);
cudaFree(dev_c);
return 0;
}
```

保存后编译

```bash
nvcc hello.cu -o helloworld
sudo tee /proc/acpi/bbswitch <<<ON
./helloworld
```

如果看到 `1 + 1 is 2`的输出，代表一切正常。如果是0或者其他乱七八糟的值，重新检查你的显卡开关状态，或者用`optirun helloworld`调用独显再计算一次。

## Anaconda环境的安装和配置

为什么要用`Anaconda`呢？主要是避免污染本地环境，`pip`处理包依赖的功能并不好，尤其是如果以后要升级`python`包的时候，更是容易引起依赖地狱。
当然也可以使用`docker`来达成同样的效果，不过这里选用`Anaconda`。
`Anaconda`的安装流程可以在这个链接找到 [Installing on Linux](https://docs.anaconda.com/anaconda/install/linux/) 。
这里只提一点,安装以后先使用`init`使conda可以调用，第二句是避免默认激活`anaconda`环境，而使用系统自带的`Python`

```bash
conda init zsh/bash/fish # your shell
conda config --set auto_activate_base False
```

使用`conda activate base`和`conda deactivate`来进入和退出`anaconda`环境。

## Pytorch的安装

首先建议不要直接在`Anaconda`的`base`环境建立，而是从`Anaconda`中创建一个新分支来安装。

```bash
conda create -n pytorch python=3 numpy scipy
conda activate pytorch
conda install pytorch torchvision cudatoolkit=9.2 -c python  #安装cuda9.2版本的Pytorch
```

进入python环境，输入

```python
import torch
torch.cuda.is_available()
True
```
如果输出`False`的话，重新检查你的显卡开关，`cuda`版本。



