## 7 基础纹理



### 单张纹理

关注这段CG代码，在Blinn-Phone光照模型基础上增加单张贴图

```glsl
Properties {
	_Color ("Color Tint", Color) = (1, 1, 1, 1)
	_MainTex ("Main Tex", 2D) = "white" {}
	_Specular ("Specular", Color) = (1, 1, 1, 1)
	_Gloss ("Gloss", Range(8.0, 256)) = 20
}
/*...*/
CGPROGRAM

#pragma vertex vert
#pragma fragment frag

#include "Lighting.cginc"

fixed4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
fixed4 _Specular;
float _Gloss;

struct a2v {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 texcoord : TEXCOORD0;
};

struct v2f {
	float4 pos : SV_POSITION;
	float3 worldNormal : TEXCOORD0;
	float3 worldPos : TEXCOORD1;
	float2 uv : TEXCOORD2;
};

v2f vert(a2v v) {
	v2f o;
	o.pos = UnityObjectToClipPos(v.vertex);
	// o.worldNormal = UnityObjectToWorldNormal(v.normal);
	o.worldNormal = mul(v.normal, unity_WorldToObject);
	o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

	o.uv = v.texcoord.xy * _MainTex_ST.xy * _MainTex_ST.zw;
	// o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
	
	return o;
}

fixed4 frag(v2f i) : SV_Target {
	fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;

	fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

	fixed3 WorldNormal = normalize(i.worldNormal);
	fixed3 WorldLightDir = normalize(_WorldSpaceLightPos0.xyz);
	fixed3 ViewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
	fixed3 halfDir = normalize(ViewDir + WorldLightDir);

	fixed3 diffuse = _LightColor0.rgb * albedo.rgb * saturate(dot(WorldNormal, WorldLightDir));
	fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, WorldNormal)), _Gloss);
	
	return fixed4(ambient + diffuse + specular, 1.0);
}

ENDCG
```

顶点着色器额外需要纹理坐标`texcoord`

片元着色器额外需要 经过缩放(.xy)和偏移(.zw)后的纹理坐标`uv`，片元着色器据此进行纹理采样



要确保(*)_ST中\*字符串和定义的纹理属性相同



纹理属性中设置纹理滤波方式，在shader代码中并不关心



`albedo`是在片元着色器中对纹理采样的结果，和第6章中的光照模型计算相比：

- 修改了环境光颜色，如果不乘albedo，物体的底色就是环境光的颜色，本例中会呈现白色，可以在背光一侧观察到
- 代替物体漫反射颜色_Diffuse，有纹理的物体计算漫反射时使用纹理中的纹素值，这点可以理解
- 对高光反射specular没有影响，高光部分本质上是一块颜色由_Specular决定的亮斑





### 凹凸映射

通常使用法线映射来修改光照实现凹凸效果，需要用到法线纹理

指定顶点在切线空间下的法线位置，用在材质纹理下的颜色信息和法线纹理下的法线信息来做光照的相关运算



案例使用的切线空间下的法线纹理，需要让视线向量、光线向量、法线向量统一在一个线性空间下做光照相关的运算



#### 切线空间下计算光照

