Shader "Test/ToonURP1"
{
    Properties
    {
        _BaseMap ("BaseMap", 2D) = "white" {}
        _SSSMap ("SSSMap", 2D) = "black" {}
        _ILMMap("ILM Map", 2D) = "gray" {}
        _DetailMap("Detail Map", 2D) = "white" {}
    	_FaceShadow("FaceShadowMap",2D) = "white"{}
    	_BaseColor("Base Color",Color) = (0,0,0,0) 	
        _ToonThesHold("ToonThesHold", Range(0,2)) = 0.0
        _ToonHardness("ToonHardness", float) = 50
        _SpecColor("SpecColor", Color) = (1,1,1,1)
        _SpecSize("SpecSize", Range(0,1)) = 0.1
        _RimLightColor("RimLight Color", Color) = (0,0,0,0)
    	
	    _ShadowColor("ShadowColor",Color) = (0.7,0.7,0.8,1)
		_ShadowRange("ShadowRange",Range(0,1)) = 0.5
		_ShadowSmooth("ShadowSmooth",Range(0,1)) = 0.05
		_ShadowOffset("ShadowOffset",float) = 1
        
        _RimColor("RimColor",Color) = (1,0.9,1)
		_RimBloomExp("RimBloomExp",Range(0,10)) = 0.9
		_RimBloomMulti("RimBloomMulti",Range(0,2)) = 0.9
        _RimRange("RimRange",Range(0,1)) = 0.5
        _RimSmooth("RimSmooth",Range(0,1)) = 0.06
        _RimOffsetX("RimOffsetX",Range(-1,1)) = 0
        _RimOffsetY("RimOffsetY",Range(-1,1)) = 0
        
        _Metallic("Metallic",Range(0,1)) = 0
        _Smoothness("Smoothness",Range(0,1)) = 0.5
    	
        _OutlineWidth("OutlineWidth", float) = 0.2
        _OutlineColor("OutlineColor", Color) = (1,1,1,1)
        _OutlineOffset("OutlineOffset", float) = 0
    	[KeywordEnum(ON,OFF)] _IS_FACE("isFace",float) = 0
        [KeywordEnum(ON,OFF)] _IS_METAL("isMetal",float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        LOD 100

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
//            Stencil
//            {
//                Ref 1
//                Comp Always
//                Pass Replace
//            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            
            #pragma shader_feature _IS_FACE_ON _IS_FACE_OFF
            #pragma shader_feature _IS_METAL_ON _IS_METAL_OFF
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord0 : TEXCOORD0;
                float2 texcoord1 : TEXCOORD1;
                float3 normal : NORMAL;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 pos_world: TEXCOORD1;
                float3 normal_world :TEXCOORD2;
                float4 vertex_color :TEXCOORD3;
            };

            struct BRDF
            {
                float roughness;
                float3 diffuse;
                float3 specular;
            };

            struct Surface
            {
                float alpha;
                float metallic;
                float smoothness;
                float depth;
                float dither;
                float3 normal;
                float3 color;
                float3 viewDirection;
                float3 position;
            };

            CBUFFER_START(UnityPerMaterial)
				float4 _BaseColor;
                float _ToonThesHold;
                float _ToonHardness;
                float4 _SpecColor;
                float _SpecSize;
                float4 _RimLightColor;
            	float4 _RimColor;
				float _RimBloomExp;
				float _RimBloomMulti;
                float _RimRange;
                float _RimSmooth;
                float _RimOffsetX;
                float _RimOffsetY;
				float4 _ShadowColor;
				float _ShadowRange;
				float _ShadowSmooth;
				float _ShadowOffset;
                float _Metallic;
                float _Smoothness;
                float _OutlineWidth;
                float4 _OutlineColor;
                float _OutlineOffset;
            CBUFFER_END
            
            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
            TEXTURE2D(_SSSMap);SAMPLER(sampler_SSSMap);
            TEXTURE2D(_ILMMap);SAMPLER(sampler_ILMMap);
            TEXTURE2D(_DetailMap);SAMPLER(sampler_DetailMap);
            TEXTURE2D(_FaceShadow);SAMPLER(sampler_FaceShadow);

#define MIN_REFLECTIVITY 0.04

            float Square (float v)
            {
                return v * v;
            }


            float OneMinusReflectivity(float metallic)
            {
                float range = 1.0 - MIN_REFLECTIVITY;
                //
                return range - metallic * range;
            }

            BRDF GetBRDF(Surface surface)
            {
                BRDF brdf;
                
                float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);
                float perceptualRoughness =
                    PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);
                
                brdf.diffuse = surface.color * oneMinusReflectivity;
                brdf.specular = lerp(MIN_REFLECTIVITY,surface.color,surface.metallic);
                brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

                return brdf;
            }

            float SpecularStrength (Surface surface,BRDF brdf,Light light)
            {
                float3 h = SafeNormalize(light.direction + surface.viewDirection);
                float nh2 = Square(saturate(dot(surface.normal,h)));
                float lh2 = Square(saturate(dot(light.direction,h)));
                float r2 = Square(brdf.roughness);
                float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
                float normalization = brdf.roughness * 4.0 + 2.0;

                return r2 / (d2 * max(0.1,lh2) * normalization);
            }

            float3 DirectBRDF(Surface surface,BRDF brdf,Light light)
            {
                return SpecularStrength(surface,brdf,light);
            }

            float3 IncomingLight (Surface surface,Light light)
            {
                return saturate(dot(surface.normal,light.direction)*light.distanceAttenuation)*light.color;
            }

            float3 GetLighting (Surface surface, BRDF brdf,Light light)
            {
                //非PBR
                //return IncomingLight(surface,light) * surface.color * brdf.diffuse;
                //PBR
                return IncomingLight(surface,light) * DirectBRDF(surface, brdf, light);
            }
                        
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                o.pos_world = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.normal_world = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);
                o.uv = float4(v.texcoord0,v.texcoord1);
                o.vertex_color = v.color;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half2 uv1 =  i.uv.xy;
                half2 uv2 =  i.uv.zw;
                //获取光照
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.pos_world.xyz));
                //向量
                float3 normalDir = normalize(i.normal_world);
                float3 lightDir = normalize(_MainLightPosition.xyz);
                float3 viewDir =  normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                //base贴图
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,uv1);
                half3 baseColor = baseMap.rgb;//亮部颜色
                half baseMask = baseMap.a;//区分皮肤区域
                //sss贴图
                half4 sssMap = SAMPLE_TEXTURE2D(_SSSMap,sampler_SSSMap,uv1);
                half3 sssColor = sssMap.rgb;//暗部颜色
                half sssAlpha = sssMap.a;//边缘光的强度控制
                //ILM贴图
                half4 ilmMap = SAMPLE_TEXTURE2D(_ILMMap,sampler_ILMMap,uv1);
                half specIntensity = ilmMap.r;//控制高光强度
                half diffuseControl = ilmMap.g * 2.0 - 1.0;//控制光照的偏移
                half specSize = ilmMap.b;//控制高光形状大小
                half innerLine = ilmMap.a;//内描线
                //顶点色
                float ao = i.vertex_color.r;
                //金属区域
                Surface surface = (Surface)0;
                surface.position = i.pos;
                surface.normal = normalize(i.normal_world);
                surface.color = baseColor.rgb;
                surface.alpha = 1;
                surface.metallic = _Metallic;
                surface.smoothness = _Smoothness;
                surface.viewDirection = normalize(_WorldSpaceCameraPos - i.pos);
                surface.depth = -TransformWorldToView(i.pos).z;
                surface.dither = 0;
                BRDF brdf = GetBRDF(surface);

			#ifdef _IS_METAL_ON                
                float3 final_metalColor = GetLighting(surface,brdf,GetMainLight()) * specSize * 2;
			#elif _IS_METAL_OFF
                float3 final_metalColor = 0;
			#endif
                

                //漫反射
                half NdotL = dot(normalDir,lightDir);
                half half_lambert = saturate((NdotL + 1.0) * 0.5);
                half lambert_term = half_lambert * ao + diffuseControl;
                half toon_diffuse = 1-saturate((lambert_term - _ToonThesHold) * _ToonHardness);
            	
                //测试阴影
                half testNdotL = dot(lightDir,i.normal_world);
                half shadowThreshold = ilmMap.g;
                shadowThreshold *= i.vertex_color;
                shadowThreshold = 1-shadowThreshold;
                float specularIntensity = ilmMap.r;
                float specularSize = 1-ilmMap.b;
                float3 brightColor = baseColor.rgb;
                float3 shadowColor = baseColor.rgb * sssColor.rgb;
                
                testNdotL -= shadowThreshold;
                testNdotL -= 0.2f;

                half specStrength = specularIntensity;

                float4 test_Color = float4(0,0,0,1);

				if (testNdotL < 0)
				{
					
					if ( testNdotL < - specularSize -0.5f && specStrength <= 0.5f) // -0.5f)
					{
						test_Color.rgb = shadowColor *(0.5f + specStrength);// (specStrength + 0.5f);// 0.5f; //  *s.ShadowColor;
					}
					else
					{
						test_Color.rgb = shadowColor;
					}
				}
				else
				{
					if (specularSize < 1 && testNdotL * 1.8f > specularSize && specStrength >= 0.5f) //  0.5f) // 1.0f)
					{
						test_Color.rgb = brightColor * (0.5f + specStrength);// 1.5f;//  *(specStrength * 2);// 2; // lighter
					}
					else
					{
						test_Color.rgb = brightColor;
					}
				
				}
            	
            	//阴影
            	half Lambert = dot(i.normal_world,mainLight.direction) + _ShadowOffset;
            	half ramp = smoothstep(0,_ShadowSmooth,Lambert-_ShadowRange);
                //half3 final_diffuse = lerp(base_color,sss_color,toon_diffuse)*mainLight.shadowAttenuation;
                half3 final_diffuse = lerp(baseColor,baseColor*sssColor,toon_diffuse);
                //half3 final_diffuse = lerp(brightColor,shadowColor,toon_diffuse);
                //half3 final_diffuse = lerp(_ShadowColor*sss_color.r,base_color,ramp);

