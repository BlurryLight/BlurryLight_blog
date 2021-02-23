
---
title: "Kinect_V1在Debian testing的配置指北"
date: 2019-08-29T17:07:59+08:00
draft: false
# tags: [ "" ]
categories: ["cpp"]
# keywords: [ ""]
lastmod: 2019-08-29T17:07:59+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Kinect_V1在Debian_testing的配置指北"
---
# 坑在哪里
在Linux下驱动Kinect V1现在有两种方式，一种是使用`OpenNI + SensorKinect + Nite`的方案，一种是使用`OpenNI2 + libfreenect`的方案，第一种我没有尝试，第二种的话，Debian有坑。
Debian的包管理自带有`LibOpenNI-dev`和`LibOpenNI2-dev`，这个是`PCL`库的前置依赖，理论上来说，通过`apt`装上`libfreenect-dev`就可以了。然而，`OpenNI2`与`libfreenect`连接，
需要在`libfreenect`的编译选项里打开`BUILD_OPENNI2_DRIVER`，然而Debian自带的库不带这一点，因此需要手动编译，不然会出现这样的错误。
```
SimpleViewer: Device open failed:
DeviceOpen using default: no devices found
```

## 解决方案

根据[OpenNI2-FreenectDriver](https://github.com/OpenKinect/libfreenect/tree/master/OpenNI2-FreenectDriver)的链接，首选需要一个`>=2.2.033`版本的OpenNI2。
可以从github下载预编译版本，也可以自己手动编译。然后需要手动编译`libfreenect`。

```shell
 mkdir build
 cd build
 cmake .. -DBUILD_OPENNI2_DRIVER=ON
 make
```

编译的结果里会有一个`libFreenectDriver.so`，这就是所缺少的文件。接下来:

1. 备份Debian自带的`/lib/libOpenNI2.so`，`/lib/OpenNI2/`，删掉他们，再刚刚下载的`OpenNI2`中找到对应的文件，复制到系统对应位置去替换他们。
2. 把`libFreenectDriver.so`文件放入`/lib/OpenNI2/Drivers`。
3. 由于Debian的打包策略，可能还需要建立一些`libxxx.so.0`类似的软链接。