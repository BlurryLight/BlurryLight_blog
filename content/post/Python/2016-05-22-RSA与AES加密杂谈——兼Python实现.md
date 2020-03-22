---
layout: post
cid: 396
title: "RSA与AES加密杂谈——兼Python实现"
slug: rsa与aes加密杂谈-兼python实现
date: 2016-05-22
updated: 2016-05-22
status: publish
author: panda
categories: 
  - Python
tags: 
---


<blockquote>本文代码部分大量参考于http://www.jianshu.com/p/6a39610122fa</blockquote>

<blockquote>使用的Pycryto库的API：https://www.dlitz.net/software/pycrypto/apidoc/ </blockquote>
环境要求:Python 2.7,Pycryto库


<!--more-->


话外言：有那么长一段时间一直没写博客了，大概是由于变懒了和近期在学JavaScript。作为一个初入一门语言的小菜鸟着实不敢在JS领域发表什么言论，尽管在Python上也是菜鸟一个但至少还能写一写东西来娱乐自己。在晃悠了接近一月有余，总算决定不写不行了。恰好最近看了一点密码学的东西，就决定来写一写加密的杂谈。
<b>预警：本文可能充满理论上的错误和各路神论以及私人情感。</b>

一。为什么要加密
   这个问题太难回答了，大概和为什么你需要一个保险柜一样。
<blockquote>加密可以用于保证安全性，但是其它一些技术在保障通信安全方面仍然是必须的，尤其是关于数据完整性和信息验证。例如，信息验证码（MAC）或者数字签名。另一方面的考虑是为了应付流量分析。</blockquote>
   尤其是在网络环境比较恶劣的国内，加密的应用似乎无处不在。比如本博客的小绿锁，代表本网站传输的内容是加密的，无法被恶意宽带提供商劫持插入广告。再比如Shadowsocks为了防范传输内容被GFW审查而采用了AES-256-CFB(一种对称加密）
二。加密类型
<strong>   1.对称加密</strong>
 加密和解密方使用同一个密钥。
<strong>   2.非对称加密</strong>
顾名思义，非对称加密使用一对密钥，分为公钥和私钥。从私钥中推算出公钥，但过程不可逆。公钥加密的东西可以利用私钥解密，但私钥加密的东西不能用公钥解。但是私钥可以对信息进行签名，而公钥可以用来验证签名。

特点：对称加密加密速度快，长度不受限制。而非对称加密的加密文件长度不得超过密钥长度，且加密较慢，但是安全性高。

三。代码实现
   “Talk is cheap,show me the code.”
      我尽量在代码里面把注释写好。
```python
#!/usr/bin/env python
# encoding: utf-8
from Crypto.Hash import SHA
from Crypto.PublicKey import RSA
from Crypto import Random
from Crypto.Cipher import PKCS1_v1_5 as Cipher_do
from Crypto.Signature import PKCS1_v1_5 as Signature_do
import base64
class RSA_Encript(object):
    def __init__(self):
        self.text='This is for Test'
    def build_key(self):
    #生成随机数
        self.random_generator = Random.new().read
    #生成RSA密钥
        rsa = RSA.generate(1024,self.random_generator)
    #生成自己的密钥对
        private_pem = rsa.exportKey()
        publick_key = rsa.publickey().exportKey()
        with open('private_key.pem','w') as f:
            f.write(private_pem)
        with open('public_key.pem','w') as f:
            f.write(publick_key)
    def do_encrypt(self,text):
        #用公钥加密，后面用私钥解密
        with open('public_key.pem') as f:
            key=f.read()
            rsakey=RSA.importKey(key)
            cipher = Cipher_do.new(rsakey)
            cipher_text =base64.b64encode(cipher.encrypt(text))
            #加密后用base64转码，否则会生成乱码
            f.close()
        with open('加密后.txt','w') as f:
            f.write(cipher_text)
    def do_decript(self):
        with open('加密后.txt','r') as f:
            text=f.read()
        with open('private_key.pem') as f:
            key=f.read()
            rsakey=RSA.importKey(key)
            cipher=Cipher_do.new(rsakey)
            decrypt_text = cipher.decrypt(base64.b64decode(text),self.random_generator)
            #这里API文档给出的参数  cipher.decrypt(string,essential)  并且推荐essential采用一个随机数用以防范破解.
            print(decrypt_text)
    def sign(self,text):
        with open('private_key.pem') as f:
            key=f.read()
            rsakey=RSA.importKey(key)
            signer  = Signature_do.new(rsakey)
            digest = SHA.new()
            digest.update(text) #这里是对text的内容hash一次，获取hash值
            #这里对text变量签名，text可以为任意值，但是后面验签的时候需要知道text的值
            #API:  signer.sign(hash) 必须传递一个hash值进去
            sign = signer.sign(digest)
            signature = base64.b64encode(sign)
        with open('签名后.txt','w') as f:
            f.write(signature)
    def verify(self,text,signature):
        with open('public_key.pem') as f:
            key=f.read()
            rsakey=RSA.importKey(key)
            verifier = Signature_do.new(rsakey)
            digest = SHA.new()
            digest.update(text)
            #verify函数需要两个参数，一个是签名前的信息内容的hash，一个是生成的签名
            is_verify = verifier.verify(digest,base64.b64decode(signature))
            print(is_verify)


if __name__=="__main__":
    app = RSA_Encript()
    app.build_key()
    app.do_encrypt(app.text)
    app.do_decript()
    encrypted_text = open('加密后.txt').read()
    app.sign(encrypted_text)
    signature=open('签名后.txt').read()
    app.verify(encrypted_text,signature)
```


<strong>
通常情况下，一般是用AES对称加密方法来加密大文件，然后采用RSA非对称加密方法对AES加密时采用的密钥进行加密，最后如果需要签名还需要额外生成一个签名文件。</strong>


附上AES加密的代码片段：
```python
#!/usr/bin/env python
# encoding: utf-8

from Crypto.Cipher import AES
import os
from Crypto import Random
def encrypt():
    key = 'keyskeyskeyskeys'
#可以使用16位，24位，32位  分别对应aes-128/192/256
    mode = AES.MODE_CBC
    text="i"*32 + "j" *64
    encryptor = AES.new(key,mode,b'0000000000000000')
#这里有一个Bug,所以必须添加16个0才可以正常工作
    encrypted_text = encryptor.encrypt(text)
    return encrypted_text
def decrypt(encrypted_text):
    key = 'keyskeyskeyskeys'
    mode = AES.MODE_CBC
    decryptor = AES.new(key,mode,b'0000000000000000')
    text =  decryptor.decrypt(encrypted_text)
    return text
if __name__ == "__main__":
    en_text = encrypt()
    with open('a.txt','w') as f:
        f.write(decrypt(en_text))
```

