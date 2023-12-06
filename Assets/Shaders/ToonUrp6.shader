Shader "Test/ToonURP6"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Main Texture", 2D) = "white" {}
		// Ambient light is applied uniformly to all surfaces on the object.
		//[HDR]
		_ShadowColor("Shadow Color", Color) = (0.4,0.4,0.4,1)
		_ShadowRange("Shadow Range", Range(0,1)) = 1
		_ShadowSmooth("Shadow Smooth",Range(0,1)) = 1
		
		//[HDR]
		_SpecularColor("Specular Color", Color) = (0.9,0.9,0.9,1)
		// Controls the size of the specular reflection.
		_Glossiness("Glossiness", Float) = 32
		//[HDR]
		_RimColor("Rim Color", Color) = (1,1,1,1)
		_RimAmount("Rim Amount", Range(0, 1)) = 0.716
		// Control how smoothly the rim blends when approaching unlit
		// parts of the surface.
		_RimThreshold("Rim Threshold", Range(0, 1)) = 0.1		
	}
	SubShader
	{
		Pass
		{
			// Setup our pass to use Forward rendering, and only receive
			// data on the main directional light and ambient light.
			Tags
			{
				"RenderPipeline" = "UniversalPipeline"
				"LightMode" = "UniversalForward"
				"PassFlags" = "OnlyDirectional"
			}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// Compile multiple versions of this shader depending on lighting settings.
			//#pragma multi_compile_fwdbase

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			
			//#include "UnityCG.cginc"
			// Files below include macros and functions to assist
			// with lighting and shadows.
			//#include "Lighting.cginc"
			//#include "AutoLight.cginc"
			//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)
			float4 _Color;
			float4 _ShadowColor;
			float _ShadowRange;
			float _ShadowSmooth;
			float4 _SpecularColor;
			float _Glossiness;		
			float4 _RimColor;
			float _RimAmount;
			float _RimThreshold;
			CBUFFER_END
			
			TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
			
			struct appdata
			{
				float4 vertex : POSITION;				
				float4 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 worldNormal : NORMAL;
				float2 uv : TEXCOORD0;
				float3 viewDir : TEXCOORD1;	
				// Macro found in Autolight.cginc. Declares a vector4
				// into the TEXCOORD2 semantic with varying precision 
				// depending on platform target.
				//SHADOW_COORDS(2)
				float4 shadowCoord : TEXCOORD2;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = TransformObjectToHClip(v.vertex);
				o.worldNormal = TransformObjectToWorldNormal(v.normal);		
				o.viewDir = GetCameraPositionWS() - v.vertex;
				o.uv = v.uv;
				// Defined in Autolight.cginc. Assigns the above shadow coordinate
				// by transforming the vertex from world space to shadow-map space.
				o.shadowCoord = TransformWorldToShadowCoord(v.vertex);
				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				float3 normal = normalize(i.worldNormal);
				float3 viewDir = normalize(i.viewDir);

				// Lighting below is calculated using Blinn-Phong,
				// with values thresholded to creat the "toon" look.
				// https://en.wikipedia.org/wiki/Blinn-Phong_shading_model

				// Calculate illumination from directional light.
				// _WorldSpaceLightPos0 is a vector pointing the OPPOSITE
				// direction of the main directional light.
				float NdotL = dot(_MainLightPosition, normal);

				// Samples the shadow map, returning a value in the 0...1 range,
				// where 0 is in the shadow, and 1 is not.
				//float shadow = SHADOW_ATTENUATION(i);
				float4 SHADOW_COORDS = TransformWorldToShadowCoord(i.pos);
				Light mainLight = GetMainLight(SHADOW_COORDS);
				half shadow = mainLight.shadowAttenuation;
				float3 mainLightDir = normalize(mainLight.direction);
				
				// Partition the intensity into light and dark, smoothly interpolated
				// between the two to avoid a jagged break.
				float lightIntensity = smoothstep(0, 0.01, NdotL * shadow);	
				// Multiply by the main directional light's intensity and color.
				//float4 light = lightIntensity * _MainLightColor;

				// Calculate specular reflection.
				float3 halfVector = normalize(_MainLightPosition + viewDir);
				float NdotH = dot(normal, halfVector);
				// Multiply _Glossiness by itself to allow artist to use smaller
				// glossiness values in the inspector.
				float specularIntensity = pow(NdotH * lightIntensity, _Glossiness * _Glossiness);
				float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity);
				float4 specular = specularIntensitySmooth * _SpecularColor;				

				// Calculate rim lighting.
				float rimDot = 1 - dot(viewDir, normal);
				// We only want rim to appear on the lit side of the surface,
				// so multiply it by NdotL, raised to a power to smoothly blend it.
				float rimIntensity = rimDot * pow(NdotL, _RimThreshold);
				rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);
				float4 rim = rimIntensity * _RimColor;
				
				half Lambert = dot(normal,mainLightDir);
				half ramp = smoothstep(0, _ShadowSmooth, Lambert-_ShadowRange);
				
				float4 sample = SAMPLE_TEXTURE2D( _MainTex ,sampler_MainTex, i.uv);
				half4 diffuse = lerp(_ShadowColor,_Color,ramp);

				return (diffuse + specular + rim) * sample;
			}
			ENDHLSL
		}
		// Shadow casting support.
        //UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
}