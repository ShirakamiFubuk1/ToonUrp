Shader "Test/ToonURP3"

{
 
    Properties{
            [Header(Surface options)]
            [MainTexture] _ColorMap("Albedo", 2D) = "white" {}
            [MainColor] _ColorTint("Tint", Color) = (1, 1, 1, 1)
            
            [NoScaleOffset][Normal] _NormalMap("Normal", 2D) = "bump" {}
            _NormalStrength("Normal strength", Range(0, 1)) = 1
            [NoScaleOffset] _MetalnessMask("Metalness mask", 2D) = "white" {}
            _Metalness("Metalness strength", Range(0, 1)) = 0
            [Toggle(_SPECULAR_SETUP)] _SpecularSetupToggle("Use specular workflow", Float) = 0
            [NoScaleOffset] _SpecularMap("Specular map", 2D) = "white" {}
            _SpecularTint("Specular tint", Color) = (1, 1, 1, 1)
            _Smoothness("Smoothness multiplier", Range(0, 1)) = 0.5
            [NoScaleOffset] _EmissionMap("Emission map", 2D) = "white" {}
            [HDR] _EmissionTint("Emission tint", Color) = (0, 0, 0, 0)
            
 
            [HideInInspector] _SurfaceType("Surface type", Float) = 0
            [HideInInspector] _BlendType("Blend type", Float) = 0
            [HideInInspector] _FaceRenderingMode("Face rendering type", Float) = 0
 
            
            _Step("Toon Color Steps", Float) = 5
            _Offset("Toon Color Offset", Float) = 0.03
            _Extrude("Edge Extrude", Float) = 1.0
            _EdgeColor("Edge Color", Color) = (0, 0, 0, 0)
 
            [Toggle(BLACK_AND_WHITE)] BlackAndWhiteToggle("Black and white", Float) = 0
    }
 
        SubShader{
            Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel" = "4.5"}
 
            Pass {
                Name "ForwardLit"
                Tags{"LightMode" = "UniversalForward"}
 
                Blend One Zero
                ZWrite On
                Cull Back
 
                HLSLPROGRAM
 
                #define _NORMALMAP
                #pragma shader_feature_local_fragment _SPECULAR_SETUP
 
#if UNITY_VERSION >= 202120
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
#else
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#endif
                #pragma multi_compile_fragment _ _SHADOWS_SOFT
#if UNITY_VERSION >= 202120
                #pragma multi_compile_fragment _ DEBUG_DISPLAY
#endif
                #pragma shader_feature_local_fragment BLACK_AND_WHITE
                #pragma vertex Vertex
                #pragma fragment Fragment
 
                #include "MyToonForwardLitPass.hlsl"
                ENDHLSL
            }
        Pass{
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}
 
            ColorMask 0
            Cull Back
 
            HLSLPROGRAM            
            #pragma vertex Vertex
            #pragma fragment Fragment
 
            #include "MyLitShadowCasterPass.hlsl"
            ENDHLSL
        }
        Pass
        {
            
            Name"Edge"            
            Cull Front
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
 
             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"           
                
            float _Extrude;
            float4 _EdgeColor;            
 
            struct vIn
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
            };
 
            struct vOut
            {
                float4 positionCS   : SV_POSITION;
                
 
            };
 
            vOut vert(vIn i)
            {
                vOut o;
                float4 dir;
                dir.xyz = normalize(i.normalOS);
                i.positionOS = i.positionOS + dir * _Extrude;
                const VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS);
 
                o.positionCS = vertexInput.positionCS;
                return o;
            }
 
            half4 frag(vOut o) : SV_Target
            {
                return _EdgeColor;
            }
            ENDHLSL
        }
 
 
    }
 
 
}
