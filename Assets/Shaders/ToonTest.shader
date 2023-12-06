Shader "URP/Toon/ToonShader"

{

	Properties

	{
		 //[KeywordEnum(ON,OFF)] _IS_FACE("isFace",float) = 0
		[KeywordEnum(ON,OFF)] _USE_SPEC("Use Specular",float) = 0 
		[KeywordEnum(ON,OFF)] _USE_RIM("Use Rim Light",float) = 0 
		[KeywordEnum(ON,OFF)] _TOON_SHADOW("Use Toon Shadow",float) = 0 
		[KeywordEnum(2x2,4x4,8x8,Off)] _USE_DITHER("Use Dither Half Transparent",float) = 0 
		_Clip("Clip",Range(0,1)) = 0
		_Saturation("Saturation Mult",Range(0,2)) = 1.0
		_Contrast("Contrast",Range(0,2)) = 1.0
		_LightMult("Light Multi",Range(0,2)) = 1.0
		_MainTex("MainTex",2D) = "White"{}

		_BaseColor("BaseColor",Color) = (1,1,1,1)
		_ShadowColor("ShadowColor",Color) = (0.7,0.7,0.8,1)
		_ShadowRange("ShadowRange",Range(0,1)) = 0.5
		_ShadowSmooth("ShadowSmooth",Range(0,1)) = 0.05
		_ShadowOffset("ShadowOffset",float) = 1

		//_OutLineWidth("OutLineWidth",Range(0.01,2)) = 0.24
		//_OutLineColor("OutLineColor",Color) = (0.5,0.5,0.5,1)
		_Glossiness("Glossiness",Range(0,10) )=2
	    _SpecularColor("SpecularColor",Color) = (0.5,0.5,0.2)
		_rampTex("rampTex",2D)= "white"{}

		//Rim
		_RimColor("RimColor",Color) = (1,0.9,1)
		_RimMin("RimMin",Range(0,1)) = 0.1
		_RimMax("RimMax",Range(0,1)) = 0.9
		_RimBloomExp("RimBloomExp",Range(0,5)) = 0.9
		_RimBloomMulti("RimBloomMulti",Range(0,2)) = 0.9
		//_FaceShadow("FaceShadowMap",2D) = "white"{}
		_shadowControl("ShadowControl",Range(0,2)) = 1.5

		//specular 
		_Roughness("Roughness",Range(0.001,1)) = 0.01
		_DividLineSpec("DividLineSpec",Range(0.001,1)) = 0.01
		_BoundSharp("BoundSharp",Range(0.001,1)) = 0.01
		_speColor("speColor",Color) = (1,1,1)
		_speStrength("speStrength",Range(0,1)) = 0.4
	}

		SubShader

		{

			Tags
			{
				"RenderPipeline" = "UniversalRenderPipeline"
				"RenderType" = "Opaque"
			}

			HLSLINCLUDE

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)

			float _Saturation;
			float _Contrast;
			float _LightMult;
			float4 _MainTex_ST;
			half4 _BaseColor;
			half4 _ShadowColor;
			float _ShadowRange;
			float _ShadowSmooth;
			float _ShadowOffset;
			// float _OutLineWidth;
			// half4 _OutLineColor;
			float _Glossiness;
			half4 _SpecularColor;
			float4 _RimColor;
			float _RimMin;
			float _RimMax;
			float _RimSmooth;
			float _RimBloomExp;
			float _RimBloomMulti;
			float _shadowControll;
			float _Roughness;
			float _DividLineSpec;
			float _BoundSharp;
			half3 _speColor;
			float _speStrength;
			float _Clip;
			CBUFFER_END

			TEXTURE2D(_MainTex);
			TEXTURE2D(_rampTex);
			SAMPLER(sampler_rampTex);
			SAMPLER(sampler_MainTex);
			// TEXTURE2D(_FaceShadow);
			// SAMPLER(sampler_FaceShadow);

			 struct a2v
			 {
				 float4 positionOS:POSITION;
				 float4 normalOS:NORMAL;
				 float2 texcoord:TEXCOORD;
			 };

			 struct v2f

			 {

				 float4 positionCS:SV_POSITION;
				 float2 texcoord:TEXCOORD;
				 float3 normalWS:TEXCOORD1;
				 float3 positionWS:TEXCOORD2;
				 float3 headrightWS:TEXCOORD3;

			 };
			
			 float3 SH_IndirectionDiff(float3 normalWS)//漫反射
			 {

				 float4 SHCoefficients[7];

				 SHCoefficients[0] = unity_SHAr;

				 SHCoefficients[1] = unity_SHAg;

				 SHCoefficients[2] = unity_SHAb;

				 SHCoefficients[3] = unity_SHBr;

				 SHCoefficients[4] = unity_SHBg;

				 SHCoefficients[5] = unity_SHBb;

				 SHCoefficients[6] = unity_SHC;

				 float3 Color = SampleSH9(SHCoefficients, normalWS);

				 return max(0, Color);

			 }

			 float D_GGX_DIY(float a2, float NoH) {
				 float d = (NoH * a2 - NoH) * NoH + 1;
				 return a2 / (3.14159 * d * d);
			 }

			 float sigmoid(float x, float center, float sharp) {
				 float s;
				 s = 1 / (1 + pow(100000, (-3 * sharp * (x - center))));
				 return s;
			 }

   			// 2x2 Matrix
            half Dither2x2_Array(uint2 uv )
			 {
				 uv %= 2;
			 	float A2x2[4]=
				 {
			 		 0,2,
					 3,1
				 };
                
			 	return A2x2[uv.x*2+uv.y]/4;
			 	
			 }
			
   	// 		// 4x4 Matrix
    //         half Dither4x4_Array(uint2 uv )
			 // {
				//  uv %= 4;
			 // 	float A4x4[16]=
				//  {
			 // 		0,8,2,10,
				// 	 12,4,14,6,
				// 	 3,11,1,1,
				// 	 15,7,13,5
				//  };
    //             
			 // 	return A4x4[uv.x*4+uv.y]/16;
			 // 	
			 // }

   			// 4x4 Matrix
            half Dither4x4_Array(uint2 uv )
			 {
				 uv %= 4;
			 	float A4x4[16]=
				 {
			 		 0,1,2,3,
					 11,12,13,4,
					 10,15,14,5,
					 9,8,7,6
				 };
                
			 	return A4x4[uv.x*4+uv.y]/16;
			 	
			 }			
			
			// //8x8 Matrix
   //          half Dither8x8_Array(uint2 uv )
   //          {
   //              uv %= 8;
   //              float A8x8[64]=
   //              {
   //                  0,32,8,40,2,34,10,42,
   //                  48,16,56,24,50,18,58,26,
   //                  12,44,4,36,14,46,6,38,
   //                  60,28,52,20,62,30,54,22,
   //                  3,35,11,43,1,33,9,41,
   //                  51,19,59,27,49,17,57,25,
   //                  15,47,7,39,13,45,5,37,
   //                  63,31,55,23,61,29,53,21
   //              };
   //              
   //              return A8x8[uv.x*8+uv.y]/64;
   //          }

			//8x8 Matrix
            half Dither8x8_Array(uint2 uv)
            {
                uv %= 8;
                float A8x8[64]=
                {
                    0,0,8,8,2,2,10,10,
                    0,0,8,8,2,2,10,10,
                    12,12,4,4,14,14,6,6,
                    12,12,4,4,14,14,6,6,
                    3,3,11,11,1,1,9,9,
                    3,3,11,11,1,1,9,9,
                    15,15,7,7,13,13,5,5,
                    15,15,7,7,13,13,5,5
                };
                
                return A8x8[uv.x*8+uv.y]/16;
            }


			ENDHLSL
				
				
				
			pass
			{


				HLSLPROGRAM
				#pragma vertex VERT
				#pragma fragment FRAG

                //#pragma shader_feature _IS_FACE_ON _IS_FACE_OFF
				#pragma shader_feature _USE_SPEC_ON _USE_SPEC_OFF
				#pragma shader_feature _USE_RIM_ON _USE_RIM_OFF
				#pragma shader_feature _USE_DITHER_8x8 _USE_DITHER_4x4 _USE_DITHER_2x2 _USE_DITHER_OFF
				#pragma shader_feature _TOON_SHADOW_ON _TOON_SHADOW_OFF
				//#pragma shader_feature _USE_DTIHER_ON _USE_DITHER_OFF
				
				#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
				#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
				#pragma multi_compile _ _SHADOWS_SOFT
			


				v2f VERT(a2v i)

				{
					v2f o;
					o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
					o.texcoord = TRANSFORM_TEX(i.texcoord,_MainTex);
					o.normalWS = TransformObjectToWorldNormal(i.normalOS);
					o.positionWS = TransformObjectToWorld(i.positionOS);
					o.headrightWS = TransformObjectToWorld(float3(1, 0, 0));
					return o;

				}

				half4 FRAG(v2f i) :SV_TARGET

				{
					half4 col = 1;
					
					half4 tex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord) * _BaseColor;
					
					half3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
					half3 normalWS = normalize(i.normalWS);
					Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
					float3 mainLightDir = normalize(mainLight.direction);

					half3 hsv = RgbToHsv(tex);
					hsv.y *= _Saturation;
					tex = float4(HsvToRgb(hsv),1);

					half4 avgColor = (0.5,0.5,0.5,1);

					tex = lerp(avgColor,tex,_Contrast);

//#if _IS_FACE_OFF
#if _TOON_SHADOW_ON
					//half halfLambert =(dot(normalWS, mainLightDir) * 0.5 + 0.5);
					half Lambert =dot(normalWS, mainLightDir) + _ShadowOffset;
					
					
					//half3 ramp2 = SAMPLE_TEXTURE2D(_rampTex, sampler_rampTex,float2(saturate(Lambert - _ShadowRange),0.5));
					half ramp = smoothstep(0, _ShadowSmooth, Lambert - _ShadowRange);
					//half3 diffuse = step(halfLambert, _ShadowRange) * _ShadowColor + step(_ShadowRange, halfLambert) * halfLambert;
					half3 diffuse = lerp( _ShadowColor, _BaseColor, ramp);
					diffuse *= tex;
					diffuse *= (mainLight.color * _LightMult);
#elif _TOON_SHADOW_OFF
					half3 diffuse = 1;
					diffuse *= tex;
					diffuse *= (mainLight.color * _LightMult * mainLight.shadowAttenuation);
#endif
//#endif

#if _USE_RIM_ON
					
			       //边缘光RIM
					half NdotL = max(0,dot(normalWS, mainLightDir));

					half f = 1.0 - saturate(dot(viewDirWS, normalWS));
					half rimBloom = pow(f, _RimBloomExp) * _RimBloomMulti * NdotL;
					half3 rimColor = f * _RimColor.rgb * _RimColor.a*mainLight.color* rimBloom;
					
			
					half rim = smoothstep(_RimMin, _RimMax, f);
					rim = smoothstep(0, _RimSmooth, rim);
#elif _USE_RIM_OFF
					
					half3 rimColor = 0.0;
					
#endif

// #if _IS_FACE_ON
// 			     //face shadow
// 					
// 					half faceshadow = SAMPLE_TEXTURE2D(_FaceShadow, sampler_FaceShadow, i.texcoord);
// 					half faceshadowL = SAMPLE_TEXTURE2D(_FaceShadow, sampler_FaceShadow, float2(1 - i.texcoord.x, i.texcoord.y));
// 					float3 headRight = i.headrightWS;
// 					
// 					float RdotL = dot(headRight, mainLightDir);
//
// 					float angle = acos(RdotL);
// 					angle = angle / PI * 2;
// 					//angle = pow(angle, _shadowControll);
//
// 					if (RdotL <= 0 && 1 < angle <= 2) {
// 						 angle = angle - 1;
// 						//faceshadow = smoothstep(0, _ShadowSmooth, faceshadow - angle);
//
// 						faceshadow = faceshadowL > angle ? 1 : 0;
// 						
// 					}
//
// 				
// 					else if (RdotL > 0 && 0 < angle <= 1) {
// 						 angle = 1 - angle;
// 						faceshadow = faceshadow > angle ? 1 : 0;
// 						 
// 					}
//
// 					else {
//
// 					
// 						faceshadow = 0;
// 						
// 					}
// 			
// 					//half rampf = smoothstep(0, _ShadowSmooth, faceshadow-angle);
// 					//faceshadow = lerp(0, 1, rampf);
// 					half3 diffuse =lerp(_ShadowColor, _BaseColor, faceshadow);
// 					diffuse *= tex;
// 					diffuse *= mainLight.color;
//
// #endif

#if _USE_SPEC_ON
					
					//specular
					half3 H = normalize(mainLightDir + viewDirWS);
					half NoH = dot(normalWS, H);
					half NDF0 = D_GGX_DIY(_Roughness * _Roughness, 1);
					half NDF_HBound = NDF0 * _DividLineSpec;
					half NDF = D_GGX_DIY(_Roughness * _Roughness, clamp(0, 1, NoH));
					half specularWin = sigmoid(NDF, NDF_HBound, _BoundSharp);
					half specular = specularWin * (NDF0 + NDF_HBound) / 2*_speStrength*_speColor;
					
					
#elif _USE_SPEC_OFF
					
					half specular = 0;
					
#endif



					uint2 uv = (uint2)i.positionCS.xy;
					
#if _USE_DITHER_8x8
					
					half ditherColor = Dither8x8_Array(uv);

//#elif _USE_DTIHER_ON

//					half ditherColor = Dither8x8_Array(uv);

#elif _USE_DITHER_4x4

					half ditherColor = Dither4x4_Array(uv);
					
#elif _USE_DITHER_2x2

					half ditherColor = Dither2x2_Array(uv);
					
#elif _USE_DITHER_OFF

					half ditherColor = 1;
					
#endif

					clip(ditherColor - _Clip);

					//return ceil(saturate(ditherColor)+0.01);
					
					float4 finalColor = mul(ceil(saturate(ditherColor)+0.0001), float4(rimColor + diffuse + specular,1));
					
					return  finalColor;
			//return  float4(diffuse,1);

				}

				ENDHLSL

			}

			UsePass "Universal Render Pipeline/Lit/ShadowCaster" 

		}
}
