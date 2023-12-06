Shader "Test/ToonURP2"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _AOMap("AO Map", 2D) = "white" {}
        _DiffuseRamp("Ramp", 2D) = "white" {}
        _TintLayer1("TintLayer1 Color",Color) = (0.5,0.5,0.5,1)
        _TintLayer1_Offset("TintLayer1 Offset", Range(-1,1)) = 0
        _TintLayer2("TintLayer2 Color",Color) = (0.5,0.5,0.5,1)
        _TintLayer2_Offset("TintLayer2 Offset", Range(-1,1)) = 0
        _TintLayer2_Softness("TintLayer2 Softness", Range(-1,1)) = 0
        _TintLayer3("TintLayer3 Color",Color) = (0.5,0.5,0.5,1)
        _TintLayer3_Offset("TintLayer3 Offset", Range(-1,1)) = 0
        _TintLayer3_Softness("TintLayer3 Softness", Range(-1,1)) = 0
        _SpecMap("Spec Map", 2D) = "white" {}
        _SpecColor("Spec Color",Color) =  (0.5,0.5,0.5,1)
        _SpecIntensity("Spec Intensity", float) = 1
        _SpecShininess("Spec Shininess", float) = 100

        _EnvMap("Env Map",Cube) = "white" {}
        _Roughness("Roughness", Range(0,1)) = 0
        _FresnelMin("Fresnel Min", Range(-1,2)) = 0.5
        _FresnelMax("Fresnel Max", Range(-1,2)) = 1
        _EnvIntensity("Env Intensity", float) = 0.5

        _OutlineColor("Outline Color", Color) = (0,0,0,1)
        _OutlineWidth("Outline Width", float) = 1


    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "LightMode"="UniversalForward" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
        CBUFFER_START(UnityPerMaterial)

        float4 _TintLayer1;
        float _TintLayer1_Offset;
        float4 _TintLayer2;
        float _TintLayer2_Offset;
        float _TintLayer2_Softness;
        float4 _TintLayer3;
        float _TintLayer3_Offset;
        float _TintLayer3_Softness;

        float4 _SpecColor;
        float _SpecIntensity;
        float _SpecShininess;

        float4 _EnvMap_HDR;
        float _Roughness;
        float _FresnelMin;
        float _FresnelMax;
        float _EnvIntensity;

        float _OutlineWidth;
        float4 _OutlineColor;

        CBUFFER_END

        TEXTURECUBE(_EnvMap); SAMPLER(sampler_EnvMap);
        TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
        TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
        TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
        TEXTURE2D(_AOMap); SAMPLER(sampler_AOMap);
        TEXTURE2D(_DiffuseRamp); SAMPLER(sampler_DiffuseRamp);
        TEXTURE2D(_SpecMap); SAMPLER(sampler_SpecMap);

        ENDHLSL
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord0 : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normalDir : TEXCOORD1;
                float3 tangentDir : TEXCOORD2;//切线
                float3 binormalDir : TEXCOORD3;//副切线
                float4 posWorld : TEXCOORD4;
                float4 vertexColor : TEXCOORD5;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                o.normalDir = TransformObjectToWorldNormal(v.normal);
                o.tangentDir = normalize(mul(unity_ObjectToWorld,float4(v.tangent.xyz,0.0)).xyz);
                o.binormalDir = normalize(cross(o.normalDir,o.tangentDir) * v.tangent.w);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.vertexColor = v.color;
                o.uv = v.texcoord0;
                return o;
            }

            // Decodes HDR textures
            // handles dLDR, RGBM formats
            half3 DecodeHDR(half4 data, half4 decodeInstructions)
            {
                // Take into account texture alpha if decodeInstructions.w is true(the alpha value affects the RGB channels)
                half alpha = decodeInstructions.w * (data.a - 1.0) + 1.0;

                // If Linear mode is not supported we can skip exponent part
#if defined(UNITY_COLORSPACE_GAMMA)
                return (decodeInstructions.x * alpha) * data.rgb;
#else
#   if defined(UNITY_USE_NATIVE_HDR)
                return decodeInstructions.x * data.rgb; // Multiplier for future HDRI relative to absolute conversion.
#   else
                return (decodeInstructions.x * pow(alpha, decodeInstructions.y)) * data.rgb;
#   endif
#endif
            }
            half4 frag (v2f i) : SV_Target
            {
                //向量
                half3 normalDir = normalize(i.normalDir);
                half3 tangentDir = normalize(i.tangentDir);
                half3 binormalDir = normalize(i.binormalDir);
                half3 lightDir = normalize(_MainLightPosition.xyz);
                half3 viewDir = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);

                //贴图数据
                half3 base_color = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap, i.uv).rgb;
                half ao =  SAMPLE_TEXTURE2D(_AOMap,sampler_AOMap, i.uv).r;
                half4 spec_map =  SAMPLE_TEXTURE2D(_SpecMap,sampler_SpecMap, i.uv);
                half spec_mask = spec_map.b;
                half spec_smoothness = spec_map.a;
                //法线贴图
                half4 normal_map = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap, i.uv);
                half3 normal_data = UnpackNormal(normal_map);
                float3x3 TBN = float3x3(tangentDir,binormalDir,normalDir);
                normalDir = normalize(mul(normal_data,TBN));

                //漫反射
                half NdotL = dot(normalDir,lightDir);
                half half_lambert = (NdotL + 1.0) * 0.5;
                half diffuse_term = half_lambert * ao;

                half3 final_diffuse = half3(0.0,0.0,0.0);
                //第一层上色(Ramp图的r通道不根据y渐变)
                half2 uv_ramp1 = half2(diffuse_term + _TintLayer1_Offset,0.5);
                half toon_diffuse1 = SAMPLE_TEXTURE2D(_DiffuseRamp,sampler_DiffuseRamp, uv_ramp1).r;
                half3 tint_color1 = lerp(half3(1.0,1.0,1.0),_TintLayer1.rgb,toon_diffuse1*_TintLayer1.a * i.vertexColor.r);
                final_diffuse = base_color*tint_color1;

                //第二层上色(Ramp图的g通道根据y渐变)
                half2 uv_ramp2 = half2(diffuse_term + _TintLayer2_Offset,i.vertexColor.g + _TintLayer2_Softness);
                half toon_diffuse2 = SAMPLE_TEXTURE2D(_DiffuseRamp,sampler_DiffuseRamp, uv_ramp2).g;
                half3 tint_color2 = lerp(half3(1.0,1.0,1.0),_TintLayer2.rgb,toon_diffuse2 * _TintLayer2.a);
                final_diffuse = final_diffuse*tint_color2;

                 //第三层上色(Ramp图的b通道根据y渐变)
                half2 uv_ramp3 = half2(diffuse_term + _TintLayer3_Offset,i.vertexColor.b + _TintLayer3_Softness);
                half toon_diffuse3 = SAMPLE_TEXTURE2D(_DiffuseRamp,sampler_DiffuseRamp, uv_ramp3).b;
                half3 tint_color3 = lerp(half3(1.0,1.0,1.0),_TintLayer3.rgb,toon_diffuse3 * _TintLayer3.a);
                final_diffuse = final_diffuse*tint_color3;

                //高光反射
                half3 H = normalize(lightDir + viewDir);
                half NdotH = dot(normalDir,H);
                half spec_term = max(0.0001,pow(NdotH,_SpecShininess * spec_smoothness))* ao ;
                half3 final_spec = spec_term * _SpecColor * _SpecIntensity * spec_mask;

                //环境反射/边缘光
                half fresnel = 1.0 - dot(normalDir,viewDir);
                fresnel = smoothstep(_FresnelMin,_FresnelMax,fresnel);
                half3 reflectDir = reflect(-viewDir,normalDir);
                float roughness = lerp(0.0, 0.95, saturate(_Roughness));
                roughness = roughness * (1.7 - 0.7* roughness);
                float mip_level = roughness * 6.0;
                half4 color_cubemap = SAMPLE_TEXTURECUBE_LOD(_EnvMap, sampler_EnvMap, reflectDir,mip_level);
                half3 env_color = DecodeHDR(color_cubemap,_EnvMap_HDR);
                half3 final_env = env_color * fresnel * _EnvIntensity * spec_mask;

                half3 final_color = final_diffuse + final_spec + final_env;
                return half4(final_color,1.0);
            }
            ENDHLSL
        }
        Pass{
            Cull Front
            Tags{"LightMode" = "SRPDefaultUnlit"}
            Name "OUTLINE"

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog


            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 texcoord0 : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o;
                v.vertex.xyz += v.normal.xyz * _OutlineWidth * 0.001 * v.color.a * v.color.b;
                o.pos = TransformObjectToHClip(v.vertex);
                o.uv = v.texcoord0;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half3 base_color = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap, i.uv.xy).xyz;
                half maxComponent = max(max(base_color.r, base_color.g),base_color.b) - 0.004;
                half3 saturatedColor = step(maxComponent.rrr,base_color) * base_color;
                saturatedColor = lerp(base_color.rgb,saturatedColor,0.6);
                half3 outlineColor = 0.8 * saturatedColor * base_color * _OutlineColor.rgb;
                return float4(outlineColor,1.0);
            }
            ENDHLSL
        }
        // 计算主光源与阴影
        pass {
            Tags{ "LightMode" = "ShadowCaster" }
                HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
                return o;
            }
            float4 frag(v2f i) : SV_Target
            {
                float4 color;
                color.xyz = float3(0.0, 0.0, 0.0);
                return color;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}