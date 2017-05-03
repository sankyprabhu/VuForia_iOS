/*===============================================================================
 Copyright (c) 2016 PTC Inc. All Rights Reserved. Confidential and Proprietary -
 Protected under copyright and other laws.
 Vuforia is a trademark of PTC Inc., registered in the United States and other
 countries.
 ===============================================================================*/


#include <metal_stdlib>
using namespace metal;

// === Basic texture sampling shader ===
struct VertexOut
{
    float4 m_Position [[ position ]];
    float2 m_TexCoord;
};


vertex VertexOut texturedVertex(constant packed_float3* pPosition   [[ buffer(0) ]],
                                constant float4x4*      pMVP        [[ buffer(1) ]],
                                constant float2*        pTexCoords  [[ buffer(2) ]],
                                uint                    vid         [[ vertex_id ]])
{
    VertexOut out;
    float4 in(pPosition[vid], 1.0f);

    out.m_Position = *pMVP * in;
    out.m_TexCoord = pTexCoords[vid];

    return out;
}


fragment half4 texturedFragment(VertexOut       inFrag  [[ stage_in ]],
                                texture2d<half> tex2D   [[ texture(0) ]])
{
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
    return tex2D.sample(linear_sampler, inFrag.m_TexCoord);
}
