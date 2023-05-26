# GrassShader

使用曲面细分着色器和几何着色器生成交互草地

## 效果展示

### 无光照

个人认为这个天空球背景更适合无光照

![withoutLight.png](ScreenShot%2FwithoutLight.png)

### Lambert光照

![withLight.png](ScreenShot%2FwithLight.png)

### 交互

![interactGrass.png](ScreenShot%2FinteractGrass.png)

## Shader使用方法
1. 将**ShaderInteractor.cs**文件挂在角色上
2. 调整脚本**Offset**参数，使向外偏移圆圈中心和角色对齐
3. 新建平面，**添加Grass.mat**材质

## 参考链接

[菜鸡都能学会的Unity草地shader](https://zhuanlan.zhihu.com/p/433385999)

[Unity Grass Shader Tutorial](https://roystan.net/articles/grass-shader/)

[GrassGeometry.shader](https://pastebin.com/VQHj0Uuc)