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

	o.uv = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
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

```glsl
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
```

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





## 高级纹理

### 立方体纹理——环境映射的实现方法

天空盒

创建立方体纹理

环境映射

- 环境映射（Environment Mapping，EM）也称为反射映射（Reflection Mapping），在指定位置设置一个虚拟眼睛，生成一张虚拟的纹理图，然后把该纹理图映射到模型上，该模型表面得到的图像就是该场景的一个影像。

- 环境映射是基于图像光照的（Image Based Lighting，IBL）技术的基础，IBL的核心是**将环境贴图作为光照的来源来照亮场景**，这也是它在实时渲染中经典的应用。

- [环境纹理映射 | JunQiang's Site (rootjhon.github.io)](https://rootjhon.github.io/posts/环境纹理映射/)



#### 反射效果

通过入射光线方向和表面法线方向计算反射方向，利用反射方向对立方体纹理采样

这里利用了光路可逆的原理，已知视线方向和表面法线方向，反向求得“光源”的入射方向，立方体纹理入射方向



声明如下属性：

```glsl
_Color ("Color Tint", Color) = (1, 1, 1, 1)						物体漫反射颜色
_ReflectColor ("Reflection Color", Color) = (1, 1, 1, 1)		反射颜色
_ReflectAmount ("Reflect Amount", Range(0, 1)) = 1				反射程度
_Cubemap ("Reflection Cubemap", Cube) = "_Skybox" {}			用于环境映射的立方体纹理
```

在顶点着色器计算反射方向

```glsl
o.worldRefl = reflect(-o.worldViewDir, o.worldNormal);
```

片元着色器对立方体纹理采样

```glsl
fixed3 reflection = texCUBE(_Cubemap, worldRefl).rgb * _ReflectColor.rgb;
```

计算最终颜色时用到Lerp插值函数

```glsl
fixed3 color = ambient + lerp(diffuse, reflection, _ReflectAmount) * atten;
```

Lerp 函数的定义如下：

```glsl
public static float Lerp(float a, float b, float t);
public static Vector3 Lerp(Vector3 a, Vector3 b, float t);
public static Quaternion Lerp(Quaternion a, Quaternion b, float t);
```

Lerp 函数有三种重载形式，分别用于对 float、Vector3 和 Quaternion 类型的数值进行插值。
第一个参数 a 表示起始值，第二个参数 b 表示结束值。
第三个参数 t 表示插值的权重，取值范围为 [0, 1]，表示插值在起始值和结束值之间的权重，当 t=0 时返回起始值 a，当 t=1 时返回结束值 b，当 t=0.5 时返回 a 和 b 的平均值。

当_ReflectAmount为1时，片元的颜色就是从cubemap中采样的结果，与本身漫反射颜色无关，所以如果要加入高光效果，需要将高光放在lerp函数外



Reflection.shader：

- 如果选择在顶点着色器计算反射光线方向，不需要传递worldViewDir到片元着色器
- 增加subshader
  - 在片元着色器计算反射方向，效果：壶的棱角感变弱了
  - 增加高光反射



#### 折射

根据斯涅尔定律计算折射方向，利用折射方向对立方体纹理采样
同样用到光路可逆原理，并且一般只计算一次折射



声明如下属性：

```glsl
_Color ("Color Tint", Color) = (1, 1, 1, 1)						漫反射颜色
_RefractColor ("Refraction Color", Color) = (1, 1, 1, 1)		折射颜色
_RefractAmount ("Refraction Amount", Range(0, 1)) = 1			折射射程度
_RefractRatio ("Refraction Ratio", Range(0.1, 1)) = 0.5			介质透射比
_Cubemap ("Refraction Cubemap", Cube) = "_Skybox" {}			用于环境映射的立方体纹理
```

和反射不同在于折射方向的计算，视线方向和表面法线都需要归一化，还需要介质的透射比：

```glsl
o.worldRefr = refract(-normalize(o.worldViewDir), normalize(o.worldNormal), RefractRatio);
```

透射比 =  入射光线所在介质折射率/折射光线所在介质折射率；透射比为1时，效果就像单纯遮挡了一块毛玻璃，光路没有变化



Reflection.shader：

- 增加subshader，在片元着色器计算折射方向 效果：几乎看不出差别，水壶折射的背景几乎不变，只是棱处有些许变化，本身一次折射就是大致模拟，在顶点计算折射方向就很合适



#### 菲涅尔反射

*菲涅耳公式（或菲涅耳方程），由奥古斯丁·让·菲涅耳导出。用来描述光在不同折射率的介质之间的行为。菲涅尔公式是光学中的重要公式，用它能解释反射光的强度、折射光的强度、相位与入射光的角度的关系。简单的讲，就是视线垂直于表面时，反射较弱，而当视线非垂直表面时，夹角越小，反射越明显。如果你看向一个圆球，那圆球中心的反射较弱，靠近边缘较强*

光线照射到物体表面时，一部分发生反射，一部分进入物体内部，发生折射或散射。反射的光和折射的光之间存在比例关系，根据视角方向控制菲涅尔反射强度，主要用来模拟边缘光照效果。

常用于车漆和水面等材质的渲染，模拟更加真实的效果

[团结引擎 - 手册: 菲涅耳效应 (unity.cn)](https://docs.unity.cn/cn/tuanjiemanual/Manual/StandardShaderFresnel.html) 表面处于掠射（入射角接近90°）时出现反射效果，随着材质的光滑度上升，反射变得更加明显和清晰。



声明参数：

```glsl
_Color ("Color Tint", Color) = (1, 1, 1, 1)
_FresnelScale ("Fresnel Scale", Range(0, 1)) = 0.5			调整菲涅尔反射程度
_Cubemap ("Reflection Cubemap", Cube) = "_Skybox" {}
```

和普通反射效果实现差别在于反射量计算和反射颜色插值计算

插值使用的反射程度fresnel根据当前片元视线方向和表面法线方向确定

```glsl
//Reflection
fixed3 reflection = texCUBE(_Cubemap, i.worldRefl).rgb * _ReflectColor.rgb;
fixed3 color = ambient + lerp(diffuse, reflection, _ReflectAmount) * atten;

//Fresnel
fixed3 reflection = texCUBE(_Cubemap, i.worldRefl).rgb;//也可以使用_ReflectColor控制反射颜色
fixed fresnel = _FresnelScale + (1 - _FresnelScale) * pow(1 - dot(worldViewDir, worldNormal), 5);
fixed3 color = ambient + lerp(diffuse, reflection, saturate(fresnel)) * atten;
```

也可以不使用插值混合的方法，将反射光照乘fresnel叠加到漫反射光照上





### 渲染纹理



渲染目标纹理 Render Target Texture

多重渲染目标 Multiple Render Target

渲染纹理 Render Texture





#### 镜子效果

本节使用渲染纹理实现镜子效果，需要预先准备一个相机，将渲染目标设为一个渲染纹理



过程极其简单：

顶点着色器输入模型空间的顶点坐标和顶点的纹理坐标，计算镜像的纹理坐标（镜像对称只需要翻转x分量）

片元着色器对渲染纹理采样



#### 玻璃效果

GrabPass：将当前屏幕图像绘制在一张纹理中，以便后续pass中访问，可以用来实现玻璃等透明材质模拟

注意：GrabPass需要设置透明渲染队列"Queue" = "Transparent"，确保最后绘制该物体

```glsl
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float2 texcoord: TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
			    float4 TtoW1 : TEXCOORD3;  
			    float4 TtoW2 : TEXCOORD4; 
			};
```



GrabPass决定该纹理存储位置

```glsl
GrabPass { "_RefractionTex" }
```



问题：_RefractionTex保存的是什么？



对比渲染纹理 GrabPass：

- 渲染纹理需要先创建渲染纹理和额外相机，将相机的Render Target设为渲染纹理，最后将该纹理传递给shader
- GrabPass在shader中抓取场景





### 程序纹理

程序材质：使用程序纹理的材质

[关于Unity Shader编写程序纹理报错error CS0246: The type or namespace name ‘SetProperty‘ could not be found 问题_the type or namespace name 'setproperty' could not-CSDN博客](https://blog.csdn.net/a1601611709/article/details/113099701)



问题：示例给出的cube材质为instance







## 动画

### 纹理动画

#### 序列帧动画

使用包含m x n张关键帧的图像，每个关键帧大小相同，按播放顺序排列，计算每个时刻下应当播放的关键帧的位置，对该帧进行采样

受三个参数控制：

```glsl
_HorizontalAmount ("Horizontal Amount", Float) = 4		水平方向关键帧数m
_VerticalAmount ("Vertical Amount", Float) = 4			竖直方向关键帧数n
_Speed ("Speed", Range(1, 100)) = 30					播放速度
```

通常作为透明纹理

```glsl
Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
```

顶点着色器和单张纹理基本相同，片元着色器中根据时间计算行列索引，根据索引修改纹理坐标，最后采样

```glsl
fixed4 frag (v2f i) : SV_Target {
	float time = floor(_Time.y * _Speed);  
	float row = floor(time / _HorizontalAmount);				//商
	float column = time - row * _HorizontalAmount;				//余数

//				half2 uv = float2(i.uv.x /_HorizontalAmount, i.uv.y / _VerticalAmount);
//				uv.x += column / _HorizontalAmount;
//				uv.y -= row / _VerticalAmount;
	half2 uv = i.uv + half2(column, -row);
	uv.x /=  _HorizontalAmount;
	uv.y /= _VerticalAmount;
	
	fixed4 c = tex2D(_MainTex, uv);
	c.rgb *= _Color;
	
	return c;
}
```

这里i.uv中保存的是顶点纹理坐标，含义应为在单张关键帧中的坐标，因为序列帧动画使用的纹理包含多张关键帧，所有需要先进行缩放；然后根据行、列索引进行偏移

注意纹理坐标竖直方向从下到上逐渐增大



#### 滚动背景

滚动背景通常用纹理动画实现



在顶点着色器计算纹理坐标，初始+随时间偏移，TRANSFORM_TEX(v.texcoord, _MainTex)得到初始坐标，\_ScrollX * _Time.y控制偏移，偏移范围在0-1之间，用frac函数返回小数部分

这里将两张纹理的坐标存储到同一变量uv中，减少使用的插值寄存器

```glsl
o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex) + frac(float2(_ScrollX, 0.0) * _Time.y);
o.uv.zw = TRANSFORM_TEX(v.texcoord, _DetailTex) + frac(float2(_Scroll2X, 0.0) * _Time.y);
```

案例包含两个layer，模拟视差效果，在片元着色器中将二者混合



总结：即使是渲染平面的纹理，流程上也需要创建材质，为其编写Shader实现需要的效果，也就是说Shader无法直接赋予渲染对象，要配合材质使用



### 顶点动画

纹理动画中顶点坐标不变，通过改变纹理坐标实现动画；顶点动画中，顶点的坐标发生偏移，纹理坐标不变



#### 河流案例

```glsl
Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True"}
```

设置透明渲染队列：

删除"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"中间的会被后面的覆盖掉。在framedebugger中查看，中间的一条河流最先被绘制，接着靠后的一条，最后是靠前的

设置透明渲染队列后，顺序由后往前



关闭批处理：

p235：一些SubShader使用批处理功能时会出现问题，原因是批处理会合并所有相关模型，模型各自的模型空间会丢失。本例中需要在物体的模型空间下对顶点位置进行偏移，因此需要取消批处理操作

设置该标签，framedebugger中Batch Cause提示已经禁用，否则提示Objects have different materials
实测删除"DisableBatching"="True"没有出现问题。。。



关闭剔除：

让水流的每个面都能显示，示例场景中摄像机看到的是水流的背面。



Blend命令 SrcAlpha OneMinusSrcAlpha，换其他混合方式效果突兀



顶点着色器计算顶点的偏移，x的偏移量是时间和y的函数，y z不变

```glsl
float4 offset;
offset.yzw = float3(0.0, 0.0, 0.0);
offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
o.pos = UnityObjectToClipPos(v.vertex + offset);
```

为实现流动效果，纹理坐标也需要随时间偏移

```glsl
o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
o.uv +=  float2(0.0, _Time.y * _Speed);
```

片元着色器根据纹理坐标采样，添加颜色控制实现不同层次不同颜色的效果



问题：为什么这里不透明的纹理要放到透明队列？

该Pass中使用了透明度混合，关闭ZWrite，任何使用了透明度混合的物体都需要在透明渲染队列中 [表8.1]

这又引出了另外一个问题，深度测试能明确地判断出前后关系，为什么还要用透明度混合？

此处的河流需要前后遮挡的效果，如果不使用混合，强行开启ZWrite，渲染先后顺序正确，但是波浪边缘处有空白。经检查问题出在贴图water.psd，这张贴图边缘是透明的。如果裁掉边缘透明的部分，再将其当作不透明物体处理效果就正确了



#### 广告牌案例

广告牌是根据视角方向来旋转的被纹理着色的多边形

构建旋转矩阵，需要三个基向量，表面法线，指向上的方向和指向右的方向，锚点：旋转过程中固定不变的位置



基向量的构建：

- 广告牌法线方向：指向视线方向

- 广告牌指向右方向right：广告牌法线 x 指向上方向up（注意：这里使用的up是人为规定的，最终up值并不一定等于up）

- 广告牌指向上方向up'：广告牌法线 x right



```
计算过程通常是，我们首先会通过初始计算得到目标的表面法线（例如就是视角方向〉和指向上的方向，而两者往往是不垂直的。但是，两者其中之一是固定的，例如当模拟草丛时，我们希望广告牌的指向上的方向永远是（0, 1，0)，而法线方向应该随视角变化；而当模拟粒子效果时，我们希望广告牌的法线方向是固定的，即总是指向视角方向，指向上的方向则可以发生变化
```

这里可以了解到广告牌有两种效果，一是转向相机但永远垂直，而是始终朝向相机，这一点在Billboard.shader中通过_VerticalBillboarding调整，后续已给出问题分析



Billboard.shader：

新增属性_VerticalBillboarding，调整固定发现还是固定指向上的方向

使用透明纹理，设置Subshader标签

```glsl
Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True"}
```

再次说明，包含模型空间顶点动画的Shader通常需要设置DisableBatching，因为批处理会合并所有相关模型，模型各自的模型空间会被丢失（实测注释掉仍然没有变化）



重点在顶点着色器，计算在模型空间下完成

```glsl
v2f vert (a2v v) {
	v2f o;
    //法线计算：
	//在模型空间选择一个锚点，将相机从世界空间变换到模型空间
    //二者做差得到广告牌的法线（视线方向）
	float3 center = float3(0, 0, 0);
	float3 viewer = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos, 1));
	float3 normalDir = viewer - center;

    //确定初始up    
	normalDir.y =normalDir.y * _VerticalBillboarding;
	normalDir = normalize(normalDir);
	float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
    //计算right，up'
	float3 rightDir = normalize(cross(upDir, normalDir));
	upDir = normalize(cross(normalDir, rightDir));
	
	// 根据原始位置相对锚点的偏移量和正交基，计算旋转后的新位置
	float3 centerOffs = v.vertex.xyz - center;
	float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;

	o.pos = UnityObjectToClipPos(float4(localPos, 1));
	o.uv = TRANSFORM_TEX(v.texcoord,_MainTex);

	return o;
}
```





问题：Vertical Restraints属性作用是什么？

个人理解：有时候并不希望广告牌永远朝向镜头，我们希望能以某个方向为轴旋转，案例中是绕y轴在竖直面内旋转，_VerticalBillboarding置为0或1可以实现两种不同的朝向相机效果：

Vertical Restraints = 0，此时normalDir的y分量为0，将法线约束再水平面，以（0，1，0）为初始指向上的方向，计算right，最终计算得到up仍然是（0，1，0），这种情况下广告牌绕y轴再竖直面旋转；

Vertical Restraints = 1，此时以（0，1，0）为初始指向上的方向，计算right，再计算得到up，这时候的up不一定是（0，1，0），广告牌表现为始终朝向摄像机；（*这是一步挺逆天的操作，我不清楚“用一个假的up计算出right，再根据normal和right计算出真正的up”这样做的道理在哪里，但是确实可行*）

```glsl
float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
```

这里还需要避免视线方向与初始规定up（0，1，0）平行的情况，使用了一个条件运算符判断。





问题：有没有可能实现一个绕x轴旋转的广告牌？

可以，绕y轴旋转，限制upDir =  1，绕x轴旋转，限制right=1即可



通过重新定义基向量并将顶点位置投影到这些新的基向量上，可以实现对顶点的旋转变换。这种方法利用了基向量的线性组合特性，可以实现任意旋转变换，并保证顶点在新坐标系中的正确位置

参见p69 p70坐标空间的变换

````
You: 

能否解释一下float3 centerOffs = v.vertex.xyz - center;
	float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;

ChatGPT: 

当然可以。这两行代码的目的是根据计算出来的方向向量（`rightDir`、`upDir`、`normalDir`）对顶点进行位置变换，以实现广告牌效果。具体来说，这两行代码将顶点的局部坐标（相对于中心点）转换为新的位置，以便使广告牌面向相机。
### 代码片段 


```hlsl
float3 centerOffs = v.vertex.xyz - center;
float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
```

### 详细解释 
 
1. **计算顶点相对于中心点的偏移量：** 

```hlsl
float3 centerOffs = v.vertex.xyz - center;
```
 
  - `v.vertex.xyz` 是输入顶点的坐标。
 
  - `center` 是中心点坐标，在代码中通常是 `(0, 0, 0)`。
 
  - `centerOffs` 表示顶点相对于中心点的偏移量。
 
  - 通过减去中心点坐标，得到一个向量 `centerOffs`，表示顶点从中心点出发的偏移量。
 
2. **计算新的顶点位置：** 

```hlsl
float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
```
 
  - 这一行代码使用三个方向向量（`rightDir`、`upDir` 和 `normalDir`）来重新计算顶点的位置。
 
  - 公式的每一部分含义如下：
 
    - `center`：添加中心点坐标，作为基准点。
 
    - `rightDir * centerOffs.x`：将顶点相对于中心点的 x 方向偏移量 `centerOffs.x` 投影到右方向 `rightDir` 上。`rightDir` 是一个单位向量，表示新的右方向。
 
    - `upDir * centerOffs.y`：将顶点相对于中心点的 y 方向偏移量 `centerOffs.y` 投影到向上方向 `upDir` 上。`upDir` 是一个单位向量，表示新的向上方向。
 
    - `normalDir * centerOffs.z`：将顶点相对于中心点的 z 方向偏移量 `centerOffs.z` 投影到法线方向 `normalDir` 上。`normalDir` 是一个单位向量，表示新的法线方向。
 
  - 通过将顶点的局部偏移量投影到新的坐标系中，计算出顶点在新坐标系中的位置 `localPos`。

### 总结 
 
- **`centerOffs`** ：表示顶点相对于中心点的偏移量。
 
- **`localPos`** ：使用新的坐标系（由 `rightDir`、`upDir` 和 `normalDir` 定义）重新计算顶点的位置。

这个过程可以实现广告牌效果，使广告牌能够根据相机的位置动态调整其方向，始终面向相机。通过将顶点的偏移量转换到新的坐标系，确保广告牌在3D空间中的正确显示。

You: 

这相当于旋转吗

ChatGPT: 

是的，这相当于对顶点进行旋转变换。具体来说，代码中的变换是基于局部坐标系（由 `rightDir`、`upDir` 和 `normalDir` 定义）重新计算顶点位置，从而实现对顶点的旋转。以下是详细的解释：
### 代码片段 


```hlsl
float3 centerOffs = v.vertex.xyz - center;
float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
```

### 详细解释 
 
1. **计算顶点相对于中心点的偏移量：** 

```hlsl
float3 centerOffs = v.vertex.xyz - center;
```
 
  - `centerOffs` 是顶点相对于中心点的偏移量，表示顶点在局部坐标系中的位置。
 
2. **计算新的顶点位置：** 

```hlsl
float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
```
 
  - `rightDir`、`upDir` 和 `normalDir` 分别表示新的右方向、向上方向和法线方向。这些方向向量共同定义了一个新的局部坐标系。
 
  - 顶点的原始位置 `v.vertex.xyz` 在新的局部坐标系中的位置通过以下步骤计算： 
    - `rightDir * centerOffs.x`：将原始位置的 x 方向分量 `centerOffs.x` 投影到新的右方向上。
 
    - `upDir * centerOffs.y`：将原始位置的 y 方向分量 `centerOffs.y` 投影到新的向上方向上。
 
    - `normalDir * centerOffs.z`：将原始位置的 z 方向分量 `centerOffs.z` 投影到新的法线方向上。
 
  - 最终的 `localPos` 是将这些投影结果相加，并加上中心点的位置，得到顶点在新坐标系中的位置。

### 旋转变换 

通过这个过程，顶点的原始位置被重新计算为在新坐标系中的位置，实际上相当于对顶点进行了旋转变换。以下是具体的旋转过程：
 
1. **定义新的局部坐标系：**  
  - `rightDir`、`upDir` 和 `normalDir` 定义了新的局部坐标系的基向量。
 
2. **将顶点位置转换到新坐标系：**  
  - 原始顶点位置 `v.vertex.xyz` 相对于中心点的位置被分解到新坐标系的基向量上。
 
3. **计算顶点在新坐标系中的位置：**  
  - 通过基向量的线性组合，计算顶点在新坐标系中的位置 `localPos`。
这种方法可以实现对顶点的任意旋转，因为新的局部坐标系的基向量 `rightDir`、`upDir` 和 `normalDir` 可以任意选择，适应不同的旋转需求。
### 总结 

- 通过将顶点的位置从原始坐标系转换到新的局部坐标系，这种变换相当于对顶点进行了一次旋转。
 
- 这种旋转是通过新的局部坐标系的基向量（`rightDir`、`upDir` 和 `normalDir`）实现的，从而使顶点在新的坐标系中正确定位。

You: 

如何用基向量进行旋转操作，能讲讲原理吗

ChatGPT: 

当然可以。利用基向量进行旋转操作是计算机图形学中的一个基本概念。通过旋转基向量（单位向量）来定义新的坐标系，我们可以将顶点的位置从原始坐标系转换到新的坐标系，从而实现旋转效果。以下是详细的解释。

### 基向量旋转的原理 

#### 1. 基向量定义 

在3D空间中，我们通常使用三个相互正交的基向量来定义一个坐标系：
 
- $$\mathbf{i}$$ 表示 x 轴方向的基向量
 
- $$\mathbf{j}$$ 表示 y 轴方向的基向量
 
- $$\mathbf{k}$$ 表示 z 轴方向的基向量

这三个基向量共同定义了一个右手坐标系。

#### 2. 旋转基向量 

当我们进行旋转操作时，我们实际上是在改变这些基向量的方向。例如：
 
- 旋转后的 x 轴方向基向量可以表示为 $$\mathbf{i}'$$
 
- 旋转后的 y 轴方向基向量可以表示为 $$\mathbf{j}'$$
 
- 旋转后的 z 轴方向基向量可以表示为 $$\mathbf{k}'$$

#### 3. 将顶点转换到新坐标系 
给定一个顶点的位置 $$\mathbf{v}$$，可以表示为相对于原始基向量的组合：
$$\mathbf{v} = x \mathbf{i} + y \mathbf{j} + z \mathbf{k}$$经过旋转后，顶点的位置需要转换到新的基向量下：
$$\mathbf{v}' = x \mathbf{i}' + y \mathbf{j}' + z \mathbf{k}'$$
#### 4. 具体计算方法 

通过将顶点的位置投影到新的基向量上，我们可以计算顶点在新坐标系中的位置。

### 示例代码解释 


```hlsl
float3 centerOffs = v.vertex.xyz - center;
float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
```

#### 具体步骤 
 
1. **计算相对于中心点的偏移量：** 

```hlsl
float3 centerOffs = v.vertex.xyz - center;
```
 
  - `centerOffs` 是顶点相对于中心点的偏移量，表示为 $$\mathbf{v} - \mathbf{c}$$。
 
2. **将偏移量投影到新的基向量上：** 

```hlsl
float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
```
 
  - `rightDir` 是新的 x 轴方向基向量 $$\mathbf{i}'$$
 
  - `upDir` 是新的 y 轴方向基向量 $$\mathbf{j}'$$
 
  - `normalDir` 是新的 z 轴方向基向量 $$\mathbf{k}'$$
通过将 `centerOffs` 的分量分别乘以新的基向量，我们得到顶点在新坐标系中的位置：
$$\mathbf{v}' = \mathbf{c} + x' \mathbf{i}' + y' \mathbf{j}' + z' \mathbf{k}'$$
其中：
 
  - $$x' = centerOffs.x$$
 
  - $$y' = centerOffs.y$$
 
  - $$z' = centerOffs.z$$

### 例子 

假设一个顶点在原始坐标系中的位置为 (1, 2, 3)，中心点为 (0, 0, 0)，新的基向量为：
 
- `rightDir` = (1, 0, 0) （新的 x 轴方向）
 
- `upDir` = (0, 1, 0) （新的 y 轴方向）
 
- `normalDir` = (0, 0, 1) （新的 z 轴方向）

则计算过程如下：
 
1. 计算偏移量：
$$centerOffs = (1, 2, 3) - (0, 0, 0) = (1, 2, 3)$$
 
2. 将偏移量投影到新的基向量上：
$$localPos = (0, 0, 0) + (1, 0, 0) * 1 + (0, 1, 0) * 2 + (0, 0, 1) * 3 = (1, 2, 3)$$
在这个例子中，由于新的基向量与原始基向量一致，顶点位置没有改变。如果新的基向量是经过旋转的，则 `localPos` 会是顶点在旋转后的坐标系中的新位置。
### 总结 

通过重新定义基向量并将顶点位置投影到这些新的基向量上，我们可以实现对顶点的旋转变换。这种方法利用了基向量的线性组合特性，可以实现任意旋转变换，并保证顶点在新坐标系中的正确位置。

You: 

这里normal updir right是不是可以看作原先模型坐标系A下的一组新的坐标系B的基，我们求出在B坐标空间下顶点的位置。并以B为新的模型坐标系，参与到世界坐标系下顶点位置的计算？

ChatGPT: 

是的，你的理解是正确的。这里的 `normalDir`、`upDir` 和 `rightDir` 可以看作是模型坐标系 A 下定义的一组新的坐标系 B 的基向量。通过这些基向量，我们可以将顶点的位置从坐标系 A 转换到坐标系 B，并使用坐标系 B 作为新的模型坐标系来计算顶点在世界坐标系下的位置。
### 详细解释 

#### 1. 定义新的坐标系 B 的基向量 
在代码中，`normalDir`、`upDir` 和 `rightDir` 分别表示新坐标系 B 的 z 轴、y 轴和 x 轴方向。这些向量是基于模型坐标系 A 下的法线方向和其他向量计算出来的。
#### 2. 计算顶点在新坐标系 B 下的位置 

通过以下代码，我们将顶点从坐标系 A 转换到坐标系 B：


```hlsl
float3 centerOffs = v.vertex.xyz - center;
float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
```
 
- `centerOffs = v.vertex.xyz - center;` 计算顶点相对于中心点的偏移量。
 
- `localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;` 将这个偏移量投影到新坐标系 B 的基向量上，得到顶点在新坐标系 B 下的位置。

#### 3. 使用新坐标系 B 计算顶点在世界坐标系下的位置 
一旦我们有了顶点在新坐标系 B 下的位置 `localPos`，就可以将它转换到世界坐标系下：

```hlsl
o.pos = UnityObjectToClipPos(float4(localPos, 1));
```

### 示例 
假设原始模型坐标系 A 的基向量为标准的单位向量（即 x 轴方向为 (1, 0, 0)，y 轴方向为 (0, 1, 0)，z 轴方向为 (0, 0, 1)）。通过 `normalDir`、`upDir` 和 `rightDir` 定义的新坐标系 B 的基向量可能是经过旋转或其他变换后的向量。
### 步骤总结 
 
1. **定义新坐标系 B 的基向量：**  
  - `normalDir`：新坐标系 B 的 z 轴方向
 
  - `upDir`：新坐标系 B 的 y 轴方向
 
  - `rightDir`：新坐标系 B 的 x 轴方向
 
2. **计算顶点在新坐标系 B 下的位置：** 
  - 通过将顶点相对于中心点的偏移量投影到新坐标系 B 的基向量上，得到顶点在新坐标系 B 下的位置。
 
3. **将顶点位置从新坐标系 B 转换到世界坐标系：** 
  - 使用新坐标系 B 的顶点位置来参与世界坐标系下的顶点位置计算。

这种方法通过定义新的坐标系 B，并将顶点位置从原始坐标系 A 转换到坐标系 B，从而实现了对顶点位置的变换（如旋转），并且在世界坐标系中保持正确的位置和方向。这在计算机图形学中是一个常见且有效的技术，用于处理各种几何变换。
````

[UnityShader精要笔记十四 纹理动画 顶点动画 - 简书 (jianshu.com)](https://www.jianshu.com/p/473603ca0e69)给出了localPos的变换矩阵



注意：

```
通过SubShader 的DisableBatching 标签来强制取消对该Unity Shader 的批处理。然而，取消批处理会带来一定的性能下降，增加了Draw Call，因此我们应该尽量避免使用模型空间下的一些绝对位置和方向来进行计算。在广告牌的例子中，为了避免显式使用模型空间的中心来作为锚点，我们可以利用顶点颜色来存储每个顶点到锚点的距离值，这种做法在商业游戏中很常见。
```



#### 顶点动画添加阴影

默认shadowcaster pass没有根据动画对顶点进行变换，故阴影仍然是原先顶点位置

```glsl
	v2f vert (appdata_base v) {
		v2f o;
		TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
		return o;
	}
```

需要在顶点着色器增加计算移动后的顶点位置

```glsl
float4 offset;
offset.yzw = float3(0.0, 0.0, 0.0);
offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
v.vertex = v.vertex + offset;
```













---

[着色器语义 - Unity 手册](https://docs.unity.cn/cn/2022.3/Manual/SL-ShaderSemantics.html)

关于着色器语义



[着色器数据类型和精度 - Unity 手册](https://docs.unity.cn/cn/2020.3/Manual/SL-DataTypesAndPrecision.html)

为社么在着色器中用fixed 在结构体中用float



[现代计算机图形学 | 计算机图形学笔记 (remoooo.com)](https://docs.remoooo.com/cg01)

---

