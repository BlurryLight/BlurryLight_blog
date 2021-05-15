
---
title: "PBR渲染: 对IBL的理解"
date: 2021-05-15T23:08:49+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
lastmod: 2021-05-15T23:08:49+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "dec701b2"
toc: false
#latex support
katex: true
markup: mmark
---

# Cook-Torrance反射方程
$$
L_{o}\left(p, \omega_{o}\right)=\int_{\Omega}\left(k_{d} \frac{c}{\pi}+\frac{D F G}{4\left(\omega_{o} \cdot n\right)\left(\omega_{i} \cdot n\right)}\right) L_{i}\left(p, \omega_{i}\right) n \cdot \omega_{i} d \omega_{i}
$$

常用的`D，F，G`函数有多个选择。
## 菲涅尔反射项
`F`项我们可以选用`schilick`近似。`F`函数描述了光线在经过某个物体表面的反射率和折射率。`F`函数中的$$F_0$$项描述了光线以0度的偏差(沿着法线方向）碰撞表面的时候的反射率，电介质这个值很低。那么剩下的$$1 - F_0$$就是发生
折射的能量。
如果把角度和微表面模型考虑进去，那么在Cook-Torrance中，它会形如

$$
F_{Schlick}\left(h, v, F_{0}\right)=F_{0}+\left(1-F_{0}\right)(1-(h \cdot v))^{5}
$$

注意该函数是关于$$h,v$$的函数，其中$$h$$需要格外注意。

## 法线分布函数(NDF）
`NDF`函数描述了微表面模型的法线分布。关于它的选择有很多，常用的包括Trowbridge-Reitz GGX函数。它是形如

$$
NDF_{GGX}(n, h, \alpha)=\frac{\alpha^{2}}{\pi\left((n \cdot h)^{2}\left(\alpha^{2}-1\right)+1\right)^{2}}
$$

有一点需要格外注意，它是有关$$h$$的一个函数。并且所有的NDF都遵循一个性质: 如果给定一个点，已知它的法线和粗糙度，那么

$$
\int_{\Omega} D(h) \cos \left(\theta_{h}\right) d \omega=1
$$

这个式子隐含了一个重要的推论：所有的`NDF`乘以`cosine`项都代表了一个`pdf`函数。这意味着`GGX`的`pdf`函数就是

$$
pdf_{ggx}(n,h,\alpha) = \frac{\alpha^{2} (\mathbf{n} \cdot \mathbf{h})}{\pi\left((n \cdot h)^{2}\left(\alpha^{2}-1\right)+1\right)^{2}}
$$
 
 这个推论会帮助后续对`brdf`进行重要性采样。对这个pdf积分，进行逆变换采样得到

 $$
\theta=\arccos \sqrt{\frac{1-r_1}{r_1\left(\alpha^{2}-1\right)+1}} \\
\phi = 2\pi r_2
$$

拿到球面坐标后转到x,y,z坐标就可以拿到向量$$\mathbf{h}$$的笛卡尔坐标系表达。
注意，我们所采样的$$\theta$$,$$\phi$$都是关于$$h$$向量的。所以$$pdf$$也是关于$$\mathbf{h}$$向量的，我们实际关心的是$$w_o$$方向的pdf。因此要把$$p(h)$$转换到$$p(w_o)$$，涉及到一点jacobian。

具体的证明可以见https://www.graphics.cornell.edu/~bjw/wardnotes.pdf。
不过简单的描述下，因为$$h$$是半程向量，所以$$\theta_h^* $$是$$\theta_o^*$$的二分之一。后面的分子的$$\sin\theta_h$$是因为把笛卡尔坐标系的x,y,z转变到球面坐标系需要乘以$$\sin\theta_h$$,计算完了以后要回到笛卡尔坐标系，从球坐标回到笛卡尔坐标系需要除以$$\sin\theta_o$$。

$$
\begin{aligned}
p_{o}(\mathbf{o}) &=p_{h}(\mathbf{h})\left\|\frac{\partial\left[\theta_{h}^{\star}, \phi_{h}^{\star}\right]}{\partial\left[\theta_{o}^{\star}, \phi_{o}^{\star}\right]}\right\| \frac{\sin \theta_{h}^{\star}}{\sin \theta_{o}^{\star}} \\
&=p_{h}(\mathbf{h})\left|\frac{1}{2}-0\right| \frac{\sin \theta_{h}^{\star}}{\sin 2 \theta_{h}^{\star}} \\
&=\frac{p_{h}(\mathbf{h})}{4 \cos \theta_{h}^{\star}}=\frac{p_{h}(\mathbf{h})}{4(\mathbf{h} \cdot \mathbf{i})}
\end{aligned}
$$

# ...
(to be continued)