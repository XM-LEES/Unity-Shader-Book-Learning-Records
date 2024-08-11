Shader "Unity Shaders Book/Chapter 12/ColorCull" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Hue ("Hue", Float) = 0
		_Saturation("Saturation", Float) = 1
		_Value("Value", Float) = 1
		_Reserve("Reserve", Float) = 1
	}
	SubShader {
		Pass {  
			ZTest Always Cull Off ZWrite Off
			
			CGPROGRAM  
			#pragma vertex vert  
			#pragma fragment frag  
			  
			#include "UnityCG.cginc"  
			  
			sampler2D _MainTex;  
			half _Hue;
			half _Saturation;
			half _Value;
			half _Reserve;
			  
			struct v2f {
				float4 pos : SV_POSITION;
				half2 uv: TEXCOORD0;
			};
			  
			v2f vert(appdata_img v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				return o;
			}
		
			fixed4 frag(v2f i) : SV_Target {
				fixed4 renderTex = tex2D(_MainTex, i.uv);

				fixed3 reserveColor;

				if (_Saturation < 0.01) {
					reserveColor = fixed3(1.0, 1.0, 1.0);
				} else {
					fixed p, q, t;
					fixed fraction = _Hue - floor(_Hue);
					fixed h = _Hue / 60.0;
					fixed s = _Saturation;
					fixed v = _Value;
					fixed hi = fmod(h, 6);

					if (hi < 1) {
						p = v * (1 - s);
						q = v * (1 - s * fraction);
						reserveColor = fixed3(v, q, p);
					} else if (hi < 2) {
						p = v * (1 - s);
						t = v * (1 - (1 - fraction) * s);
						reserveColor = fixed3(q, v, p);
					} else if (hi < 3) {
						p = v * (1 - s);
						q = v * (1 - s * fraction);
						reserveColor = fixed3(p, v, t);
					} else if (hi < 4) {
						p = v * (1 - s);
						t = v * (1 - (1 - fraction) * s);
						reserveColor = fixed3(p, q, v);
					} else if (hi < 5) {
						q = v * (1 - s * fraction);
						t = v * (1 - (1 - fraction) * s);
						reserveColor = fixed3(t, p, v);
					} else {
						q = v * (1 - s * fraction);
						reserveColor = fixed3(v, p, q);
					}
				}

				bool flag = (abs(renderTex.r - reserveColor.r) < 0.01 &&
							abs(renderTex.g - reserveColor.g) < 0.01 && 
							abs(renderTex.b - reserveColor.b) < 0.01);
				fixed gray = dot(renderTex.rgb, fixed3(0.299, 0.587, 0.114));
				if (_Reserve < 0.001){
					return (flag == true) ? fixed4(renderTex.rgb, renderTex.a) : fixed4(gray, gray, gray, renderTex.a);
				}else{
					return (flag == true) ? fixed4(gray, gray, gray, renderTex.a) : fixed4(renderTex.rgb, renderTex.a);
				}
			}
			ENDCG
		}  
	}
	
	Fallback Off
}
