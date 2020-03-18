
---
title: "图形学中常见的变换"
date: 2019-08-09T17:33:03+08:00
draft: false
# tags: [ "" ]
categories: [ "CG","C++"]
# keywords: [ ""]
# lastmod: 2019-08-09T17:33:03+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Matrix_Transformation"
katex: true
markup: mmark
---

引言: https://learnopengl.com/Getting-started/Transformations 这里讲得不错。这篇文章不过是对链接指向地址的简单摘要。此外，推荐\<Foundation of 3D computer graphics\>，前六章的数学基础讲得不错。

##  为什么要用齐次坐标？



Why use *homogeneous matrix*? 图形学中常用4x4矩阵来进行变换，因为 1. 升维后的向量能够帮助我们区分**点**和**向量**, 2 在齐次坐标下可以统一线性变换和平移变换。

考虑如下 $$ \vec{v} $$

$$
\left[
\begin{array}{cc}
 x_{1} \\
 y_{1} \\
 z_{1}
 \end{array}
  \right]
 $$

它可能代表一个**点**，也可能代表一个**向量**。 一个向量和一个向量的一些操作是有物理含义的，如$$\vec x + \vec y$$，代表$$\vec x$$与$$\vec y$$向量方向的串接。而两个点相加的操作是无意义的，你也不可能对一个点做放大(scale)的线性变换，同理，一个向量代表着某种**方向**，对某个**方向**做平移(translate)操作是毫无意义的。因此，我们为向量和点的表示再添加一个维度，最后一个维度为0的坐标表示这是一个向量，而最后一个维度为1的代表这是一个点。

一个向量:

$$
\left[
\begin{array}{cc}
 x_{1} \\
 y_{1} \\
 z_{1} \\
 0
 \end{array}
  \right]
 $$

一个点

$$
\left[
\begin{array}{cc}
 x_{1} \\
 y_{1} \\
 z_{1} \\
1
 \end{array}
  \right]
 $$

矩阵与矩阵的操作需要保持相同的维度，所以变换的矩阵也要升维为4*4矩阵。

### 常用的仿射变换

仿射变换主要由三种**线性变换**和非线性的**平移变换**组成。

#### Scaling

代表缩放，我们对向量缩放代表着增加它的"模"，从物理上，代表着沿着它原有的方向，代表着更远的运动。

$$\left[
\begin{array}{cc}
 S_{1} \\
 & S_{2} \\
 & &S_{3} \\
&&& 1
 \end{array}
  \right]
  \cdot     \left(
\begin{array}{cc}
v_{1}\\
v_{2} \\
v_{3} \\
1
 \end{array}
  \right)=    \left(
\begin{array}{cc}
S_{1} \cdot v_{1}\\
S_{2} \cdot v_{2} \\
S_{3} \cdot v_{3} \\
1
 \end{array}
  \right)$$


#### rotation
这里采用**右手坐标系**。
一个二维的旋转矩阵可以表示为，其中$$\theta$$代表逆时针旋转的角度。

$$
 \left[
\begin{array}{cc}
\cos\theta & -\sin\theta \\
\sin\theta & \cos\theta
 \end{array}
  \right]
  $$

  二维的旋转默认以原点为中心，以z轴作为旋转轴，由此推广到三维

  $$
 \left[
\begin{array}{cc}
\cos\theta & -\sin\theta & 0 &0 \\
\sin\theta & \cos\theta & 0  & 0\\
0 & 0 & 1 &0 \\
0 & 0 & 0 & 1
 \end{array}
  \right]
  $$

  表示三维空间内，绕z轴的逆时针转动$$\theta$$角。
比较特殊的是绕y轴旋转，符号是反的(因为x轴crossz轴得到的方向和y轴相反)

  $$
 \left[
\begin{array}{cc}
\cos\theta &0 & -sin\theta & 0  \\
0 & 1 & 0 &0 \\
-\sin\theta &0 & \cos\theta  & 0\\
0 & 0 & 0 & 1
 \end{array}
  \right]
  $$

可以推广到绕任意轴$$\vec{n}$$逆时针旋转$$\theta$$:

$$ \mathbf{R(n,\theta) = \cos\theta I + (\text{1} - \cos\theta)nn^T + \sin\theta}
\begin{Bmatrix}
  0 & -n_z & ny \\
  n_z & 0 & -n_x \\
  -n_y& n_x &0
\end{Bmatrix}
 $$

#### shear
三维shear用的比较少。

$$
T = 
\begin{bmatrix}
 1  & sh_y^x & sh_z^x  & 0\\
 sh_x^y & 1 & sh_z^y & 0\\
  sh_x^z & sh_x^y &   1 & 0\\
  0 & 0 & 0 & 1
\end{bmatrix}
 $$
 
$$
 V' = T \cdot V \\
 V'.x = V.x + sh_y^x V.y + sh_z^x V.z\\
 ...
 $$


#### Translation

移动代表着把一个向量加到原有的向量上，返回新的向量。

$$
\left[
\begin{array}{cc}
 &&&T_{x} \\
 &&&T_{y} \\
 &&&T_{z} \\
&&& 1     \\
 \end{array}
  \right]
  \cdot \left(
\begin{array}{cc}
v_{1}\\
v_{2} \\
v_{3} \\
1
 \end{array}
  \right)=    \left(
\begin{array}{cc}
T_{x} + v_{1}\\
T_{y} + v_{2} \\
T_{z} + v_{3} \\
1
 \end{array}
  \right)
 $$

 其中，$$T_x,T_y,T_z$$分别代表原向量沿着$$x,y,z$$三轴移动的距离。