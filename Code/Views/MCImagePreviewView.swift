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

class MCImagePreviewView : UIView
{
  private var _imageView : UIImageView
  private var _fadeOutTimer : Timer?

  override init(frame: CGRect)
  {
    _imageView = UIImageView(frame: .zero)
    _imageView.isOpaque = false
    _imageView.alpha = 0.0
    super.init(frame: frame)
    addSubview(_imageView)
    _layout()
    _setupGesture()
  }

  required init?(coder decoder: NSCoder)
  {
    _imageView = UIImageView(frame: .zero)
    super.init(coder: decoder)
    addSubview(_imageView)
    _layout()
    _setupGesture()
  }

  var fadeOutDelay = 2.0 // seconds

  var tapAction : (()->())?

  var image : UIImage?
  {
    set {
      _imageView.image = newValue
      self._imageView.alpha = 1.0
      _fadeOutTimer?.invalidate()
      _fadeOutTimer = Timer.scheduledTimer(withTimeInterval:2.0, repeats: false) { (timer) in
        timer.invalidate()
        UIView.animate(withDuration: 0.5) {
          self._imageView.alpha = 0.0
        }
      }
    }
    get { return _imageView.image }
  }

  private func _layout()
  {
    _imageView.translatesAutoresizingMaskIntoConstraints = false
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat:"H:|[iv]|", options:[], metrics:nil, views:["iv" : _imageView]))
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat:"V:|[iv]|", options:[], metrics:nil, views:["iv" : _imageView]))
  }

  private func _setupGesture()
  {
    let recognizer = UITapGestureRecognizer(target: self, action: #selector(MCImagePreviewView.handleTap) )
    addGestureRecognizer(recognizer)
  }

  @objc func handleTap(_ recognizer : UITapGestureRecognizer)
  {
    tapAction?()
  }
}
