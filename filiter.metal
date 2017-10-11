//
//  filiter.metal
//  MPSDemo
//
//  Created by danny.lau on 20/08/2017.
//  Copyright © 2017 danny.lau. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct ImageSaturationParams
{
    uint2 clipOrigin;
    uint2 clipSize;
    float saturation;
    bool changeColor;
    bool changeCoord;
};


//check the point in pos
bool checkPointInRect(uint2 point,uint2 origin, uint2 rect){
    return point.x >= origin.x &&
    point.y >= origin.y &&
    point.x <= (origin.x + rect.x) &&
    point.y <= (origin.y + rect.y);
}


kernel void image_filiter(constant ImageSaturationParams *params [[buffer(0)]],
                          texture2d<half, access::read> sourceTexture [[texture(0)]],
                          texture2d<half, access::write> targetTexture [[texture(1)]],
                          texture2d<half, access::sample> lutTexture [[texture(2)]],
                          sampler samp [[sampler(0)]],
                          uint2 gridPos [[thread_position_in_grid]]){
    
    half4 color = sourceTexture.read(gridPos);
//    half4 color = sourceTexture.sample(samp,float2(gridPos));

    
    half blueColor = color.b * 63.0;
    
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
    
    
    half4 newColor1 = lutTexture.sample(samp,float2(texPos1.x * 512, texPos2.y * 512 ));
    half4 newColor2 = lutTexture.sample(samp,float2(texPos2.x * 512, texPos2.y * 512 ));
  
    half4 newColor = mix(newColor1, newColor2, half(fract(blueColor)));
    
    
    half4 finalColor = mix(color, half4(newColor.rgb, color.w), half(params->saturation));
    
    uint2 transformCoords = gridPos;
    
    //transform coords for y
    if (params->changeCoord){
        transformCoords = uint2(gridPos.x, sourceTexture.get_height() - gridPos.y);
    }
    
    //transform color 
    half4 realColor = finalColor;
    if (params->changeColor){
        realColor = half4(finalColor.bgra);
    }
    
    if(checkPointInRect(transformCoords,params->clipOrigin,params->clipSize))
    {
        targetTexture.write(realColor, gridPos);
        
    }else{
        
        targetTexture.write(color,gridPos);
    }

}