#ifndef  _IS_FACE_ON            	
            	half3 final_shadow = lerp(_ShadowColor,float3(1,1,1),ramp);            	
            	final_diffuse *= final_shadow;
#endif            	
            	
                //高光
                float NdotV = (dot(normalDir,viewDir) +1 )*0.5;
                float spec_term = NdotV * ao + diffuseControl;
                spec_term = half_lambert * 0.9 + spec_term * 0.1;
                half3 toon_spec = saturate((spec_term - 1.0 + specSize*_SpecSize)*500);
                toon_spec *= lerp(0.05,0.8,max(dot(i.normal_world,mainLight.direction),0.0));
                half3 spec_color = (_SpecColor.rgb + baseColor) * 0.5;
                half3 final_spec = spec_color * toon_spec * specIntensity;

                // //补光
                // half NdotL_rim = NdotV*NdotV;
                // half rimlight_term = NdotL_rim  + diffuse_control;
                // half toon_rimlight = 1-saturate((rimlight_term - _ToonThesHold) * 20);
                // half3 rim_color = (_RimLightColor.rgb +base_color) * 0.5;
                // float3 final_rimlight = toon_rimlight * rim_color * max(base_mask,0.3) * (1-toon_diffuse) * _RimLightColor.a;

                //边缘光
                half f = 1.0 - saturate(dot(viewDir,i.normal_world));
                half rimRamp = smoothstep(0,_RimSmooth,dot(normalDir,viewDir-float3(_RimOffsetX,_RimOffsetY,0)) - _RimRange);
                half rimBloom = pow(f,_RimBloomExp) * _RimBloomMulti * NdotL;
                half3 final_rimlight = f * _RimColor.rgb * _RimColor.a * mainLight.color * rimBloom * max(baseMask,0.3);
                final_rimlight = max(0,final_rimlight);
                final_rimlight = lerp(float3(1,1,1),final_rimlight,rimRamp) * _RimColor;
                
                //内描线
                half3 inner_line_color = lerp(baseColor * 0.2 ,float3(1.0,1.0,1.0),innerLine);
                half3 detail_color = SAMPLE_TEXTURE2D(_DetailMap,sampler_DetailMap,uv2);//第二套uv
                detail_color = lerp(baseColor * 0.2 ,float3(1.0,1.0,1.0),detail_color);
                half3 final_line = inner_line_color * inner_line_color * detail_color;
                half3 final_color = (test_Color + final_spec + final_rimlight)*max(0.8,final_metalColor)*final_line*_BaseColor;
                //final_color = sqrt(max(exp2(log2(max(final_color, 0.0)) * 2.2),0.0));
                //final_color = sss_map * base_color;


