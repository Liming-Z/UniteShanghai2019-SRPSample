Shader "UniteShanghai2019/Multipass"
{
	Properties
	{
		_MainTex("Main Color (RGB)", 2D) = "white" {}
		_Tint("Tint Color", Color) = (.34, .85, .92, 1)
		_Outline ("Outline width", Range (.002, 0.03)) = .005
	}

	SubShader
	{
		// We must be transparent, so other objects are drawn before this one.
		Tags { "Queue" = "Transparent" "RenderPipeline" = "LightweightPipeline" "RenderType" = "Opaque" }

		Pass
		{
			Name "Simple"
			Tags { "LightMode" = "LightweightForward" }

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library
			//#pragma prefer_hlslcc gles
			//#pragma exclude_renderers d3d11_9x

			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"



			CBUFFER_START(UnityPerMaterial)
				half4 _Tint;
				half4 _MainTex_ST;
			CBUFFER_END
		

			TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
			TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);

			struct Attributes
			{
				float4 positionOS : POSITION;
				float2 texcoord   : TEXCOORD0;
			};

			struct Varyings
			{
				float4 vertex					: SV_POSITION;
				float3 uvMain					: TEXCOORD2; // xy: uv0, z: fogCoord
			};


			Varyings vert(Attributes input)
			{
				Varyings output = (Varyings)0;
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
				output.vertex = vertexInput.positionCS;

#if UNITY_UV_STARTS_AT_TOP
				float scale = -1.0;
#else
				float scale = 1.0;
#endif
				output.uvMain.xy = TRANSFORM_TEX(input.texcoord, _MainTex);
				output.uvMain.z = ComputeFogFactor(vertexInput.positionCS.z);

				return output;
			}

			half4 frag(Varyings input) : SV_Target
			{
				half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uvMain.xy) * _Tint;

				col.xyz = MixFog(col.xyz, input.uvMain.z);

				return col;
			}
			ENDHLSL
		}

		Cull Front
        ZWrite On
        ColorMask RGB
		Pass
		{
			Name "Simple2"

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library
			//#pragma prefer_hlslcc gles
			//#pragma exclude_renderers d3d11_9x

			#pragma vertex vert
			#pragma fragment frag
			#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"


			TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
			CBUFFER_START(UnityPerMaterial)
				half4 _Tint;
				half4 _MainTex_ST;
            	float _Outline;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
				float2 texcoord   : TEXCOORD0;
				float3 normalOS : NORMAL;
			};

			struct Varyings
			{
				float4 vertex					: SV_POSITION;
				float3 uvMain					: TEXCOORD2; // xy: uv0, z: fogCoord
			};


			Varyings vert(Attributes input)
			{
				Varyings output = (Varyings)0;

                input.positionOS.xyz += input.normalOS.xyz * _Outline;


				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
				output.vertex = vertexInput.positionCS;

#if UNITY_UV_STARTS_AT_TOP
				float scale = -1.0;
#else
				float scale = 1.0;
#endif
				output.uvMain.xy = TRANSFORM_TEX(input.texcoord, _MainTex);
				output.uvMain.z = ComputeFogFactor(vertexInput.positionCS.z);

				return output;
			}

			half4 frag(Varyings input) : SV_Target
			{
				half4 col = float4(1,0,0,1);

				col.xyz = MixFog(col.xyz, input.uvMain.z);

				return col;
			}
			ENDHLSL
		}
	}
	FallBack "Hidden/InternalErrorShader"
}
