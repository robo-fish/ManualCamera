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

@IBDesignable
class MCRoundColorButton : UIView
{
  @IBInspectable var normalColor : UIColor = UIColor.gray
  @IBInspectable var pressedColor : UIColor = UIColor.white
  @IBInspectable var isToggleButton : Bool = false

  var buttonAction : ()->() = {}

  var pressed : Bool = false
  {
    didSet { _updateBackgroundColor() }
  }

  override init(frame:CGRect)
  {
    super.init(frame:frame)
  }

  required init?(coder decoder: NSCoder)
  {
    normalColor = decoder.containsValue(forKey: "normal color") ? decoder.decodeObject(forKey: "normal color") as! UIColor : UIColor.gray
    pressedColor = decoder.containsValue(forKey: "pressed color") ? decoder.decodeObject(forKey: "pressed color") as! UIColor : UIColor.white
    isToggleButton = decoder.containsValue(forKey: "is toggle button") ? decoder.decodeBool(forKey: "is toggle button") : false
    super.init(coder:decoder)
  }

  override func encode(with encoder: NSCoder)
  {
    super.encode(with: encoder)
    encoder.encode(normalColor, forKey:"normal color")
    encoder.encode(pressedColor, forKey:"pressed color")
    encoder.encode(isToggleButton, forKey:"is toggle button")
  }

  override func layoutSubviews()
  {
    super.layoutSubviews()
    if self.layer.mask == nil
    {
      let maskLayer = CAShapeLayer()
      maskLayer.path = CGPath(ellipseIn: self.bounds, transform: nil)
      maskLayer.fillColor = UIColor.black.cgColor
      self.layer.mask = maskLayer
      self.layer.backgroundColor = normalColor.cgColor
      self.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(MCRoundColorButton.pressButton)))
    }
  }

  @objc func pressButton()
  {
    if isToggleButton
    {
      pressed = !pressed
      _updateBackgroundColor()
    }
    else
    {
      UIView.animate(withDuration: 0.05, animations: { () -> Void in
        self.layer.backgroundColor = self.pressedColor.cgColor
      }, completion: { (Bool) -> Void in
        UIView.animate(withDuration: 0.10, animations: { () -> Void in
          self.layer.backgroundColor = self.normalColor.cgColor
        })
      } )
    }
    buttonAction()
  }

  private func _updateBackgroundColor()
  {
    if isToggleButton
    {
      self.layer.backgroundColor = pressed ? pressedColor.cgColor : normalColor.cgColor
    }
  }
}
