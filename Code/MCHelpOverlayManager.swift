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

enum MCHelpLabelAnchor : Int
{
  case center = 0
  case topLeft = 1
  case left = 2
  case bottomLeft = 3
  case bottom = 4
  case bottomRight = 5
  case right = 6
  case topRight = 7
  case top = 8
}

private struct MCHelpTag
{
  var text : String
  var taggedView : UIView
  var anchor : MCHelpLabelAnchor
  var offset : Float
}


class MCHelpOverlayManager : NSObject
{
  var enabled : Bool = false
  {
    didSet { enabled ? _show() : _hide() }
  }

  private var _rootView : UIView
  private var _helpOverlayView : UIView
  private var _helpTags = [MCHelpTag]()
  private var _labels = [UILabel]()
  private var _didLayOutLabels : Bool = false
  private var _textAttributes = [NSAttributedStringKey:Any]()

  init(rootView: UIView)
  {
    _rootView = rootView
    _helpOverlayView = UIView(frame:rootView.bounds)
    _textAttributes[NSAttributedStringKey.font] = UIFont.systemFont(ofSize: 14.0)
  }

  func addHelpTag(_ tag : String, forView taggedView : UIView?, anchor : MCHelpLabelAnchor, offset : Float = 10.0)
  {
    assert(!_didLayOutLabels)
    if let view = taggedView
    {
      _helpTags.append(MCHelpTag(text:tag, taggedView:view, anchor:anchor, offset:offset))
    }
  }

  func clearTags()
  {
    _hide()
    for label in _labels
    {
      label.removeFromSuperview()
    }
    _labels = []
    _helpTags = []
    _didLayOutLabels = false
  }

  private func _show()
  {
    if _didLayOutLabels
    {
      for label in _labels
      {
        label.isHidden = false
      }
    }
    else
    {
      for tag in _helpTags
      {
        let label = _createLabelForTag(tag)
        label.isHidden = false
        _rootView.addSubview(label)
        let offset = CGFloat(tag.offset)
        switch tag.anchor
        {
          case .center:
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.centerX, relatedBy:.equal, toItem:tag.taggedView, attribute:.centerX, multiplier:1.0, constant:0.0))
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.centerY, relatedBy:.equal, toItem:tag.taggedView, attribute:.centerY, multiplier:1.0, constant:0.0))
          case .bottom:
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.top, relatedBy:.equal, toItem:tag.taggedView, attribute:.bottom, multiplier:1.0, constant:offset))
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.centerX, relatedBy:.equal, toItem:tag.taggedView, attribute:.centerX, multiplier:1.0, constant:0.0))
          case .left:
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.right, relatedBy:.equal, toItem:tag.taggedView, attribute:.left, multiplier:1.0, constant:offset))
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.centerY, relatedBy:.equal, toItem:tag.taggedView, attribute:.centerY, multiplier:1.0, constant:0.0))
          case .top:
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.bottom, relatedBy:.equal, toItem:tag.taggedView, attribute:.top, multiplier:1.0, constant:-offset))
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.centerX, relatedBy:.equal, toItem:tag.taggedView, attribute:.centerX, multiplier:1.0, constant:0.0))
          case .right:
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.left, relatedBy:.equal, toItem:tag.taggedView, attribute:.right, multiplier:1.0, constant:offset))
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.centerY, relatedBy:.equal, toItem:tag.taggedView, attribute:.centerY, multiplier:1.0, constant:0.0))
          case .bottomLeft:
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.top, relatedBy:.equal, toItem:tag.taggedView, attribute:.bottom, multiplier:1.0, constant:offset))
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.right, relatedBy:.equal, toItem:tag.taggedView, attribute:.left, multiplier:1.0, constant:-offset))
          case .bottomRight:
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.left, relatedBy:.equal, toItem:tag.taggedView, attribute:.right, multiplier:1.0, constant:offset))
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.top, relatedBy:.equal, toItem:tag.taggedView, attribute:.bottom, multiplier:1.0, constant:offset))
          case .topLeft:
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.bottom, relatedBy:.equal, toItem:tag.taggedView, attribute:.top, multiplier:1.0, constant:-offset))
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.right, relatedBy:.equal, toItem:tag.taggedView, attribute:.left, multiplier:1.0, constant:-offset))
          case .topRight:
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.left, relatedBy:.equal, toItem:tag.taggedView, attribute:.right, multiplier:1.0, constant:offset))
            _rootView.addConstraint(NSLayoutConstraint(item:label, attribute:.bottom, relatedBy:.equal, toItem:tag.taggedView, attribute:.top, multiplier:1.0, constant:-offset))
        }
        _labels.append(label)
      }
      _didLayOutLabels = true
    }
  }

  private func _hide()
  {
    for label in _labels
    {
      label.isHidden = true
    }
  }

  private func _createLabelForTag(_ tag : MCHelpTag) -> UILabel
  {
    let margin : CGFloat = 4.0
    let textSize = NSAttributedString(string:tag.text, attributes: _textAttributes).size()
    let result = UILabel(frame:CGRect(x: 0, y: 0, width: textSize.width+2*margin, height: textSize.height + 2*margin))
    result.isOpaque = false
    result.backgroundColor = nil
    result.layer.backgroundColor = UIColor(red:0.8, green:0.8, blue:0.2, alpha:0.8).cgColor
    result.layer.cornerRadius = margin
    result.numberOfLines = 0
    result.font = _textAttributes[NSAttributedStringKey.font] as! UIFont
    result.text = tag.text
    result.textAlignment = .center
    result.translatesAutoresizingMaskIntoConstraints = false
    result.removeConstraints(result.constraints)
    result.addConstraint(NSLayoutConstraint(item:result, attribute:.height, relatedBy:.equal, toItem:nil, attribute:.height, multiplier:1.0, constant:CGFloat(textSize.height + 2*margin)))
    result.addConstraint(NSLayoutConstraint(item:result, attribute:.width, relatedBy:.equal, toItem:nil, attribute:.width, multiplier:1.0, constant:CGFloat(textSize.width + 2*margin)))
    return result
  }
}
