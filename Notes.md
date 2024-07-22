



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

测试由clip函数完成，裁剪条件为纹理颜色值，通过测试部分进行光照计算（没有高光反射）





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

























---

[着色器语义 - Unity 手册](https://docs.unity.cn/cn/2022.3/Manual/SL-ShaderSemantics.html)

关于着色器语义



[着色器数据类型和精度 - Unity 手册](https://docs.unity.cn/cn/2020.3/Manual/SL-DataTypesAndPrecision.html)

为社么在着色器中用fixed 在结构体中用float
