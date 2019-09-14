
---
title: "LookAt的实现"
date: 2019-09-14T21:28:47+08:00
draft: false
# tags: [ "" ]
categories: [ "C++","OpenGL"]
# keywords: [ ""]
lastmod: 2019-09-14T21:28:47+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "LookAt的实现"
---

一个物体要在OpenGL中被渲染出现，需要经过经典的`MVP`变换，主要是从物体坐标系，通过`Model Matrix`，变换到世界坐标系，然后通过`View Matrix`，也叫相机坐标系，转换为某个视角所看到的内容，最后通过`projection Matrix`，做仿射变换，最后还有一步OpenGL隐藏的剪裁步骤，裁减掉不在投影区域内的像素点。

流程图可以看[^1]
![流程图](/image/MVP.png)

其中，`glm::lookat`函数是`glm`库提供的一个工具函数，可以用来计算`view matrix`。给定三个特殊向量，包括相机的`position`向量，相机所看的物体的位置`target`向量以及整个世界坐标系的`up`向量，可以计算出`view`矩阵。

![view矩阵](/image/lookat.png)

其中P是相机的位置向量，U是需要计算的，相机的up向量，R也是需要计算的，相机坐标系的右向量，D是最好计算的，D是direction向量，是从物体到相机的向量。
因此代码可以写成如下，

```cpp
  //* a solution to glm::lookat
  auto look_at = [](glm::vec3 position, glm::vec3 target,
                           glm::vec3 worldup) -> glm ::mat4 {
    glm::vec3 zaxis = glm::normalize(position - target);    //direction vector
    glm::vec3 xaxis =                                       //right vector
        glm::normalize(glm::cross(glm::normalize(worldup), zaxis));     // camera up vector
    glm::vec3 yaxis = glm::cross(zaxis, xaxis);

    glm::mat4 trans = glm::mat4(1.0f);
    trans[3][0] = -position.x;
    trans[3][1] = -position.y;
    trans[3][2] = -position.z;

    glm::mat4 rotation = glm::mat4(1.0f);
    rotation[0][0] = xaxis.x;
    rotation[1][0] = xaxis.y;
    rotation[2][0] = xaxis.y;

    rotation[0][1] = yaxis.x;
    rotation[1][1] = yaxis.y;
    rotation[2][1] = yaxis.y;

    rotation[0][2] = zaxis.x;
    rotation[1][2] = zaxis.y;
    rotation[2][2] = zaxis.y;

    return trans * rotation;
  };
```

[^1]: reference : https://learnopengl.com/Getting-started/Camera
