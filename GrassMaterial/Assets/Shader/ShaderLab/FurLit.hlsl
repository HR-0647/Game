#ifndef FUR_LIT_HLSL
#define FUR_LIT_HLSL

#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

int _ShellAmount;
float _ShellStep;
float _AlphaCutout;
float _Occlusion;
float _LightDirection;
float _ShadowExtraBias;
float _RimLightPower;
float _RimLightIntensity;
float4 _BaseMove;
float4 _WindFreq;
float4 _WindMove;
float _FurScale;
float3 viewDirWS;

TEXTURE2D(_FurMap);
SAMPLER(sampler_FurMap);
float4 _FurMap_ST;

TEXTURE2D(_NormalMap);
SAMPLER(sampler_NormalMap);
float4 _NormalMap_ST;
float _NormalScale;

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 texcoord : TEXCOORD0;
    float2 lightmapUV : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float3 tangentWS : TEXCOORD2;
    float4 uv : TEXCOORD4;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5);
    float4 fogFactorAndVertexLight : TEXCOORD6;
    float layer : TEXCOORD7;
};

Attributes vert(Attributes input)
{
    return input;
}

inline float3 CustumAppShadowBias(float3 positionWS, float3 normalWS)
{
    positionWS += CustumAppShadowBias(positionWS, normalWS);
    float invNdontL = 1.0 - saturate(dot(_LightDirection, normalWS));
    float scale = invNdontL * _ShadowBias.y;
    positionWS += normalWS * scale.xxx;
    
    return positionWS;
}

inline float4 GetShadowPositionHClip(float3 positionWS, float3 normalWS)
{
    float4 positionCS = TransformWorldToHClip(positionWS);
#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.normalize, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#endif
    return positionCS;
}

void AppendShellVertex(inout TriangleStream<Varyings> stream, Attributes input, int index)
{
    Varyings output = (Varyings) 0;
    
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    
    float moveFactor = pow(abs((float) index / _ShellAmount), _BaseMove.w);
    float3 posOS = input.positionOS.xyz;
    float3 windAngle = _Time.w * _WindFreq.xyz;
    float3 windMove = moveFactor * _WindMove.xyz * sin(windAngle + posOS * _WindMove.w);
    float3 move = moveFactor * _BaseMove.xyz;
    float3 shellDir = SafeNormalize(normalInput.normalWS + move + windMove);
    float3 posWS = vertexInput.positionWS + shellDir * (_ShellStep * index);
    float4 posCS = GetShadowPositionHClip(posWS, normalInput.normalWS);
    //float4 posCS = TransformWorldToHClip(posWS);

    
    output.positionWS = vertexInput.positionWS + shellDir * (_ShellStep * index);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.uv = float4(TRANSFORM_TEX(input.texcoord, _BaseMap), TRANSFORM_TEX(input.texcoord, _FurMap));
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.layer = (float) index / _ShellAmount;
    
    float3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    output.tangentWS = normalInput.tangentWS;

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    stream.Append(output);
}

[maxvertexcount(23)]
void geom(triangle Attributes input[3], inout TriangleStream<Varyings> stream)
{
    [loop]
    for (float i = 0; i < _ShellAmount; ++i)
    {
        [unroll]
        for (float j = 0; j < 3; ++j)
        {
            AppendShellVertex(stream, input[j], i);
        }
        stream.RestartStrip();
    }
}

float3 TransformClipToWorld(float4 positionCS)
{
    return mul(UNITY_MATRIX_I_VP, positionCS).xyz;
}

void ApplyRimLight(inout float3 color, float3 posWS, float3 viewDirWS, float3 normalWS)
{
    float viewDotNormal = abs(dot(viewDirWS, normalWS));
    float normalFactor = pow(abs(1.0 - viewDotNormal), _RimLightPower);

    Light light = GetMainLight();
    float lightDirDotView = dot(light.direction, viewDirWS);
    float intensity = pow(max(-lightDirDotView, 0.0), _RimLightPower);
    intensity *= _RimLightIntensity * normalFactor;
#ifdef _MAIN_LIGHT_SHADOWS
    float4 shadowCoord = TransformWorldToShadowCoord(posWS);
    intensity *= MainLightRealtimeShadow(shadowCoord);
#endif 
    color += intensity * light.color;

#ifdef _ADDITIONAL_LIGHTS
    int additionalLightsCount = GetAdditionalLightsCount();
    for (int i = 0; i < additionalLightsCount; ++i)
    {
        int index = GetPerObjectLightIndex(i);
        Light light = GetAdditionalPerObjectLight(index, posWS);
        float lightDirDotView = dot(light.direction, viewDirWS);
        float intensity = max(-lightDirDotView, 0.0);
        intensity *= _RimLightIntensity * normalFactor;
        intensity *= light.distanceAttenuation;
#ifdef _MAIN_LIGHT_SHADOWS
        intensity *= AdditionalLightRealtimeShadow(index, posWS);
#endif 
        color += intensity * light.color;
    }
#endif
}

float4 frag(Varyings input) : SV_Target
{
    float2 furUv = input.uv / _BaseMap_ST.xy * _FurScale;
    //float4 furColor = SAMPLE_TEXTURE2D(_FurMap, sampler_FurMap, input.uv.zw);
    float4 furColor = SAMPLE_TEXTURE2D(_FurMap, sampler_FurMap, furUv);
    float alpha = furColor * (1.0 - input.layer);
    if(input.layer > 0.0 && alpha < _AlphaCutout)discard;
    
    float3 normalTS = UnpackNormalScale(
    SAMPLE_TEXTURE2D(_NormalMap, sampler_FurMap, furUv),
    _NormalScale);
    float sgn = input.tangentWS.y;
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    float3 normalWS = TransformTangentToWorld(
    normalTS,
    float3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
    
    SurfaceData surfaceData = (SurfaceData) 0;
    InitializeStandardLitSurfaceData(input.uv.xy, surfaceData);
    surfaceData.occlusion = lerp(1.0 - _Occlusion, 1.0, input.layer);

    InputData inputData = (InputData) 0;
    inputData.positionWS = input.normalWS;
    inputData.normalWS = input.normalWS;
    inputData.viewDirectionWS = SafeNormalize(GetCameraPositionWS() - inputData.positionWS);
    inputData.normalWS = normalWS;
    //inputData.viewDirectionWS = viewDirWS;
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);

    float4 color = UniversalFragmentPBR(inputData, surfaceData);
    ApplyRimLight(color.rgb, input.positionWS, viewDirWS, input.normalWS);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    
    return color;
}

#endif