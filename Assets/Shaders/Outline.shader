Shader "Unlit/Outline"
{
    Properties
    {
        [KeywordEnum(2x2,4x4,8x8,Off)] _USE_DITHER("Use Dither Half Transparent",float) = 0 
        _Clip("Clip",Range(0,1)) = 0
        _OutlineColor("Outline Color",Color) = (0,0,0,1)
        _Outline("Outline",Range(0,1)) = 0.1
    }
        SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalRenderPipeline"
        }
        LOD 100
        Cull Front

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _USE_DITHER_8x8 _USE_DITHER_4x4 _USE_DITHER_2x2 _USE_DITHER_OFF

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Atributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

               			// 2x2 Matrix
            half Dither2x2_Array(uint2 uv )
			 {
				 uv %= 2;
			 	float A2x2[4]=
				 {
			 		 0,2,
					 3,1
				 };
                
			 	return A2x2[uv.x*4+uv.y]/4;
			 	
			 }
			
   			// 4x4 Matrix
            half Dither4x4_Array(uint2 uv )
			 {
				 uv %= 4;
			 	float A4x4[16]=
				 {
			 		0,8,2,10,
					 12,4,14,6,
					 3,11,1,1,
					 15,7,13,5
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
            half Dither8x8_Array(uint2 uv )
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

            CBUFFER_START(UnityPerMaterial)
            float4 _OutlineColor;
            float _Outline;
            float _Clip;
            CBUFFER_END

            Varyings vert(Atributes v)
            {
                Varyings o = (Varyings)0;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                //法线转到屏幕坐标
               float3 vNormal = normalize(mul((float3x3)UNITY_MATRIX_IT_MV, v.normalOS));
               //再转到裁切坐标
               float2 projPos = normalize(mul((float2x2)UNITY_MATRIX_P,vNormal.xy));

               o.positionCS.xy += projPos * _Outline * 0.1;
               return o;
           }

           float4 frag(Varyings i) : SV_Target
           {

           			uint2 uv = (uint2)i.positionCS.xy;
					
				#if _USE_DITHER_8x8
									
           			half ditherColor = Dither8x8_Array(uv);

				#elif _USE_DITHER_4x4

           			half ditherColor = Dither4x4_Array(uv);
									
				#elif _USE_DITHER_2x2

           			half ditherColor = Dither2x2_Array(uv);
									
				#elif _USE_DITHER_OFF

           			half ditherColor = 1;
									
				#endif

					clip(ditherColor - _Clip);
           	
               return mul(_OutlineColor,ceil(saturate(ditherColor)+0.0001));
           	
           }
            
           ENDHLSL
       }
    }
}