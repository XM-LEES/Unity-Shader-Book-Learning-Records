Shader "Unity Shaders Book/Chapter 12/ColorCullRGb" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_R ("R", Float) = 0
		_G("G", Float) = 0
		_B("B", Float) = 0
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
			half _R;
			half _G;
			half _B;
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

				fixed3 reserveColor = fixed3(_R / 255, _G / 255, _B / 255);

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
