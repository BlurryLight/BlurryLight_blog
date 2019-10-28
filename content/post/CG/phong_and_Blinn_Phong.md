
---
title: "经典光照模型:Phong光照模型以及BlinnPhong光照模型"
date: 2019-10-28T16:27:19+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
lastmod: 2019-10-28T16:27:19+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Phong_and_Blinn_Phong"
toc: true
---

# Phong 光照模型
`Phong Lighting Model`在1975年，由Phong提出，以他的名字冠名。是一种局部光照的模型，他认为一个光照模型可以用三种不同的部分组成，主要包括`ambient`,`diffuse`,`specular`(环境光，漫反射和高光)。
![Phong光照模型(from LearnOpenGL)](/image/basic_lighting_phong.png)

## ambient光照
环境光照是考虑到即使在不可见光源的地方，经过各种反射，总会带有微弱的光照。光线追踪的算法会更加准确，但是在这里采用一种简化的方法。就是将光源的颜色，乘以一个很小的系数，再乘以物体的颜色。
```GLSL
vec3 ambient = 0.1 * lightColor * objectColor;
```

## diffuse光照
漫反射光照是考虑到，离光源越近，直接受光源照射的片段，理应比其他片段更亮。这种概念可以用两个向量表示，分别是片段到光源的位移向量与片段表面的单位法向量，他们的向量积表示了一种衡量漫反射的强度的量。

```GLSL
vec3 lightDir = lightPos - FragPos;
float diffuse = dot(norm,lightDir)
```

## specular光照
光线在表面经过反射后，会形成一束反射光。 摄像机正处于反射光路径时，理应获得一个高亮度的斑点。该强度可以用两个向量来衡量，分别是反射光与片段位置到摄像机位置的位移向量，当夹角为0时，获得最大强度。

# BlinnPhong光照
Phong光照模型在多数时候表现良好，然而在specular光照的计算时，当位移向量和反射光的向量大于90度时，该高光会丢失。表现出来会出现不正确的光线边界。

![不正确的边界(from LearnOpenGL)](/image/advanced_lighting_phong_limit.png)

为了弥补这个缺陷，引入一个`half_way`向量作为新的度量，`halfway`向量是view向量与lightDir向量之和，它与法向量的叉积作为强度衡量，可确保永远不会大于90度。

![Halfway向量的引入(from LearnOpenGL)](/image/advanced_lighting_halfway_vector.png)

此外还有一点，Phong的模型的反射光总是呈现一个圆斑，即使当视角平行于平面的时。而BlinnPhong会被拉伸成一个椭圆形，更符合真实情况。




