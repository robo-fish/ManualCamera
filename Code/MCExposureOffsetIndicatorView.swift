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
import UIKit


class MCExposureOffsetIndicatorView : UIView
{
  var offsetValue : Float = 0.0
  {
    didSet { setNeedsDisplay() }
  }

  var maxOffset : Float = 1.0
  var minOffset : Float = -1.0

  override func draw(_ rect: CGRect)
  {
    let size = self.bounds.size
    let context = UIGraphicsGetCurrentContext()
    let marginX : CGFloat = rect.size.height
    let marginY : CGFloat = 6.0

    context?.setStrokeColor(MCBackgroundColor.cgColor)
    let path = UIBezierPath()
    path.lineCapStyle = .round
    path.lineWidth = 4.0
    let inset = path.lineWidth / 2.0
    path.move(to: CGPoint(x: inset + marginX, y: size.height/2.0))
    path.addLine(to: CGPoint(x: size.width - inset - marginX, y: size.height/2.0))
    path.stroke()

    var strokeColor : CGColor = MCIndicatorColor.cgColor
    let max = (offsetValue > 0) ? abs(maxOffset) : abs(minOffset)
    var indicatorLineEnd = CGFloat(offsetValue/max)
    if (offsetValue > maxOffset) || (offsetValue < minOffset)
    {
      indicatorLineEnd = (offsetValue > 0) ? 1.0 : -1.0
      strokeColor = MCWarningColor.cgColor
    }

    context?.setStrokeColor(strokeColor)

    let indicatorPath = UIBezierPath()
    indicatorPath.lineWidth = path.lineWidth
    indicatorPath.lineCapStyle = .round
    indicatorPath.move(to: CGPoint(x: size.width/2.0, y: inset + marginY))
    indicatorPath.addLine(to: CGPoint(x: size.width/2.0, y: size.height - inset - marginY))

    indicatorPath.move(to: CGPoint(x: size.width/2.0, y: size.height/2.0))
    indicatorPath.addLine(to: CGPoint(x: (indicatorLineEnd * (size.width/2.0 - inset - marginX)) + size.width/2.0, y: size.height/2.0))
    indicatorPath.stroke()
  }

  override func layoutSubviews()
  {
    if self.layer.mask == nil
    {
      let containerSize = self.bounds.size
      let layerMask = CAShapeLayer()
      let maskPath = CGMutablePath()
      maskPath.move(to: .zero)
      let bottomTaper : CGFloat = 24.0
      maskPath.addCurve(to: CGPoint(x: bottomTaper, y: containerSize.height), control1: CGPoint(x:bottomTaper/2.0, y: 0.0), control2: CGPoint(x: bottomTaper/2.0, y: containerSize.height))
      maskPath.addLine(to: CGPoint(x: containerSize.width - bottomTaper, y: containerSize.height))
      maskPath.addCurve(to: CGPoint(x:containerSize.width, y: 0.0), control1: CGPoint(x: containerSize.width - bottomTaper/2.0, y: containerSize.height), control2: CGPoint(x: containerSize.width - bottomTaper/2.0, y: 0.0))
      maskPath.closeSubpath()
      layerMask.path = maskPath
      layerMask.fillColor = UIColor.black.cgColor
      self.layer.mask = layerMask
    }
  }
}
