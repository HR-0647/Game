Shader "Lit/LitFur"
{

	Properties{
		[MainColor] _BaseColor("Color",Color) = (0.5 , 0.5 , 0.5 , 1)
		_BaseMap("Base Map",2D) = "white"{}
		_NormalMap("Normal",2D) = "bump"{}
		_NormalScale("Normal Scale",Range(0.0,2.0)) = 1.0
		[Gamma] _Metallic("Metallic",Range(0.0,1.0)) = 0.5
		_Smoothness("Smoothness",Range(0.0,1.0)) = 0.5
		_FurMap("Fur Map",2D) = "white"{}
		_FurScale("Fur Scale",Range(0.0,10.0)) = 1.0
		[IntRange]_ShellAmount("Shell Amount",Range(1,14)) = 14
		_ShellStep("Shell Step",Range(0.0,0.01)) = 0.001
		_AlphaCutout("Alpha Cutout",Range(0.0,1.0)) = 0.2
		_Occlusion("Occlusion",Range(0.0,1.0)) = 0.5
		_BaseMove("Base Move",Vector) = (0.0, -0.0, 0.0, 3.0)
		_WindFreq("Wind Freq", Vector) = (0.5, 0.7, 0.9, 1.0)
		_WindMove("Wind Move",Vector) = (0.2, 0.3, 0.2, 1.0)
		_RimLightPower("Rim Light Power",Range(0.0,20.0)) = 6.0
		_RimLightIntensity("Rim Light Intensity",Range(0.0,1.0))=0.5
	}
		SubShader{
			Tags{
				"RenderType" = "Opaque"
				"RenderPipeline" = "UniversalPipeline"
				"IgnoreProjector" = "True"
			}
			LOD 100
			ZWrite On
			Cull Back

			Pass
			{
				Name "ForwardLit"
				Tags{"LightMode" = "UniversalForward"}
				HLSLPROGRAM
				#pragma	prefer_hlslcc gles
				#pragma	exclude_renderers d3d11_9x
				#pragma	target 2.0

				#pragma	shader_feature _NORMALMAP
				#pragma	shader_feature _ALPHATEST_ON
				#pragma	shader_feature _ALPHAPREMULTIPLY_ON
				#pragma	shader_feature _EMISSION
				#pragma	shader_feature _METALLICSPECGLOSSMAP
				#pragma	shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
				#pragma	shader_feature OCCLUSIONMAP

				#pragma	shader_feature _SPECULARHIGHLIGHTS_OFF
				#pragma	shader_feature _ENVIRONMENTREFLECYIONS_OFF
				#pragma	shader_feature _SPECULAR_SETUP
				#pragma	shader_feature _RECEIVE_SHADOWS_OFF
				
				#pragma	multi_compile _ _MAIN_LIGHT_SHADOWS
				#pragma	multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
				#pragma	multi_compile _ _ADDITIONAL_LIGHT_VERTEX_ADDITIONAL_LIGHTS
				#pragma	multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
				#pragma	multi_compile _ _SHADOWS_SOFT
				#pragma	multi_compile _ _MIXED_LIGHTING_SUBTRACITIVE

				#pragma	multi_compile _ DIRLIGHTMAP_COMBINED
				#pragma	multi_compile _ LIGHTMAP_ON
				#pragma	multi_compile_fog

				#include "/FurLit.hlsl"
				#pragma vertex vert
				#pragma require geometry
				#pragma geometry geom
				#pragma fragment frag
				ENDHLSL
			}

			Pass{
				Name"DepthOnly"
				Tags { "LightMode" = "DepthOnly" }

				ZWrite On
				ColorMask 0

				HLSLPROGRAM
				#pragma exclude_renderers gles gles3 glcore
				#pragma vertex DepthOnlyVertex
				#pragma fragment DepthOnlyFragment
				#include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
				#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
				ENDHLSL
			}

			Pass{
				Name "ShadowCaster"
				Tags {"LightMode" = "ShadowCaster" }

			ZWrite On
				ZTest LEqual
				ColorMask 0

				HLSLPROGRAM
				#pragma exclude_renderers gles gles3 glcore
				#pragma target 4.5
				#pragma vertex ShadowPassVertex
				#pragma fragment ShadowPassFragment
				#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
				#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
				ENDHLSL
			}
		}
}