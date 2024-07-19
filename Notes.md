[这份文档更多是对shader示例代码的比较和理解，理论涉及较少]()



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



案例使用的切线空间下的法线纹理，需要让视线向量、光线向量、法线向量统一在一个线性空间下做与光照相关的运算



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

这里是矩阵是正交的！不需要求逆，只需要转置

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

顶点坐标附加在齐次位置，这样能少传递一个参数

[3\*3] x [3*1] 矩阵向量乘法按行拆分，可读性略有下降



第二个pass给出了更加直观的实现，经验证功能是正确的

[着色器数据类型和精度 - Unity 手册](https://docs.unity.cn/cn/2020.3/Manual/SL-DataTypesAndPrecision.html)





### 渐变纹理

渐变纹理用来控制物体的漫反射光照

```glsl
Properties {
	_Color ("Color Tint", Color) = (1, 1, 1, 1)
	_RampTex ("Ramp Tex", 2D) = "white" {}
	_Specular ("Specular", Color) = (1, 1, 1, 1)
	_Gloss ("Gloss", Range(8.0, 256)) = 20
}
```

_RampTex变量用于保存渐变纹理

```glsl
fixed halfLambert  = 0.5 * dot(worldNormal, worldLightDir) + 0.5;
fixed3 diffuseColor = tex2D(_RampTex, fixed2(halfLambert, halfLambert)).rgb * _Color.rgb;
fixed3 diffuse = _LightColor0.rgb * diffuseColor;
```

渐变纹理只影响漫反射，计算半兰伯特光照，代替纹理坐标uv对渐变纹理采样



### 遮罩纹理

遮罩纹理可以保护某些区域避免修改，纹理值与表面属性相乘来控制影响的强弱，0相当于不受属性影响

```glsl
fixed specularMask = tex2D(_SpecularMask, i.uv).r * _SpecularScale;
fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss) * specularMask;
```

纹理的r分量计算掩码值，并与_SpecularScale相乘，结果越大，高光效果越明显









