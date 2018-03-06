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

private let NumHorizontalLines = 3
private let NumVerticalLines = 5


class MCGridView : UIView
{
  override class var layerClass : AnyClass
  {
    return CAShapeLayer.self
  }

  override func layoutSubviews()
  {
    super.layoutSubviews()
    _updateShapeForSize(self.bounds.size)
  }

  private func _updateShapeForSize(_ size : CGSize)
  {
    let path = CGMutablePath()

    let spacingX = CGFloat(floorf(Float(size.width / CGFloat(NumVerticalLines + 1))))
    for i in 1...NumVerticalLines
    {
      let posX = CGFloat(i) * spacingX
      path.move(to: CGPoint(x: posX, y: 0))
      path.addLine(to: CGPoint(x: posX, y: size.height))
    }

    let spacingY = CGFloat(floorf(Float(size.height / CGFloat(NumHorizontalLines + 1))))
    for j in 1...NumHorizontalLines
    {
      let posY = CGFloat(j) * spacingY
      path.move(to: CGPoint(x: 0, y: posY))
      path.addLine(to: CGPoint(x: size.width, y: posY))
    }

    let shapeLayer = self.layer as! CAShapeLayer
    shapeLayer.path = path
    shapeLayer.strokeColor = MCBackgroundColor.cgColor
  }
}
