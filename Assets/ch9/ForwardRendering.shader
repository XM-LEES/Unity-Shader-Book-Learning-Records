Shader "Unity Shaders Book/Chapter 9/ForwardRendering"{	
    Properties {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
	}
	SubShader {
		Tags { "RenderType"="Opaque" }

		Pass { 
			Tags { "LightMode"="ForwardBase" }
		
			CGPROGRAM

            #pragma multi_compile_fwdbase
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));
				
				fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);
				
                fixed atten = 1.0;
				
                return fixed4(ambient + (diffuse + specular) * atten, 1.0);
			}
			
			ENDCG
		}

        Pass{
            Tags { "LightMode" = "ForwardAdd" }

            Blend One One
			// Blend Off
            
            CGPROGRAM

            #pragma multi_compile_fwdadd
            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            float4 _Diffuse;
            float4 _Specular;
            float _Gloss;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert (a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                // fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 worldNormal = normalize(i.worldNormal);
                #ifdef USING_DIRECTIONAL_LIGHT
                    fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                #else
                    fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                #endif
                fixed3 diffuse = _LightColor0 * _Diffuse * max(0, dot(worldNormal, worldLightDir));

                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                fixed3 halfDir = normalize(worldLightDir + viewDir);
                fixed3 specular = _LightColor0 * _Specular * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

                #ifdef USING_DIRECTIONAL_LIGHT
					fixed atten = 1.0;
				#else
					#if defined (POINT)
				        float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
				        fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
						// 线性衰减
						// float distance = length(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
						// fixed atten = 1.0 / distance;
				    #elif defined (SPOT)
				        float4 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
				        fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				    #else
				        fixed atten = 1.0;
				    #endif
				#endif

                return fixed4((diffuse + specular) * atten, 1.0);
            }

            ENDCG
        }
        
		// Pass 
		// {
            //此pass就是 从默认的fallBack中找到的 "LightMode" = "ShadowCaster" 产生阴影的Pass
			// Tags { "LightMode" = "ShadowCaster" }

			// CGPROGRAM
			// #pragma vertex vert
			// #pragma fragment frag
			// #pragma target 2.0
			// #pragma multi_compile_shadowcaster
			// #pragma multi_compile_instancing // allow instanced shadow pass for most of the shaders
			// #include "UnityCG.cginc"

		// 	struct v2f {
		// 		V2F_SHADOW_CASTER;
		// 		UNITY_VERTEX_OUTPUT_STEREO
		// 	};

		// 	v2f vert( appdata_base v )
		// 	{
		// 		v2f o;
		// 		UNITY_SETUP_INSTANCE_ID(v);
		// 		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
		// 		TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
		// 		return o;
		// 	}

		// 	float4 frag( v2f i ) : SV_Target
		// 	{
		// 		SHADOW_CASTER_FRAGMENT(i)
		// 	}
		// 	ENDCG
		// }

		// Pass{
		// 	Tags { "LightMode" = "ShadowCaster" }

		// 	CGPROGRAM

		// 	#pragma vertex vert
		// 	#pragma fragment frag
		// 	#pragma multi_compile_shadowcaster
		// 	#include "UnityCG.cginc"

		// 	struct v2f {
		// 		V2F_SHADOW_CASTER;
		// 	};

		// 	v2f vert (appdata_base v) {
		// 		v2f o;
		// 		TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
		// 		return o;
		// 	}

		// 	float4 frag(v2f i) : SV_Target{
		// 		SHADOW_CASTER_FRAGMENT(i);
		// 	}
		// 	ENDCG
		// }
	} 
	FallBack "Specular"
}
