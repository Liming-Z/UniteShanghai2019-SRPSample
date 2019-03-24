Shader "UniteShanghai2019/Opaque as refraction"
{
	Properties
	{
		_MainTex("Tint Color (RGB)", 2D) = "white" {}
		_TintAmt("Tint Amount", Range(0,1)) = 0.1
		_BumpAmt("Distortion", Range(0,0.2)) = 0.1
		_BumpMap("Normalmap", 2D) = "bump" {}
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
				half _BumpAmt;
				half _TintAmt;
				half4 _BumpMap_ST;
				half4 _MainTex_ST;
			CBUFFER_END
		

			TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
			TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
			TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture_linear_clamp);

			half2 DistortionUVs(float3 normalWS)
			{
				//half2 distortion;
				half3 viewNormal = mul((float3x3)GetWorldToHClipMatrix(), -normalWS).xyz;

				return viewNormal.xz * 0.5;
			}

			//half3 Refraction(half2 distortion, half mip)
			//{
			//	half3 refrac = SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture, sampler_CameraOpaqueTexture_linear_clamp, distortion, mip);
			//	return refrac;
			//}

			half3 RefractionSimple(half2 uv)
			{
				half3 refrac = SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture, sampler_CameraOpaqueTexture_linear_clamp, uv, 0).xyz;
				return refrac;
			}

			struct Attributes
			{
				float4 positionOS : POSITION;
				float2 texcoord   : TEXCOORD0;
			};

			struct Varyings
			{
				float4 vertex					: SV_POSITION;
				float4 uvGrab		            : TEXCOORD0; 
				float2 uvBump					: TEXCOORD1;
				float3 uvMain					: TEXCOORD2; // xy: uv0, z: fogCoord
				half4  screenCoord				: TEXCOORD6;	// for ssshadows
				float3	posWS					: TEXCOORD4;	// world position of the vertices
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
				output.uvGrab.xy = (float2(output.vertex.x, output.vertex.y*scale) + output.vertex.w) * 0.5;
				output.uvGrab.zw = output.vertex.zw;
				output.uvBump = TRANSFORM_TEX(input.texcoord, _BumpMap);
				output.uvMain.xy = TRANSFORM_TEX(input.texcoord, _MainTex);
				output.uvMain.z = ComputeFogFactor(vertexInput.positionCS.z);

				output.posWS = TransformObjectToWorld(input.positionOS.xyz);
				output.screenCoord = ComputeScreenPos(output.vertex);

				return output;
			}

			half4 frag(Varyings input) : SV_Target
			{
				// calculate perturbed coordinates
				// we could optimize this by just reading the x & y without reconstructing the Z
				half2 bump = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uvBump)).rg;
				//float2 offset = bump * _BumpAmt * _GrabBlurTexture_TexelSize.xy;
				//input.uvGrab.xy = offset * input.uvGrab.z + input.uvGrab.xy;

				half4 col = 0;// = tex2Dproj(_GrabBlurTexture, input.uvGrab);
				half4 tint = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uvMain.xy);

				half3 screenUV = input.screenCoord.xyz / input.screenCoord.w;//screen UVs

				//half2 distortion = bump * _BumpAmt.xx;
				half2 distortion = screenUV.xy + bump.xy *_BumpAmt;// distortion;// * clamp(depth.x, 0, 5);

				col.rgb = RefractionSimple(distortion.xy);
				col = lerp(col, tint, _TintAmt);

				col.xyz = MixFog(col.xyz, input.uvMain.z);

				//col.xyz = _BumpAmt;
				return col;
			}
			ENDHLSL
		}
	}

	FallBack "Hidden/InternalErrorShader"
}
