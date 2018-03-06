/***************************************************************************
*
* This file is part of the ManualCamera project.
* Copyright (C) 2015, 2018 Kai Oezer
* https://github.com/robo-fish/ManualCamera
*
* ManualCamera is free software. You can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
*
****************************************************************************/
#include <metal_stdlib>
#include <metal_compute>
using namespace metal;


///////////////////////////////////////////////////////////////
// COMPUTING
///////////////////////////////////////////////////////////////

// Each thread writes to its local intensity-level-to-pixel-count map while looping through the pixels.
// At the end of the kernel  maps are
kernel void hist_processTile(
  const device uint* input [[ buffer(0) ]],
  device uint* output [[ buffer(1) ]],
  device uint* numPixelsPerThread [[ buffer(2) ]],
  uint const threadGroupIndex [[ threadgroup_position_in_grid ]])
{
  const uint numIntensities = 256;
  const uint numPixels = *numPixelsPerThread;

  uint histogram[256];

  // initializing the intensity values
  for (uint i = 0; i < numIntensities; ++i)
  {
    histogram[i] = 0;
  }

  const uint readOffset = threadGroupIndex * numPixels;
  for (uint i = 0; i < numPixels; ++i)
  {
    const uint pixelValues = input[readOffset + i];
    // The 32-bit pixels contain four 8-bit components in this order: BGRA.
    const uint red = (pixelValues >> 8) & 0xFF;
    const uint green = (pixelValues >> 16) & 0xFF;
    const uint blue = (pixelValues >> 24) & 0xFF;
    const uint averageIntensity = (red + green + blue) / 3;
    histogram[averageIntensity] += 1;
  }

  // copying the intensity values to the output buffer
  const uint writeOffset = threadGroupIndex * numIntensities;
  for (uint i = 0; i < numIntensities; ++i)
  {
    output[writeOffset + i] = histogram[i];
  }
}

///////////////////////////////////////////////////////////////
// RENDERING
///////////////////////////////////////////////////////////////

struct VertexIn
{
  float4 position [[attribute(0)]];
  half4 texcoord [[attribute(1)]];
};

struct VertexOut
{
  float4 position [[position]];
  half4 texcoord;
};

vertex VertexOut hist_vertex(VertexIn in [[stage_in]])
{
  VertexOut result;
  result.position = in.position;
  result.texcoord = in.texcoord;
  return result;
}

fragment half4 hist_fragment(VertexOut in [[stage_in]], constant float* histogramData [[buffer(0)]])
{
  int intensity = static_cast<int>(round(in.texcoord.x * 255));
  float numPixelsForIntensity = histogramData[intensity];
  float barGraph = smoothstep(in.texcoord.y, max(half(0.0),min(half(1.0),in.texcoord.y + half(0.04))), half(numPixelsForIntensity));
  const half4 indicatorColor(0.6, 0.8, 1.0, 1.0);
  return barGraph * indicatorColor;
}
