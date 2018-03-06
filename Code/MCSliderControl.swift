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

protocol MCSliderControlDelegate
{
  func beginValueChangeForSliderControl(_ control : MCSliderControl)
  func endValueChangeForSliderControl(_ control : MCSliderControl)
  func updateValueForSliderControl(_ control : MCSliderControl)
}

enum MCSliderControlOrientation
{
  case verticalBottomToTop
  case horizontalLeftToRight
  case diagonalRisingLeftToRight // bottom left to top right - max value on the right side
  case diagonalFallingLeftToRight // top left to bottom right - max value on the left side
}

enum MCSliderControlStyle
{
  case roundedKnob
  case tickMarked
}

@IBDesignable
class MCSliderControl : UIView
{
  @IBInspectable var tickCount : Int

  private let _headHeight : CGFloat = 8.0

  private var _sliderValue : Float = 0

  var delegate : MCSliderControlDelegate?

  var value : Float
  {
    get
    {
      return _sliderValue
    }
    set
    {
      _sliderValue = (newValue > 1.0) ? 1.0 : ((newValue < 0.0) ? 0.0 : newValue)
      setNeedsDisplay()
    }
  }

  var orientation : MCSliderControlOrientation = .verticalBottomToTop
  {
    didSet { setNeedsDisplay() }
  }

  var style : MCSliderControlStyle = .roundedKnob
  {
    didSet { setNeedsDisplay() }
  }

  var enabled : Bool
  {
    didSet { setNeedsDisplay() }
  }

  var color : UIColor = MCControlColor
  {
    didSet { setNeedsDisplay() }
  }

  var angle : Double = .pi
  {
    didSet { setNeedsDisplay() }
  }

  override init(frame: CGRect)
  {
    enabled = true
    tickCount = 21
    super.init(frame:frame)
  }

  required init?(coder decoder: NSCoder)
  {
    enabled = decoder.containsValue(forKey: "enabled") ? decoder.decodeBool(forKey: "enabled") : true
    tickCount = decoder.containsValue(forKey: "tickCount") ? decoder.decodeInteger(forKey: "tickCount") : 21
    super.init(coder:decoder)
  }

  override func encode(with coder: NSCoder)
  {
    coder.encode(enabled, forKey:"enabled")
    coder.encode(tickCount, forKey:"tickCount")
    super.encode(with: coder)
  }

  override func draw(_ rect:CGRect)
  {
    if let context = UIGraphicsGetCurrentContext()
    {
      context.setStrokeColor(self.color.cgColor)
      context.setFillColor(self.color.cgColor)

      if self.style == .roundedKnob
      {
        _drawRoundedKnobSliderInRect(rect, withContext: context)
      }
      else
      {
        _drawTickMarkedSliderInRect(rect, withContext: context)
      }
    }
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
  {
    if let value = _sliderValueForTouches(touches)
    {
      self.value = value
      delegate?.beginValueChangeForSliderControl(self)
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
  {
    if let value = _sliderValueForTouches(touches)
    {
      self.value = value
      delegate?.updateValueForSliderControl(self)
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
  {
    self.touchesCancelled(touches, with: event)
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
  {
    delegate?.endValueChangeForSliderControl(self)
  }

  //MARK: Private

  private func _sliderValueForTouches(_ touches : Set<NSObject>) -> Float?
  {
    var result : Float?
    if enabled && (touches.count == 1)
    {
      if let touch = touches.first as? UITouch
      {
        let controlSize = self.bounds.size
        switch orientation
        {
          case .diagonalFallingLeftToRight: fallthrough
          case .diagonalRisingLeftToRight: fallthrough
          case .verticalBottomToTop:
            let tickSlotHeight = controlSize.height / CGFloat(tickCount)
            let position = touch.location(in: self).y - tickSlotHeight/2.0
            let height = controlSize.height - tickSlotHeight
            result = Float((height - position)/height)
          case .horizontalLeftToRight:
            let tickSlotWidth = controlSize.width / CGFloat(tickCount)
            let position = touch.location(in: self).x - tickSlotWidth/2.0
            let width = controlSize.width - tickSlotWidth
            result = Float((width - position)/width)
        }
      }
    }
    return result
  }

  private func _drawRoundedKnobSliderInRect(_ rect : CGRect, withContext context : CGContext)
  {
    var startPoint = CGPoint.zero
    var endPoint = CGPoint.zero
    let size = self.bounds.size
    switch self.orientation
    {
      case .verticalBottomToTop:
        startPoint.x = size.width / 2.0
        endPoint.x = startPoint.x
        endPoint.y = size.height
      case .horizontalLeftToRight:
        startPoint.y = size.height / 2.0
        endPoint.y = startPoint.y
      case .diagonalFallingLeftToRight:
        endPoint.x = size.width
        endPoint.y = size.height
      case .diagonalRisingLeftToRight:
        startPoint.y = size.height
        endPoint.x = size.width
    }
    context.setLineWidth(2.0);
    let path = UIBezierPath()
    path.lineCapStyle = .round
    path.move(to: startPoint)
    path.addLine(to: endPoint)
    path.stroke()
    let knobDiameter = max(min(size.width, size.height)/10.0, 20.0)
    var knobRect = CGRect(x: 0, y: 0, width: knobDiameter, height: knobDiameter)
    switch self.orientation
    {
      case .verticalBottomToTop:
        knobRect.origin.x = (size.width - knobDiameter)/2.0
        knobRect.origin.y = size.height * CGFloat(self.value) - knobDiameter/2.0
      case .horizontalLeftToRight:
        knobRect.origin.x = size.width * CGFloat(self.value) - knobDiameter/2.0
        knobRect.origin.y = (size.height - knobDiameter)/2.0
      case .diagonalRisingLeftToRight:
        knobRect.origin.x = size.width * CGFloat(self.value) - knobDiameter/2.0
        knobRect.origin.y = size.height * CGFloat(1.0 - self.value) - knobDiameter/2.0
      case .diagonalFallingLeftToRight:
        knobRect.origin.x = size.width * CGFloat(self.value) - knobDiameter/2.0
        knobRect.origin.y = size.height * CGFloat(self.value) - knobDiameter/2.0
    }
    let knobPath = UIBezierPath(ovalIn: knobRect)
    knobPath.fill()
  }

  private func _drawTickMarkedSliderInRect(_ rect : CGRect, withContext context : CGContext)
  {
    let size = self.bounds.size
    let tickSlotHeight = size.height / CGFloat(tickCount)
    let ticksInsetX = 0.2 * size.width

    // Drawing the tick marks
    context.setLineWidth(2.0);
    let path = UIBezierPath()
    path.lineCapStyle = .round
    for i in 0..<tickCount
    {
      let verticalPos = (CGFloat(i) + 0.5) * tickSlotHeight
      path.move(to: CGPoint(x: ticksInsetX, y: verticalPos))
      path.addLine(to: CGPoint(x: size.width - ticksInsetX, y: verticalPos))
    }
    path.stroke()

    // Drawing the slider head
    let headVerticalPos = ((size.height - tickSlotHeight) * (1.0 - CGFloat(value))) + tickSlotHeight/2.0 - _headHeight/2.0
    UIBezierPath(roundedRect: CGRect(x: 0.0, y: headVerticalPos, width: size.width, height: _headHeight), cornerRadius:_headHeight/2.0).fill()
  }

}
