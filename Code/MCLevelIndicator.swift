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
import CoreMotion

class MCLevelIndicator : NSObject
{
  var enabled : Bool
  {
    didSet
    {
      if enabled
      {
        _startTrackingYaw()
      }
      else
      {
        _stopTrackingYaw()
      }
    }
  }

  private var _motionManager : CMMotionManager
  private var _operationQueue : OperationQueue
  private var _controlledLayer : CALayer?

  override init()
  {
    enabled = false
    _motionManager = CMMotionManager()
    _motionManager.deviceMotionUpdateInterval = 0.1 // seconds
    _operationQueue = OperationQueue()
    super.init()
  }

  var layer : CALayer
  {
    get
    {
      if _controlledLayer == nil
      {
        let layerFrame = CGRect(x: 0.0, y: 0.0, width: 200.0, height: 6.0)
        let layer = CAShapeLayer()
        layer.frame = layerFrame
        layer.cornerRadius = layerFrame.size.height/2.0
        layer.backgroundColor = MCBackgroundColor.cgColor
        layer.lineCap = CAShapeLayerLineCap.round
        layer.lineWidth = layerFrame.size.height - 2.0
        layer.fillColor = MCIndicatorColor.cgColor
        layer.strokeColor = MCIndicatorColor.cgColor
        let margin = layer.cornerRadius
        let linePath = CGMutablePath()
        let centerY = layerFrame.size.height/2.0
        linePath.move(to: CGPoint(x: margin, y: centerY))
        linePath.addLine(to: CGPoint(x: layerFrame.size.width - margin, y: centerY))
        layer.path = linePath
        _controlledLayer = layer
      }
      return _controlledLayer!
    }
  }

  //MARK: Private

  private func _startTrackingYaw()
  {
    if _motionManager.isDeviceMotionAvailable && !_motionManager.isDeviceMotionActive
    {
      _motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to:_operationQueue, withHandler:_motionUpdateHandler)
    }
  }

  private func _stopTrackingYaw()
  {
    if _motionManager.isDeviceMotionActive
    {
      _motionManager.stopDeviceMotionUpdates()
    }
  }

  private func _motionUpdateHandler(_ motion : CMDeviceMotion?, error : Error?)
  {
    guard let layer = _controlledLayer else { return }
    guard let pitch = motion?.attitude.pitch else { return }
    let orientationFactor : CGFloat = UIDevice.current.orientation == .landscapeLeft ? -1.0 : 1.0
    DispatchQueue.main.async {
      let LevelGaugeMaxUsablePitch = Float.pi/3.0
      layer.opacity = (LevelGaugeMaxUsablePitch - Float(fabs(pitch)))/LevelGaugeMaxUsablePitch
      layer.transform = CATransform3DMakeRotation(CGFloat(pitch) * orientationFactor, 0.0, 0.0, 1.0)
    }
  }

}
