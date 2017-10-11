//
//  shader.metal
//  MPSDemo
//
//  Created by danny.lau on 18/08/2017.
//  Copyright © 2017 danny.lau. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Uniforms
{
    float4x4 modelViewProjectionMatrix;
};

struct ColoredVertexIn
{
    packed_float4 position;
    packed_float2 texCoords;
};

struct ColoredVertex
{
    float4 position [[position]];
    float2 texCoords;
};

struct RenderImageSaturationParams
{
    uint2 clipOrigin;
    uint2 clipSize;
    float saturation;
    bool changeColor;
    bool changeCoord;
};

vertex ColoredVertex mps_vertex(constant ColoredVertexIn *vertices [[buffer(0)]],
                                    uint vid [[vertex_id]])
{
    ColoredVertexIn inVertex = vertices[vid];
    ColoredVertex outVertex;
    
//    outVertex.position = uniforms->modelViewProjectionMatrix * float4(inVertex.position);
    outVertex.position = inVertex.position;
    outVertex.texCoords = inVertex.texCoords;
    
    return outVertex;
};

fragment half4 mps_fragment(ColoredVertex vert [[stage_in]],
                                texture2d<float> diffuseTexture [[texture(0)]],
                                sampler samplr [[sampler(0)]])
{
    float4 diffuse = diffuseTexture.sample(samplr, vert.texCoords);
    return half4(diffuse);
//    return half4(0.5,0.5,0,1);
};

bool checkPointInRectRender(uint2 point,uint2 origin, uint2 rect){
    return point.x >= origin.x &&
    point.y >= origin.y &&
    point.x <= (origin.x + rect.x) &&
    point.y <= (origin.y + rect.y);
}

fragment half4 mps_filter_fragment(
                                   ColoredVertex vert [[stage_in]],
                            constant RenderImageSaturationParams *params [[buffer(0)]],
                            texture2d<half> sourceTexture [[texture(0)]],
                            texture2d<half> lutTexture [[texture(1)]]
                            )
{
    float width = sourceTexture.get_width();
    float height = sourceTexture.get_height();
    uint2 gridPos = uint2(vert.texCoords.x * width ,vert.texCoords.y * height);
    
    half4 color = sourceTexture.read(gridPos);
    
    
    float blueColor = color.b * 63.0;
    
    int2 quad1;
    quad1.y = floor(floor(blueColor) / 8.0);
    quad1.x = floor(blueColor) - (quad1.y * 8.0);
    
    int2 quad2;
    
    quad2.y = floor(ceil(blueColor) / 8.0);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0);
    
    half2 texPos1;
    texPos1.x = (quad1.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * color.r);
    texPos1.y = (quad1.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * color.g);
    
    half2 texPos2;
    texPos2.x = (quad2.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * color.r);
    texPos2.y = (quad2.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * color.g);
    
    
    half4 newColor1 = lutTexture.read(uint2(texPos1.x * 512,texPos1.y * 512));
    half4 newColor2 = lutTexture.read(uint2(texPos2.x * 512,texPos2.y * 512));
    
    half4 newColor = mix(newColor1, newColor2, half(fract(blueColor)));
    
    
    half4 finalColor = mix(color, half4(newColor.rgb, color.w), half(params->saturation));
    
    
    uint2 destCoords = gridPos + params->clipOrigin;
    
    
    uint2 transformCoords =  uint2(destCoords.x, destCoords.y);
    
    //transform coords for y
    if (params->changeCoord){
        transformCoords = uint2(destCoords.x , height - destCoords.y);
    }
    //transform color for r&b
    half4 realColor = finalColor;
    if (params->changeColor){
        realColor = half4(finalColor.bgra);
    }
    
    if(checkPointInRectRender(transformCoords,params->clipOrigin,params->clipSize))
    {
        return realColor;
        
    }else{
        
        return color;
    }
    
    
};