#if _IS_FACE_ON
                //face shadow
				float4 leftFaceTex = SAMPLE_TEXTURE2D(_FaceShadow, sampler_FaceShadow, i.uv);
				float4 rightFaceTex = SAMPLE_TEXTURE2D(_FaceShadow, sampler_FaceShadow, float2(1 - i.uv.x, i.uv.y));
				float2 left = normalize(TransformObjectToWorld(float3(1,0,0)).xz);
            	float2 front = normalize(TransformObjectToWorld(float3(0,0,1)).xz);
            	float2 mainLightDir = normalize(mainLight.direction.xz);
                
                float angle = 1-clamp(0,1,dot(front,mainLightDir)*0.5+0.5);
                float texDirect = dot(mainLightDir,left)>0?rightFaceTex.r:leftFaceTex.r;
                float bias = smoothstep(0,_ShadowSmooth,abs(angle-texDirect));
                float isShadow = step(texDirect,angle);
                if(angle>0.99||isShadow==1)
                {
                    final_color*=lerp(float3(1,1,1),_ShadowColor.rgb,bias);
                }
#endif
                return float4(final_color,1.0);
            }


            
            ENDHLSL
        }
        Pass{
            Cull Front
            Tags{"LightMode" = "SRPDefaultUnlit"}
//            Stencil
//            {
//                Ref 1
//                Comp NotEqual
//                Pass Keep
//            }
            Name "OUTLINE"

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            CBUFFER_START(UnityPerMaterial)
            float _OutlineWidth;
            float4 _OutlineColor;
            float _OutlineOffset;
            CBUFFER_END

            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 texcoord0 : TEXCOORD0;
                float4 color : COLOR;
                float4 tangent : TANGENT;
                float4 vertexColor : TEXCOORD1;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float invLerp(float from, float to, float value){
                return (value - from) / (to - from);
            }

            v2f vert(appdata v)
            {
                v2f o;
                float3 positionWS = TransformObjectToWorld(v.vertex);
                float4 positionVS = TransformWorldToView(positionWS).z;
                float eyeDepth = positionVS.z * positionVS.w;
                float depthAlpha = saturate(invLerp(5,100,eyeDepth));
                float finalWidth = lerp(0.05,0.03,depthAlpha) * _OutlineWidth;
                float4 clipPosition = TransformObjectToHClip(v.vertex);
                float3 normalCS = mul((float3x3)UNITY_MATRIX_MVP,v.tangent);
                float2 screenOffset = normalize(normalCS.xy)/_ScreenParams.xy*clipPosition.w;
                clipPosition.xy += (screenOffset * _OutlineWidth * 10 + _OutlineOffset);
                v.vertex.xyz += v.tangent.xyz * _OutlineWidth * 0.01 * v.color.a * v.color.b; 
                //o.pos = TransformObjectToHClip(v.vertex);
                o.pos = TransformObjectToHClip(v.vertex + v.tangent * finalWidth);
                o.uv = v.texcoord0;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half3 base_color = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv.xy).xyz;
                half maxComponent = max(max(base_color.r, base_color.g),base_color.b) - 0.004;
                half3 saturatedColor = step(maxComponent.rrr,base_color)*base_color;
                saturatedColor = lerp (base_color.rgb,saturatedColor,0.6);
                //half3 outlineColor = 0.8 * saturatedColor * base_color * _OutlineColor.rgb;
                half3 outlineColor = _OutlineColor.rgb;
                return float4(outlineColor,1.0);
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster" 
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
