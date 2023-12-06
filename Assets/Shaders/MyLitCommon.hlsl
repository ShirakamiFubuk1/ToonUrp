
#ifndef MY_LIT_COMMON_INCLUDED
#define MY_LIT_COMMON_INCLUDED
 
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 
TEXTURE2D(_ColorMap); SAMPLER(sampler_ColorMap);
TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
TEXTURE2D(_MetalnessMask); SAMPLER(sampler_MetalnessMask);
TEXTURE2D(_SpecularMap); SAMPLER(sampler_SpecularMap);
TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
 
 
float4 _ColorMap_ST;
float4 _ColorTint;
float _NormalStrength;
float _Metalness;
float3 _SpecularTint;
float3 _EmissionTint;
 
 
 
#endif