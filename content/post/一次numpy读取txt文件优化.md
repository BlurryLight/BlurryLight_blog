
---
title: "一次numpy读取txt文件优化"
date: 2020-01-01T20:04:49+08:00
draft: False
# tags: [ "" ]
categories: [ "Python"]
# keywords: [ ""]
lastmod: 2020-01-01T20:04:49+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "一次numpy读取txt文件优化"
toc: false
---

简单介绍下背景，有大约600个txt，大小在1M左右，实际内容是4列的浮点数，也就是csv格式，以空格分割。想用python读到内存里转成`numpy.array`格式，踩了一个`numpy.loadtxt`的坑。

先下结论:**永远不要用numpy.loadtxt**,非常非常慢[^1]。

环境：
- Manjaro x64
- HDD 5400X
- python 3.7 
- I7 4720HQ 2.6GHZ
## numpy.loadtxt有多慢
先用numpy跑一次loadtxt
```
import os
from timeit import default_timer as timer
import numpy as np
path_list = os.listdir('.')
start=timer()
[np.loadtxt(x) for x in path_list]
print(timer() - start)
```
结果:**139.54152867000084**
139秒，emm
## 换用pandas.read_csv看看
```
import os
from timeit import default_timer as timer
import pandas as pd
path_list = os.listdir('.')
start=timer()
[pd.read_csv(x).to_numpy() for x in path_list]
print(timer() - start)
```
结果:**12.904358740983298**
12.9秒，差不多快了十倍吧

## 再进一步
分析一下源文件，文件里面不存在无效数据，每列之间的间隔是空格，没有`header`(严格的说还有知道每个元素的浮点数信息)，可以对pandas再优化一下。
```
[pd.read_csv(x,header=None,na_filter=False,delim_whitespace=True).to_numpy() for x in path_list]
```
结果::**7.258525391021976**
速度再度提升了接近一倍

## 还可以再快
分析一下，读取文件到一个列表，列表可以无序，这是一个典型的可以并行而且不用加锁的场景，我的cpu是4核8线程，python由于GIL的存在，一个进程只能占用一个核，还可以在并行上加速，理论上可以得到至少4x的提升。

```
from multiprocessing import Pool
def csv_reader(filename):
    data = pd.read_csv(filename,header=None,na_filter=False,delim_whitespace=True)
    return data.to_numpy()
cores = os.cpu_count()
pool = Pool(cores)
data_list = pool.map(csv_reader,path_list)
```
结果:**2.62115897500189**，差不多三倍

和最开始的139秒比一下，快了近50倍。

## 还可不可以更快？
没有做实验，将所有文件用binary存储，整合成一个大文件，用C写读取模块，可能能更快，但是没必要，3秒600个1M文件的读取，差不多接近机械硬盘的最高速度了。



[^1]: [STOP USING numpy.loadtxt()](http://akuederle.com/stop-using-numpy-loadtxt)