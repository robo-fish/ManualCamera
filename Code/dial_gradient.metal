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
//#include <simd/simd.h>
using namespace metal;


struct VertexInput
{
  float4 position [[attribute(0)]];
  //simd::float4 position [[attribute(0)]];
  half2 texCoord [[attribute(1)]];
};

struct VertexOutput
{
  float4 position [[position]];
  half2 texCoord;
};

vertex VertexOutput basic_vs(VertexInput input [[stage_in]])
{
  VertexOutput result;
  result.position = input.position;
  result.texCoord = input.texCoord;
  return result;
};

fragment half4 dial_gradient(
  VertexOutput input [[stage_in]],
  constant bool* reverseGradient [[buffer(0)]])
{
  half const PI = 3.1415926536;
  half const PI2 = 6.28318531;
  half const innerCircle = 0.35;
  half const outerCircle = 0.50;
  half x = input.texCoord.x - 0.5;
  half y = input.texCoord.y - 0.5;
  half distance = sqrt(x*x + y*y);
  half angle = acos(x / distance); // returns an angle between +90 and -90 degrees but we want an angle in the range [0,2π]
  angle += step(x,half(0.0)) * step(y,half(0.0)) * 2.0 * (PI - angle); // correction for third quadrant
  angle += step(half(0.0),x) * step(y,half(0.0)) * (PI2 - 2.0 * angle); // correction for fourth quadrant
  angle = *reverseGradient ? (PI2 - angle) : angle;
  half angularGradient = angle / PI2;
  half regionFilter = step(innerCircle,distance) * step(distance,outerCircle);
  //half4 gradientColor = half4(0.776, 0.537, 0.384, 1.0); // brown
  //half4 gradientColor = half4(1.0, 1.0, 1.0, 1.0); // white
  //half4 gradientColor = half4(0.573, 0.271, 0.941, 1.0); // purple
  half4 gradientColor = half4(1.0);
  return regionFilter * angularGradient * 0.4 * gradientColor;
};