[为什么要有切线空间（Tangent Space），它的作用是什么？ - 知乎 (zhihu.com)](https://www.zhihu.com/question/23706933)

需要在顶点着色器中将视角方向、光照方向变换到切线空间（这种方法高效）

片元着色器采样切线空间下的法线，再和切线空间下的视角方向、光照方向进行计算

```glsl
Properties {
	_Color ("Color Tint", Color) = (1, 1, 1, 1)
	_MainTex ("Main Tex", 2D) = "white" {}
	_BumpMap ("Normal Map", 2D) = "bump" {}
	_BumpScale ("Bump Scale", Float) = 1.0
	_Specular ("Specular", Color) = (1, 1, 1, 1)
	_Gloss ("Gloss", Range(8.0, 256)) = 20
}
```

属性中增加了`_BumpMap`和`_BumpScale`用来存储法线纹理和凹凸程度，`_BumpScale`正负代表不同凹凸方向



```glsl
struct a2v {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float4 texcoord : TEXCOORD0;
};

struct v2f {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 lightDir: TEXCOORD1;
	float3 viewDir : TEXCOORD2;
};
```

顶点着色器需要获取顶点的切线方向`tangent`

片元着色器需要`lightDir`和`viewDir`，这两者是切线空间下的

两张纹理需要两个坐标，故uv设为float4，使用xy、zw分量

这里并没有使用`worldNormal`和`worldPos`，原因是？：worldPos用来计算视角方向，我们已经在顶点着色器中得到了切线空间下的视角方向，切线空间下法线方向可以由法线纹理采样，不需要用worldNormal变换



```glsl
v2f vert(a2v v) {
	v2f o;
	o.pos = UnityObjectToClipPos(v.vertex);

	o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
	o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

	fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
	fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
	fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 

	float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

	// Transform the light and view dir from world space to tangent space
	o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
	o.viewDir = mul(worldToTangent, WorldSpaceViewDir(v.vertex));

	return o;
}
```

顶点着色器关键在于如何完成切线空间的变换，这里数学原理见p71

这里是矩阵是正交的，所以不需要求逆，只需要转置

将向量从世界坐标系A变换到切线坐标系B，变换矩阵是切线空间坐标轴x y z在世界坐标下的按行排列

float3x3是行主的



```glsl
fixed4 frag(v2f i) : SV_Target {				
	fixed3 tangentLightDir = normalize(i.lightDir);
	fixed3 tangentViewDir = normalize(i.viewDir);
	
	// Get the texel in the normal map
	fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
	fixed3 tangentNormal;
	// If the texture is not marked as "Normal map"
//	tangentNormal.xy = (packedNormal.xy * 2 - 1) * _BumpScale;
//	tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
	
	// Or mark the texture as "Normal map", and use the built-in funciton
	tangentNormal = UnpackNormal(packedNormal);
	tangentNormal.xy *= _BumpScale;
	tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
	
	fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
	
	fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
	
	fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

	fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
	fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);
	
	return fixed4(ambient + diffuse + specular, 1.0);
}
```

片元着色器中光照计算过程和单张纹理一致



#### 世界空间下计算光照

将采样得到的法线变换到世界空间，在片元着色器中完成

```glsl
struct v2f {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float4 TtoW0 : TEXCOORD1;  
	float4 TtoW1 : TEXCOORD2;  
	float4 TtoW2 : TEXCOORD3; 
};
```

在片元着色器进行切线空间到世界空间的变换，需要传递三个坐标轴，用以构建变换矩阵



```glsl
v2f vert(a2v v) {
	v2f o;
	o.pos = UnityObjectToClipPos(v.vertex);
	
	o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
	o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;
	
	float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
	fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
	fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
	fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
	
	// Compute the matrix that transform directions from tangent space to world space
	// Put the world position in w component for optimization
	o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
	o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
	o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
	
	return o;
}

fixed4 frag(v2f i) : SV_Target {
	// Get the position in world space		
	float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
	// Compute the light and view dir in world space
	fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
	fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
	
	// Get the normal in tangent space
	fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
	bump.xy *= _BumpScale;
	bump.z = sqrt(1.0 - saturate(dot(bump.xy, bump.xy)));
	// Transform the narmal from tangent space to world space
	bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
	
	fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
	
	fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
	
	fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(bump, lightDir));

	fixed3 halfDir = normalize(lightDir + viewDir);
	fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(bump, halfDir)), _Gloss);
	
	return fixed4(ambient + diffuse + specular, 1.0);
}
```

这里坐标变换矩阵需要按列放置

顶点坐标附加在齐次的位置，这样能少传递一个参数

[3\*3] x [3*1] 矩阵向量乘法按行拆分，可读性略有下降



注释掉的pass尝试自己实现，多用了一个变量传递世界空间下的顶点坐标，看起来更加直观一些，经验证功能是正确的





### 渐变纹理

渐变纹理用来控制物体的漫反射光照

```glsl
fixed halfLambert  = 0.5 * dot(worldNormal, worldLightDir) + 0.5;
fixed3 diffuseColor = tex2D(_RampTex, fixed2(halfLambert, halfLambert)).rgb * _Color.rgb;
fixed3 diffuse = _LightColor0.rgb * diffuseColor;
```

渐变纹理只影响漫反射，计算半兰伯特光照，代替纹理坐标uv对渐变纹理采样





### 遮罩纹理

遮罩纹理可以保护某些区域避免修改，纹理值与表面属性相乘来控制影响的强弱，0相当于不受属性影响

案例中用于控制高光反射

```glsl
fixed specularMask = tex2D(_SpecularMask, i.uv).r * _SpecularScale;
fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss) * specularMask;
```

纹理的r分量计算掩码值，并与_SpecularScale相乘，结果越大，高光效果越明显





## 透明效果

### 透明度测试

透明度测试需要在Tags中指定渲染队列"AlphaTest"

```glsl
Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
```

```glsl
clip (texColor.a - _Cutoff);
```

测试由clip函数完成，裁剪条件为纹理颜色值，通过测试部分进行光照计算（这个shader里没有计算高光反射）





### 透明度混合（半透明效果）

使用当前片元的透明度作为混合因子，与已经储存在颜色缓冲中的颜色值进行混合

注意：开启深度测试，关闭深度写入

```glsl
Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
```

在pass语句块中关闭深度写入，设置混合因子（多种混合因子可选）

```glsl
pass{
	Tags { "LightMode" = "ForwardBase" }

	ZWrite Off	
    Blend SrcAlpha OneMinusSrcAlpha
}
```



```glsl
return fixed4(ambient + diffuse, texColor.a * _AlphaScale);
```

在片元着色器的返回值中设置了透明通道，值为纹理像素的透明通道`texColor.a`和`_AlphaScale`乘积





### 开启深度写入的半透明效果

关闭深度写入会造成错误排序

使用两个pass渲染模型，第一个开启深度写入，第二个进行透明度混合

```glsl
pass{
	ZWrite On
	ColorMask 0
}
```

第一个pass将模型的深度信息写入缓冲区，用以剔除被自身遮挡的片元，从原理上看，对于模型自身前后遮挡问题根据zbuffer剔除，这和不透明的方式来处理一致，我们只能看到靠近相机的部分

即使是半透明的，也只能看到距离相机最近的表面，不同物体之间仍然遵循透明度混合





### 双面渲染透明效果

#### 透明度测试双面渲染只需要关闭Cull

```glsl
Pass {
	Tags { "LightMode"="ForwardBase" }
	// Turn off culling
	Cull Off
	CGPROGRAM
    /**/
```

默认Cull Back，也可以设为Front，剔除前表面



#### 透明度混合双面渲染

SubShader中的pass顺序执行，可以利用这一点控制正面/背面的渲染顺序

透明度混合shader中第一个pass 设置Cull Front剔除正向图元，第二个设置Cull Back剔除背向图元





`总结`：

透明度测试

- 开启深度写入，深度测试
- 双面渲染只需要关闭Cull

透明度混合

- 关闭深度写入，开启深度测试
- 对于复杂物体可以开启深度写入，这需要先增加一个pass将模型的深度信息写入缓冲区，用以剔除被自身遮挡的片元，第二个pass进行混合
- 双面混合使用不同pass控制正面/背面的渲染顺序



思考问题1：双面混合可否使用之前深度写入的方法？显然不可以，原因在于ZBuffer只保留了最靠近相机的片元



思考问题2：可不可以通过剔除背面实现开启ZWrite混合一样的效果？不可以，复杂物体透明部分关系混乱和正面背面无关，是由于渲染顺序不正确引起的



思考问题3：透明度混合为什么要关ZWrite，不关会出现什么情况？

在透明度混合中，ZWrite影响透明物体之间有重叠部分的情况（物理上的重叠，一个物体嵌入到另一个物体，scene8_4中增加了一个透明立方体，开启ZWrite重叠部分会被“吃掉”）

因为Unity根据物体排序级别的排序，前面方块的重叠部分被剔除掉了没有渲染，会先渲染后方的方块，由于后方的方块进行了深度写入，所以等到前面方块渲染的时候，重叠部分的像素无法通过深度测试，会直接被剔除掉

如果两个透明物体不重叠，关闭ZWrite与否对最终结果没有影响，原因是从后往前渲染，前面物体的Z值一定比后面的小

[Unity 透明混合为什么要关闭深度写入_unity 透明物体重叠闪烁](https://blog.csdn.net/u011105442/article/details/134136441?spm=1001.2101.3001.6650.1&utm_medium=distribute.pc_relevant.none-task-blog-2~default~BlogCommendFromBaidu~Ctr-1-134136441-blog-120240950.235^v43^pc_blog_bottom_relevance_base6&depth_1-utm_source=distribute.pc_relevant.none-task-blog-2~default~BlogCommendFromBaidu~Ctr-1-134136441-blog-120240950.235^v43^pc_blog_bottom_relevance_base6)



思考问题4：为什么透明度混合不能直接关闭Cull？

scene8_7_2中新增立方体AlphaBlendCullOff进行对比

因为没有开启深度写入，无法保证这些面的渲染顺序，会出现错误混合效果，比如底面盖到最顶层

即使开启深度写入，确保了渲染顺序没有问题，也会有一些面不被渲染，原因见思考问题3





## 复杂光照

[内置渲染管线中的渲染路径 - Unity 手册](https://docs.unity.cn/cn/2022.2/Manual/RenderingPaths.html)

### 前向渲染

前向渲染原理p182

- 进行一次前向渲染时，计算被渲染的物体的深度缓冲和颜色缓冲，根据深度缓冲决定该图元是否可见，可见则更新颜色缓冲区；每个逐像素光源都进行一次
- 问题：受渲染场景影响（物体数和逐像素光照数）。当场景中包含大量实时光源，需要为每个物体执行多个Pass计算不同光源的光照结果，并混合到颜色缓冲区。

延迟渲染原理

- 使用G-Buffer，存储所关心表面（离摄像机最近）的法线、位置、材质属性等信息，G-Buffer大小和屏幕空间有关
  延迟渲染包含两个Pass，第一个仅计算哪些片元可见，并将信息储存到G-Buffer，每个物体仅执行一次；第二个Pass进行光照计算
- 渲染效率不依赖于场景复杂度，只和屏幕空间的大小有关
- 问题：不支持真正的抗锯齿功能，不能处理半透明物体，需要硬件支持等



前向渲染中两类pass对比：

Base Pass：

- 只会执行一次（除非定义了多个Bass Pass）

- 处理一个逐像素的平行光（最重要的平行光 最亮的）和其他所有逐顶点光源和SH光源

- 处理环境光和自发光（在Additional Pass执行会叠加）
- 默认开启阴影的

Additional Pass：

- 对其余所有的**逐像素光源**进行处理，每个逐像素光源调用一次Additional Pass

- 开启混合模式
- 默认不开启阴影

[「UnityShader笔记」12.Unity中的前向渲染(Forward Base) - 睦月兔 - 博客园 (cnblogs.com)](https://www.cnblogs.com/MuTsuKi/p/16424950.html)



Unity光源设置

- 渲染模式 Not Important ：逐顶点或SH处理（逐顶点和球谐处理方式本章未提及）

- 渲染模式 Important ： 逐像素处理



ForwardRendering.shader代码总结：

- Base Pass处理平行光，计算环境光，漫反射和高光反射，衰减率1

- Additional Pass处理其他逐像素光源，需要计算漫反射和高光反射，计算光照衰减。需要开启混合模式

- ```glsl
  #pragma multi_compile_fwdbase
  #pragma multi_compile_fwdadd
  ```

  编译指令确保在shader中使用的光照衰减等光照变量可以被正确赋值



渲染过程示例p194



### 光照衰减

默认使用纹理查找方式计算逐像素的点光源和聚光灯衰减，平行光认为不衰减（Base Pass中atten设为1）

将顶点从世界空间变换到光源空间，根据坐标对衰减纹理采样得到衰减值

```glsl
float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
```

也可以利用公式自行计算

scene_9_2_1 ForwardRendering.shader line121



### 阴影

阴影效果使用Shadow Map实现技术



需要LightMode为ShadowCaster的pass来更新阴影映射纹理，ForwardRendering.shader中增加了该pass，如果没有将会从FallBack寻找



Unity5中使用屏幕空间的阴影映射技术，首先调用ShadowCaster得到光源的阴影映射纹理和相机的深度纹理，然后得到屏幕空间的阴影图。如果相机深度图中表面深度阴影映射纹理中的深度值，说明该表面可见但是处于阴影。计算接收阴影时只需要在阴影图中采样。



接收阴影：对阴影映射纹理（包括屏幕空间的阴影图）进行采样，将采样结果与光照结果相乘

投射阴影：将物体加入光源的阴影映射纹理计算



#### 阴影投射

投射阴影：将物体加入光源的阴影映射纹理计算，由ShadowCaster Pass完成

ShadowCaster Pass的渲染目标既可以是光源的阴影映射纹理，也可以是相机的深度纹理



引一篇自定义shadowcaster博客（自己写阴影的投射pass，这样就可以继续开启SRP Batcher，并支持alpha test的透明阴影[urp管线的自学hlsl之路 第十二篇 ShadowCaster和SRP batcher](https://www.bilibili.com/read/cv6473097/)）



#### 阴影接收

接收阴影：对阴影映射纹理（包括屏幕空间的阴影图）进行采样，将采样结果与光照结果相乘

内置Standard Shader支持接收阴影



在Base Pass做如下修改

- 在v2f中声明对阴影纹理采样的坐标

  ```glsl
  #define SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1;
  ```

- 在顶点着色器计算上述坐标

  ```glsl
  #define TRANSFER_SHADOW(a) a._ShadowCoord = mul (unity_WorldToShadow[0], mul(unity_ObjectToWorld,v.vertex));
  ```

- 在片元着色器中计算阴影值

  ```glsl
  #define SHADOW_ATTENUATION(a) UnitySampleShadowmap(a._ShadowCoord)
  /*...*/
  return fixed4(ambient + (diffuse + specular) * atten * shadow, 1.0);
  ```

使用AutoLight.cginc中的宏实现，宏会使用上下文变量进行计算，需要确保a2v v2f中自定义变量命名一致



总结阴影绘制过程（Frame Debugger查看）：

- 更新相机的深度纹理
- 得到光源的阴影映射纹理（记录从该光源位置出发，场景中距离它最近的表面的位置。一共生成了四个尺度）
- 得到屏幕空间阴影图
- 绘制渲染结果



原理上，光照衰减和阴影对物体渲染结果的影响相同

通常情况下需要在Base Pass处理阴影，在Additional Pass判断光源类型处理光照衰减（这里默认除平行光外的其他光源不产生阴影效果）



AttenuationAndShadowUseBuildInFunctions.shader：

可以使用UNITY_LIGHT_ATTENUATION一并计算，不必区分base pass或additional pass
UNITY_LIGHT_ATTENUATION根据光源类型、是否启用cookie声明多个版本，不需要再定义atten

注意使用WorldSpaceLightDir计算光照方向而不用WorldSpaceLightPos（只计算平行光）

经过统一后，两个pass区别：1. 编译指令不同 2. Base Pass有ambient



#### 透明物体阴影

AlphaTestMat中FallBack 为Transparent/Cutout/VertexLit，内置的ShadowCaster提供透明度测试，将裁减后的物体深度信息写入深度图和阴影映射纹理中，需要_Cutoff变量

对比两个shadowcaster

```glsl
#Common
		Pass{
			Tags { "LightMode" = "ShadowCaster" }

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"

			struct v2f {
				V2F_SHADOW_CASTER;
			};

			v2f vert (appdata_base v) {
				v2f o;
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
				return o;
			}

			float4 frag(v2f i) : SV_Target{
				SHADOW_CASTER_FRAGMENT(i);
			}
			ENDCG
		}

#Alpha test
		Pass{
			Tags{"LightMode" = "ShadowCaster"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed _Cutoff;

			struct v2f
			{
				V2F_SHADOW_CASTER;
				float2 uv : TEXCOORD0;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				o.uv = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				return o;
			}

			float4 frag(v2f i) : SV_TARGET
			{
				fixed4 testColor = tex2D(_MainTex, i.uv);	
				clip(testColor.a - _Cutoff);
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
```

注：Mesh Renderer组件中Cast Shadows属性设为Two Sided，将被对光源的面深度信息加入阴影映射纹理的计算中，这样计算所有面的深度信息，避免仅考虑正面出现不正确透光部分



AlphaBlendMat中FallBack设置为"Transparent/VertexLit"，半透明物体不会产生阴影，强行将FallBack设为VertexLit，阴影效果和不透明物体一样

---

书中暂时没有讨论阴影算法实现方式，在此补充

[阴影算法的实现(SM、PCF、PCSS、VSM) | Banbao (banbao991.github.io)](https://banbao991.github.io/2021/06/18/CG/Algorithm/SM-PCF-PCSS-VSM/)

202课程：[实时渲染一：软阴影实现 | 计算机图形学笔记 (remoooo.com)](https://docs.remoooo.com/cg01/202-gao-zhi-liang-shi-shi-xuan-ran/gao-zhi-liang-shi-shi-xuan-ran/shi-shi-xuan-ran-yi-ruan-yin-ying-shi-xian)

[shadowmap的原理与实现_shadow map-CSDN博客](https://blog.csdn.net/the_shy33/article/details/120043177)

[ShadowMap的技术原理和实现 - 技术专栏 - Unity官方开发者社区](https://developer.unity.cn/projects/6434d104edbc2a001ee7a032)

[【Unity Shader】Unity中自阴影优化方案_unity 阴影锯齿-CSDN博客](https://blog.csdn.net/qq_41835314/article/details/127556757)

---



问题：示例中只在Base Pass中给出了平行光阴影，逐像素的点光源能否产生阴影？

[[Shader\] 4.实现平行光和其他光源的阴影效果 - 技术专栏 - Unity官方开发者社区](https://developer.unity.cn/projects/62e8e3a0edbc2a001ce4d784)

使用\#pragma multi_compile_fwdadd_fullshadows替换\#pragma multi_compile_fwdadd，在Additional Pass添加阴影效果。Scene9_4_4增加一个点光源，实测在inspector中选择shadow type后，不修改这条编译指令也可以有阴影效果



问题1：为什么同样的shader和mat，没有正确的阴影？

解决：视角设置应当选择persp透视视野，ISO平行视野不会呈现正确的结果！！！

[Unity下Iso和Persp两种模式的区别](https://www.cnblogs.com/OctoptusLian/p/8848216.html#:~:text=Iso模式 平行视野。 在Iso模式下，不论物体距离摄像头远近都给人的感觉是一样大的。,Persp模式 透视视野。 在persp模式下，物体在scene界面上所呈现的画面是给人一种距离摄像头近的物体显示的大，距离摄像头远的物体显示的小。)

问题2：高光区域明显比示例大

解决：Gloss值不同，原先为20，示例中为105，Gloss为20时高光部分明显大很多

问题3：同样的贴图，颜色饱和度比示例低？

解决：Tecture参数设置，勾选Aloha IS Transparency和Remove PSD Matte

















---

[着色器语义 - Unity 手册](https://docs.unity.cn/cn/2022.3/Manual/SL-ShaderSemantics.html)

关于着色器语义



[着色器数据类型和精度 - Unity 手册](https://docs.unity.cn/cn/2020.3/Manual/SL-DataTypesAndPrecision.html)

为社么在着色器中用fixed 在结构体中用float



[现代计算机图形学 | 计算机图形学笔记 (remoooo.com)](https://docs.remoooo.com/cg01)

---

