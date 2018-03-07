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
import AVFoundation
import Photos

enum MCControlsLayoutStyle : Int
{
  case left = 0
  case right = 1
  init(_ deviceOrientation : UIDeviceOrientation)
  {
    if deviceOrientation == .landscapeLeft { self = .right }
    self = .left
  }
}

enum MCControlsScreenWidth : CGFloat
{
  case w568 = 568.0 // iPhone 5/5s/5c/SE, iPod touch
  case w667 = 667.0 // iPhone 6/6s/7/8
  case w736 = 736.0 // iPhone 6+/6s+/7+/8+
  case w812 = 812.0 // iPhone X
}

enum MCPreferenceKey : String
{
  case ISO = "ISO"
  case Shutter = "Shutter"
  case FocalDistance = "FocalDistance"
  case ShowHelpButton = "ShowHelpButton"
  case LeftHandedLayout = "LeftHandedLayout"
}

class MCMainController : UIViewController
{
  private let _cameraController = MCCameraController()

  private let _previewView = MCVideoPreviewView(frame: CGRect.zero)
  private let _isoDial = MCDialControl(frame: CGRect.zero)
  private let _speedDial = MCDialControl(frame: CGRect.zero)
  private let _shutterButton = MCRoundColorButton(frame: CGRect.zero)
  private let _focusSlider = MCSliderControl(frame: CGRect.zero)
  private let _exposureOffsetView = MCExposureOffsetIndicatorView(frame: CGRect.zero)
  private let _isoIndicator = UILabel(frame: CGRect.zero)
  private let _isoLabel = UILabel(frame: CGRect.zero)
  private let _shutterSpeedIndicator = UILabel(frame: CGRect.zero)
  private let _shutterLabel = UILabel(frame: CGRect.zero)

  private var _histogram : MCHistogram?
  private var _lastHistogramSampleTime : TimeInterval = -1.0
  private var _histogramView : MCHistogramView?
  private let _histogramButton = UIButton(frame: CGRect.zero)
  private let _gridButton = UIButton(frame: CGRect.zero)
  private let _helpButton = MCRoundColorButton(frame: CGRect.zero)

  private var _focusAssistant : MCFocusAssistant?

  private let _levelIndicator = MCLevelIndicator()
  private let _levelIndicatorView = UIView(frame: CGRect.zero)

  private let _gridView = MCGridView(frame:CGRect.zero)
  private var _gridViewWidth : NSLayoutConstraint?
  private var _gridViewHeight : NSLayoutConstraint?

  private var _messageLabel : UILabel?

  private var _helpOverlayManager : MCHelpOverlayManager?

  private var _layoutStyle = MCControlsLayoutStyle.right
  private var _leftHandConstraints = [NSLayoutConstraint]()
  private var _rightHandConstraints = [NSLayoutConstraint]()

  private let _screenWidth : MCControlsScreenWidth

  init()
  {
    _screenWidth = MCControlsScreenWidth(rawValue:UIScreen.main.bounds.width) ?? .w568
    super.init(nibName: nil, bundle: nil)
    UserDefaults.standard.register(defaults:[
      MCPreferenceKey.ISO.rawValue : 0.2,
      MCPreferenceKey.Shutter.rawValue : 0.1,
      MCPreferenceKey.FocalDistance.rawValue : 0.5,
      MCPreferenceKey.ShowHelpButton.rawValue : true,
      MCPreferenceKey.LeftHandedLayout.rawValue : false
    ])

    let notifCenter = NotificationCenter.default
    notifCenter.addObserver(self, selector:#selector(MCMainController.handleAppBecameActive(_:)), name:NSNotification.Name.UIApplicationDidBecomeActive, object:nil)
    notifCenter.addObserver(self, selector:#selector(MCMainController.handleAppWillBecomeInactive(_:)), name:NSNotification.Name.UIApplicationWillResignActive, object:nil)
    _layoutStyle = UserDefaults.standard.bool(forKey: MCPreferenceKey.LeftHandedLayout.rawValue) ? .left : .right
  }

  required convenience init?(coder aDecoder: NSCoder)
  {
    self.init()
  }

  // MARK: UIViewController overrides

  override func loadView()
  {
    self.view = UIView(frame: CGRect.zero)
    _buildUI()
    _layoutUI()
  }

  override var shouldAutorotate : Bool
  {
    return true
  }

  override var supportedInterfaceOrientations : UIInterfaceOrientationMask
  {
    return _layoutStyle == .left ? [.landscapeLeft] : [.landscapeRight]
  }

  override func viewWillDisappear(_ animated : Bool)
  {
    super.viewWillDisappear(animated)
    NotificationCenter.default.removeObserver(self)
  }

  override func viewDidLayoutSubviews()
  {
  /*
    let sublayers = _helpButton.layer.sublayers
    if (sublayers == nil) || (sublayers!.count == 0)
    {
      let textLayer = CATextLayer()
      let fontSize : CGFloat = 24.0
      let textAttributes : [NSAttributedStringKey : Any] = [
        NSAttributedStringKey.font : UIFont.boldSystemFont(ofSize: fontSize),
        NSAttributedStringKey.foregroundColor : _helpButton.pressedColor
      ]
      let attributedString = NSAttributedString(string: MCLoc("Help_Button_Symbol"), attributes:textAttributes)
      textLayer.string = attributedString
      textLayer.alignmentMode = kCAAlignmentRight
      let textSize = attributedString.size()
      textLayer.bounds = CGRect(x: 0, y: 0, width: ceil(textSize.width), height: ceil(textSize.height));
      _helpButton.layer.addSublayer(textLayer)
      let helpButtonSize = _helpButton.bounds.size
      textLayer.position = CGPoint(x: helpButtonSize.width/2.0 - textSize.width/2.0, y: helpButtonSize.height/2.0 - textSize.height/2.0)
    }
  */
  }

//  override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator)
//  {
//    super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
//  }

  // MARK: Notification and user actions

//  func handleAppWillEnterForeground(notification : NSNotification)
//  {
//  }

  @objc func handleAppBecameActive(_ notification : Notification)
  {
    _layoutStyle = UserDefaults.standard.bool(forKey: MCPreferenceKey.LeftHandedLayout.rawValue) ? .left : .right
    _applyLayoutStyle()
    _updateHelpButtonVisibility()
    _checkCameraPermission()
  }

  @objc func handleAppWillBecomeInactive(_ notification : Notification)
  {
  }

  @objc func openSettings(_ sender : AnyObject)
  {
    if let url = URL(string:UIApplicationOpenSettingsURLString)
    {
      UIApplication.shared.open(url)
    }
  }

  @objc func toggleHistogram(_ sender : AnyObject)
  {
    if let histogram = _histogram
    {
      histogram.enabled = !histogram.enabled
    }
  }

  @objc func toggleGrid(_ sender : AnyObject)
  {
    if _cameraController.cameraIsReady
    {
      let wasEnabled = _levelIndicator.enabled
      _levelIndicator.enabled = !wasEnabled
      _levelIndicatorView.isHidden = wasEnabled

      _gridView.isHidden = wasEnabled
      if !wasEnabled
      {
        let videoSize = _cameraController.videoDimensions
        if (videoSize.width > 0) && (videoSize.height > 0)
        {
          // videoWidth and videoHeight correspond to the native screen size of the device.
          // For compatibility with non-native screen scalings (a.k.a. zoomed view) we will use
          // these values to calculate the aspect ratio and fit the grid into the height of the parent view.
          let previewSize = _previewView.frame.size
          let previewAspect = previewSize.width / previewSize.height
          let videoAspect = videoSize.width / videoSize.height
          _gridViewWidth?.constant = (previewAspect < videoAspect) ? previewSize.width : previewSize.height * videoAspect
          _gridViewHeight?.constant = (previewAspect < videoAspect) ? previewSize.width / videoAspect : previewSize.height
          _gridView.setNeedsLayout()
        }
      }
    }
  }

}

//MARK:- Private -

private extension MCMainController
{

  func _checkCameraPermission()
  {
    let enableCamera = { ()->() in
      DispatchQueue.main.async {
        self._cameraController.delegate = self
        self._cameraController.setUpCamera()
        self._cameraController.startCapturingVideo()
      }
    }
    switch AVCaptureDevice.authorizationStatus(for: .video)
    {
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { (granted : Bool) in
        if granted
        {
          enableCamera()
        }
        else
        {
          self._handleAccessDeniedToCamera()
        }
      }
    case .authorized:
      if !_cameraController.cameraIsReady
      {
        enableCamera()
      }
      else
      {
        _helpOverlayManager?.enabled = false
        _helpButton.pressed = false
        _showMessage(nil)
      }
    case .denied: fallthrough
    case .restricted:
      _handleAccessDeniedToCamera()
    }
  }

  func _updateHelpButtonVisibility()
  {
    _helpButton.isHidden = !UserDefaults.standard.bool(forKey: MCPreferenceKey.ShowHelpButton.rawValue)
  }

  func _handleAccessDeniedToCamera()
  {
    _showMessage(MCLoc("CameraPermission"))
    _cameraController.shutDownCamera()
  }

  func _showMessage(_ message : String?)
  {
    if let messageLabel = _messageLabel
    {
      messageLabel.text = message
      messageLabel.isHidden = (message == nil);
    }
  }

  func _captureImage()
  {
    if _cameraController.cameraIsReady
    {
      let status = PHPhotoLibrary.authorizationStatus()
      if (status == .denied) || (status == .restricted)
      {
        _showMessage(MCLoc("PhotoLibraryPermission"))
      }
      else
      {
        _showMessage(nil)
        _cameraController.captureImage() { (image : UIImage) in
          UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
      }
    }
  }

  func _screenVariant(w568: CGFloat, w667: CGFloat, w736: CGFloat, w812: CGFloat) -> CGFloat
  {
    switch _screenWidth
    {
      case .w568: return w568
      case .w667: return w667
      case .w736: return w736
      case .w812: return w812
    }
  }
}

//MARK:- MCCameraControllerDelegate -

extension MCMainController : MCCameraControllerDelegate
{
  func cameraController(_ controller : MCCameraController, didUpdateExposureTargetOffset offset : Float)
  {
    _exposureOffsetView.offsetValue = offset
  }

  func cameraController(_ controller : MCCameraController, didUpdateExposureDuration seconds : Double)
  {
    if seconds > 1.0
    {
      _shutterSpeedIndicator.text = String(format:"%.0f″", seconds)
    }
    else
    {
      let inverse = 1.0/seconds
      _shutterSpeedIndicator.text = String(format:"%.0f", inverse)
    }
  }

  func cameraController(_ controller : MCCameraController, didUpdateISO iso : Float)
  {
    _isoIndicator.text = String(format:"%.0f", iso)
  }

  func cameraControllerShouldPassVideoData(_ controller : MCCameraController) -> Bool
  {
#if arch(arm64)
    return (Date.timeIntervalSinceReferenceDate - _lastHistogramSampleTime) > 0.05 // seconds
#else
    return true
#endif
  }

  func cameraController(_ controller : MCCameraController, hasNewVideoData pixelBuffer : CVPixelBuffer, completionHandler handler : @escaping ()->() )
  {
#if arch(arm64)
    DispatchQueue.main.sync {
      _histogram?.updateFromPixelData(pixelBuffer) {
        let now = Date.timeIntervalSinceReferenceDate
        #if false // performance analysis
          let timeDiff = Double(1e3 * (now - samplingTime))
          println(String(format:"updated histogram in %3.1f milliseconds", timeDiff))
        #endif
        self._lastHistogramSampleTime = now
        handler()
      }
    }
#endif
  }

  var currentUserFocusPosition : Float
  {
    return _focusSlider.value
  }

  var lastStoredUserFocusPosition : Float
  {
    return max(0.0, min(1.0, UserDefaults.standard.float(forKey: MCPreferenceKey.ISO.rawValue)))
  }

  func update(userFocusPosition newFocusPosition: Float, forCameraController : MCCameraController)
  {
    _focusSlider.value = newFocusPosition
  }

  func update(userISO ISOValue : Float, forCameraController : MCCameraController)
  {
    _isoDial.dialValue = ISOValue
  }

  var lastStoredUserISO : Float
  {
    return max(0.0, min(1.0, UserDefaults.standard.float(forKey: MCPreferenceKey.FocalDistance.rawValue)))
  }

  func update(userShutter newShutter: Float, forCameraController: MCCameraController)
  {
    _speedDial.dialValue = newShutter
  }

  var lastStoredUserShutter : Float
  {
    return max(0.0, min(1.0, UserDefaults.standard.float(forKey: MCPreferenceKey.Shutter.rawValue)))
  }

  func previewLayer(forCameraController : MCCameraController) -> AVCaptureVideoPreviewLayer
  {
    return _previewView.layer as! AVCaptureVideoPreviewLayer
  }
}

// MARK:- MCSliderControlDelegate -

extension MCMainController : MCSliderControlDelegate
{

  func beginValueChangeForSliderControl(_ slider : MCSliderControl)
  {
    self.updateValueForSliderControl(slider)
  }

  func endValueChangeForSliderControl(_ slider : MCSliderControl)
  {
    if slider === _focusSlider
    {
      UserDefaults.standard.set(_focusSlider.value, forKey:MCPreferenceKey.FocalDistance.rawValue)
    }
  }

  func updateValueForSliderControl(_ slider : MCSliderControl)
  {
    if slider === _focusSlider
    {
      _cameraController.handleFocusChangeIntent(newValue:_focusSlider.value) {
        self._focusSlider.value = $0
      }
    }
  }

}

//MARK:- GUI Layout -

private extension MCMainController
{

  func _layoutUI()
  {
    //_removeAllConstraints()

    _layoutPreview()
    _layoutDials()
    _layoutFocusSlider()
    _layoutShutterButton()
    _layoutMessageLabel()
    _layoutGridView()
    _layoutHistogramView()
    _layoutLevelIndicator()
    _layoutHistogramButtonAndGridButton()
    _layoutHelpButton()
    _layoutExposureOffsetIndicator()
    _layoutSpeedAndISOIndicators()

    _applyLayoutStyleToConstraints()

    //_printActiveConstraints()
  }

  func _layoutPreview()
  {
    let hMargin = _screenVariant(w568: 150.0, w667: 180.0, w736: 200.0, w812:180.0)

    _addLeftHandConstraint(NSLayoutConstraint(item: _previewView, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: hMargin), "MCLeftHandedPreview1")
    _addLeftHandConstraint(NSLayoutConstraint(item: _previewView, attribute: .right, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1.0, constant: 0.0), "MCLeftHandedPreview2")

    _addRightHandConstraint(NSLayoutConstraint(item: _previewView, attribute: .right, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1.0, constant: -hMargin), "MCRightHandedPreview2")
    _addRightHandConstraint(NSLayoutConstraint(item: _previewView, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: 0.0), "MCRightHandedPreview1")

    self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[preview]|", options: [], metrics: nil, views: ["preview" : _previewView]))
  }

  func _layoutDials()
  {
    let diameter = _screenVariant(w568: 220.0, w667: 258.0, w736: 270.0, w812:270.0)

    let speedDialCenterXConstraintLeftHanded = NSLayoutConstraint(item: _speedDial, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: 0.0)
    speedDialCenterXConstraintLeftHanded.identifier = "MCLeftHandedDial1"
    _leftHandConstraints.append(speedDialCenterXConstraintLeftHanded)
    self.view.addConstraint(speedDialCenterXConstraintLeftHanded)

    let speedDialCenterXConstraintRightHanded = NSLayoutConstraint(item: _speedDial, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1.0, constant: 0.0)
    speedDialCenterXConstraintRightHanded.identifier = "MCLeftHandedDial2"
    _rightHandConstraints.append(speedDialCenterXConstraintRightHanded)
    self.view.addConstraint(speedDialCenterXConstraintRightHanded)

    _speedDial.addConstraint(NSLayoutConstraint(item: _speedDial, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: diameter))
    _speedDial.addConstraint(NSLayoutConstraint(item: _speedDial, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: diameter))
    self.view.addConstraint(NSLayoutConstraint(item: _speedDial, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 0.0))

    let isoDialCenterXConstraintLeftHanded = NSLayoutConstraint(item: _isoDial, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: 0.0)
    isoDialCenterXConstraintLeftHanded.identifier = "MCLeftHandedDial3"
    _leftHandConstraints.append(isoDialCenterXConstraintLeftHanded)
    self.view.addConstraint(isoDialCenterXConstraintLeftHanded)

    let isoDialCenterXConstraintRightHanded = NSLayoutConstraint(item: _isoDial, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1.0, constant: 0.0)
    isoDialCenterXConstraintRightHanded.identifier = "MCLeftHandedDial4"
    _rightHandConstraints.append(isoDialCenterXConstraintRightHanded)
    self.view.addConstraint(isoDialCenterXConstraintRightHanded)

    _isoDial.addConstraint(NSLayoutConstraint(item: _isoDial, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: diameter))
    _isoDial.addConstraint(NSLayoutConstraint(item: _isoDial, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: diameter))
    self.view.addConstraint(NSLayoutConstraint(item: _isoDial, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: 0.0))
  }

  func _layoutFocusSlider()
  {
    let marginToPreview = _screenVariant(w568: 0, w667: 10, w736: 10, w812: -40)
    _addLeftHandConstraint(NSLayoutConstraint(item: _focusSlider, attribute: .right, relatedBy: .equal, toItem: _previewView, attribute: .left, multiplier: 1.0, constant: -marginToPreview), "MCLeftHandedFocus1")
    _addRightHandConstraint(NSLayoutConstraint(item: _focusSlider, attribute: .left, relatedBy: .equal, toItem: _previewView, attribute: .right, multiplier: 1.0, constant: marginToPreview), "MCLeftHandedFocus2")

    self.view.addConstraint(NSLayoutConstraint(item: _focusSlider, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1.0, constant: 0.0))
    let width = _screenVariant(w568: 60.0, w667: 72.0, w736: 80.0, w812: 72.0)
    self.view.addConstraint(NSLayoutConstraint(item: _focusSlider, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: width))
    let height = _screenVariant(w568: 140.0, w667: 180.0, w736: 200.0, w812: 180.0)
    self.view.addConstraint(NSLayoutConstraint(item: _focusSlider, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: height))
  }

  func _layoutShutterButton()
  {
    let diameter = _screenVariant(w568: 132, w667: 156, w736: 162, w812: 162)
    _shutterButton.addConstraint(NSLayoutConstraint(item: _shutterButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: diameter))
    _shutterButton.addConstraint(NSLayoutConstraint(item: _shutterButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: diameter))
    _addRightHandConstraint(NSLayoutConstraint(item: _shutterButton, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1.0, constant: 0.0), "MCRightHandedShutterButton")
    _addLeftHandConstraint(NSLayoutConstraint(item: _shutterButton, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: 0.0), "MCLeftHandedShutterButton")
    self.view.addConstraint(NSLayoutConstraint(item: _shutterButton, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 0.0))
  }

  func _layoutHelpButton()
  {
    let diameter = _screenVariant(w568: 40, w667: 162, w736: 162, w812: 162)
    _helpButton.addConstraint(NSLayoutConstraint(item: _helpButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: diameter))
    _helpButton.addConstraint(NSLayoutConstraint(item: _helpButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: diameter))
    _addRightHandConstraint(NSLayoutConstraint(item: _helpButton, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1.0, constant: 0))
    _addLeftHandConstraint(NSLayoutConstraint(item: _helpButton, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: 0))
    self.view.addConstraint(NSLayoutConstraint(item: _helpButton, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: 0))
  }

  func _layoutMessageLabel()
  {
    if let messageLabel = _messageLabel
    {
      let width = _screenVariant(w568: 350, w667: 400, w736: 400, w812: 400)
      let height = _screenVariant(w568: 60, w667: 60, w736: 60, w812: 60)
      messageLabel.addConstraint(NSLayoutConstraint(item:messageLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: height))
      messageLabel.addConstraint(NSLayoutConstraint(item:messageLabel, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: width))
      self.view.addConstraint(NSLayoutConstraint(item:messageLabel, attribute: .centerX, relatedBy: .equal, toItem: _previewView, attribute: .centerX, multiplier: 1.0, constant: 0.0))
      self.view.addConstraint(NSLayoutConstraint(item:messageLabel, attribute: .centerY, relatedBy: .equal, toItem: _previewView, attribute: .centerY, multiplier: 1.0, constant: 0.0))
    }
  }

  func _layoutHistogramView()
  {
    if let histogramView = _histogramView
    {
      let verticalOffset = _screenVariant(w568: 100, w667: 120, w736: 120, w812: 120)
      histogramView.addConstraint(NSLayoutConstraint(item:histogramView, attribute: .width, relatedBy: .equal, toItem: nil, attribute:.width, multiplier:1.0, constant:256.0))
      histogramView.addConstraint(NSLayoutConstraint(item:histogramView, attribute: .height, relatedBy: .equal, toItem: nil, attribute:.height, multiplier:1.0, constant:50.0))
      self.view.addConstraint(NSLayoutConstraint(item:histogramView, attribute: .centerX, relatedBy: .equal, toItem: _previewView, attribute:.centerX, multiplier:1.0, constant:0.0))
      self.view.addConstraint(NSLayoutConstraint(item:histogramView, attribute: .centerY, relatedBy: .equal, toItem: _previewView, attribute:.centerY, multiplier:1.0, constant:verticalOffset))
    }
  }

  func _layoutGridView()
  {
    let gridViewWidth = NSLayoutConstraint(item:_gridView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier:1.0, constant:100.0)
    gridViewWidth.identifier = "MCGridViewWidth"
    let gridViewHeight = NSLayoutConstraint(item:_gridView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier:1.0, constant:100.0)
    gridViewHeight.identifier = "MCGridViewHeight"
    _gridView.addConstraint(gridViewWidth)
    _gridView.addConstraint(gridViewHeight)
    _gridViewWidth = gridViewWidth
    _gridViewHeight = gridViewHeight
    self.view.addConstraint(NSLayoutConstraint(item:_gridView, attribute:.centerX, relatedBy:.equal, toItem:_previewView, attribute:.centerX, multiplier:1.0, constant:0.0))
    self.view.addConstraint(NSLayoutConstraint(item:_gridView, attribute:.centerY, relatedBy:.equal, toItem:_previewView, attribute:.centerY, multiplier:1.0, constant:0.0))
  }

  func _layoutLevelIndicator()
  {
    _levelIndicatorView.addConstraint(NSLayoutConstraint(item:_levelIndicatorView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier:1.0, constant:200.0))
    _levelIndicatorView.addConstraint(NSLayoutConstraint(item:_levelIndicatorView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier:1.0, constant:12.0))
    self.view.addConstraint(NSLayoutConstraint(item:_levelIndicatorView, attribute:.centerX, relatedBy:.equal, toItem:_previewView, attribute:.centerX, multiplier:1.0, constant:0.0))
    self.view.addConstraint(NSLayoutConstraint(item:_levelIndicatorView, attribute:.centerY, relatedBy:.equal, toItem:_previewView, attribute:.centerY, multiplier:1.0, constant:0.0))
  }

  func _layoutExposureOffsetIndicator()
  {
    _exposureOffsetView.addConstraint(NSLayoutConstraint(item: _exposureOffsetView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: 100.0))
    _exposureOffsetView.addConstraint(NSLayoutConstraint(item: _exposureOffsetView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: 20.0))
    self.view.addConstraint(NSLayoutConstraint(item: _exposureOffsetView, attribute: .centerX, relatedBy: .equal, toItem: _previewView, attribute: .centerX, multiplier: 1.0, constant: 0.0))
    self.view.addConstraint(NSLayoutConstraint(item: _exposureOffsetView, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 0.0))
  }

  func _layoutHistogramButtonAndGridButton()
  {
    let hMargin = _screenVariant(w568: 10, w667: 100, w736: 120, w812: 80)
    let vDistance = _screenVariant(w568: 30, w667: 20, w736: 12, w812: 12)
    let height = _screenVariant(w568: 22, w667: 24, w736: 28, w812: 28)

    _addLeftHandConstraint(NSLayoutConstraint(item: _gridButton, attribute: .right, relatedBy: .equal, toItem: _previewView, attribute: .left, multiplier: 1.0, constant: -hMargin), "MCLeftHandedGridButton")
    _addRightHandConstraint(NSLayoutConstraint(item: _gridButton, attribute: .left, relatedBy: .equal, toItem: _previewView, attribute: .right, multiplier: 1.0, constant: hMargin), "MCRightHandedGridButton")
    self.view.addConstraint(NSLayoutConstraint(item: _gridButton, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1.0, constant: vDistance/2.0))
    self.view.addConstraint(NSLayoutConstraint(item: _gridButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: height))

    _addLeftHandConstraint(NSLayoutConstraint(item: _histogramButton, attribute: .right, relatedBy: .equal, toItem: _gridButton, attribute: .right, multiplier: 1.0, constant: 0.0), "MCLeftHandedHistogramButton")
    _addRightHandConstraint(NSLayoutConstraint(item: _histogramButton, attribute: .left, relatedBy: .equal, toItem: _gridButton, attribute: .left, multiplier: 1.0, constant: 0.0), "MCRightHandedHistogramButton")
    self.view.addConstraint(NSLayoutConstraint(item: _histogramButton, attribute: .bottom, relatedBy: .equal, toItem: _gridButton, attribute: .top, multiplier: 1.0, constant: -vDistance))
    self.view.addConstraint(NSLayoutConstraint(item: _histogramButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: height))
  }

  func _layoutSpeedAndISOIndicators()
  {
    let marginToDial = _screenVariant(w568: 10, w667: 10, w736: 10, w812: 30)
    _addRightHandConstraint(NSLayoutConstraint(item: _shutterSpeedIndicator, attribute: .right, relatedBy: .equal, toItem: _shutterLabel, attribute: .right, multiplier: 1.0, constant: 0.0), "MCRightHandedLabelAlign1")
    _addRightHandConstraint(NSLayoutConstraint(item: _shutterSpeedIndicator, attribute: .right, relatedBy: .equal, toItem: _isoIndicator, attribute: .right, multiplier: 1.0, constant: 0.0), "MCRightHandedLabelAlign2")
    _addRightHandConstraint(NSLayoutConstraint(item: _shutterSpeedIndicator, attribute: .right, relatedBy: .equal, toItem: _isoLabel, attribute: .right, multiplier: 1.0, constant: 0.0), "MCRightHandedLabelAlign3")
    _addRightHandConstraint(NSLayoutConstraint(item: _shutterSpeedIndicator, attribute: .right, relatedBy: .equal, toItem: _speedDial, attribute: .left, multiplier: 1.0, constant: -marginToDial), "MCRightHandedLabelAlign4")

    _addLeftHandConstraint(NSLayoutConstraint(item: _shutterSpeedIndicator, attribute: .right, relatedBy: .equal, toItem: _shutterLabel, attribute: .right, multiplier: 1.0, constant: 0.0), "MCLeftHandedLabelAlign1")
    _addLeftHandConstraint(NSLayoutConstraint(item: _shutterSpeedIndicator, attribute: .right, relatedBy: .equal, toItem: _isoIndicator, attribute: .right, multiplier: 1.0, constant: 0.0), "MCLeftHandedLabelAlign2")
    _addLeftHandConstraint(NSLayoutConstraint(item: _shutterSpeedIndicator, attribute: .right, relatedBy: .equal, toItem: _isoLabel, attribute: .right, multiplier: 1.0, constant: 0.0), "MCLeftHandedLabelAlign3")
    _addLeftHandConstraint(NSLayoutConstraint(item: _shutterSpeedIndicator, attribute: .left, relatedBy: .equal, toItem: _speedDial, attribute: .right, multiplier: 1.0, constant: marginToDial), "MCLeftHandedLabelAlign4")

    self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat:"V:|-(4)-[speedLabel]-(4)-[speedInd]", options:[], metrics:["width" : 200 ], views: [ "speedLabel" : _shutterLabel, "speedInd" : _shutterSpeedIndicator]))
    self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat:"V:[isoInd]-(4)-[isoLabel]-(4)-|", options:[], metrics:["width" : 200 ], views: [ "isoLabel" : _isoLabel, "isoInd" : _isoIndicator]))
  }

  func _addRightHandConstraint(_ constraint : NSLayoutConstraint, _ identifier : String? = nil)
  {
    self.view.addConstraint(constraint)
    _rightHandConstraints.append(constraint)
    if let label = identifier
    {
      constraint.identifier = label
    }
  }

  func _addLeftHandConstraint(_ constraint : NSLayoutConstraint, _ identifier : String? = nil)
  {
    self.view.addConstraint(constraint)
    _leftHandConstraints.append(constraint)
    if let label = identifier
    {
      constraint.identifier = label
    }
  }

  func _applyLayoutStyle()
  {
    _cameraController.videoOrientation = _layoutStyle == .left ? .landscapeLeft : .landscapeRight
    _applyLayoutStyleToConstraints()
    _helpOverlayManager?.clearTags()
    _buildHelpOverlays()
    self.view.setNeedsLayout()
    _isoDial.increasesClockwise = _layoutStyle == .left
    _isoDial.gradientOffset = _layoutStyle == .left ? 0.0 : -90.0
    _speedDial.increasesClockwise = _layoutStyle == .left
    _speedDial.gradientOffset = _layoutStyle == .left ? 90.0 : 270.0
  }

  func _applyLayoutStyleToConstraints()
  {
    NSLayoutConstraint.deactivate(_layoutStyle == .left ? _rightHandConstraints : _leftHandConstraints)
    NSLayoutConstraint.activate(_layoutStyle == .left ? _leftHandConstraints : _rightHandConstraints)
  }

  func _removeAllConstraints()
  {
    let removeConstraints = { (view : UIView) in NSLayoutConstraint.deactivate(view.constraints) }
    removeConstraints(self.view)
    removeConstraints(_previewView)
    removeConstraints(_shutterSpeedIndicator)
    removeConstraints(_speedDial)
    removeConstraints(_isoDial)
    removeConstraints(_focusSlider)
    removeConstraints(_shutterButton)
    removeConstraints(_helpButton)
    removeConstraints(_messageLabel!)
    removeConstraints(_histogramView!)
    removeConstraints(_gridView)
    removeConstraints(_exposureOffsetView)
    removeConstraints(_histogramButton)
    removeConstraints(_gridButton)
    removeConstraints(_shutterLabel)
    removeConstraints(_levelIndicatorView)
    removeConstraints(_isoIndicator)
    removeConstraints(_isoLabel)
  }

  func _printActiveConstraints()
  {
    print("-----------------------------------------------------------------------------------------------------------")
    let constraints = self.view.constraints
    for constraint in constraints
    {
      if constraint.isActive
      {
        print(constraint.description)
      }
    }
  }

}

//MARK:- GUI view creation -

private extension MCMainController
{
  func _buildUI()
  {
    self.view.addSubview(_previewView)
    _previewView.translatesAutoresizingMaskIntoConstraints = false
  #if arch(x86_64)
    _previewView.backgroundColor = UIColor.orange
  #endif
    _buildHistogramView()
    _buildGridView()
    _buildLevelIndicatorView()
    _buildDials()
    _buildShutterButtonAndHelpButton()
    _buildHistogramButtonAndGridButton()
    _buildHistogram()
    _buildFocusSlider()
    _buildISOAndSpeedIndicators()
    _buildTopIndicators()
    _buildHelpOverlays()
    _buildMessageLabel()
  }

  func _buildHistogramView()
  {
    let histogramView = MCHistogramView(frame:CGRect.zero)
    histogramView.isOpaque = false
    histogramView.backgroundColor = UIColor.clear
    self.view.addSubview(histogramView)
    histogramView.translatesAutoresizingMaskIntoConstraints = false
    _histogramView = histogramView
  }

  func _buildGridView()
  {
    self.view.addSubview(_gridView)
    _gridView.isOpaque = false
    _gridView.isHidden = true
    _gridView.translatesAutoresizingMaskIntoConstraints = false
  }

  func _buildLevelIndicatorView()
  {
    let sublayer = _levelIndicator.layer
    let sublayerSize = sublayer.frame.size
    _levelIndicatorView.frame = CGRect(x: 0, y: 0, width: sublayerSize.width, height: sublayerSize.height)
    _levelIndicatorView.layer.addSublayer(sublayer)
    _levelIndicatorView.isOpaque = false
    _levelIndicatorView.clipsToBounds = false
    _levelIndicatorView.isHidden = true
    self.view.addSubview(_levelIndicatorView)
    _levelIndicatorView.translatesAutoresizingMaskIntoConstraints = false
  }

  func _buildISOAndSpeedIndicators()
  {
    let labelFont = UIFont.systemFont(ofSize: _screenVariant(w568: 12.0, w667: 14.0, w736: 16.0, w812:16.0))

    self.view.addSubview(_isoIndicator)
    _isoIndicator.text = "-"
    _isoIndicator.font = labelFont
    _isoIndicator.textColor = MCIndicatorColor
    _isoIndicator.translatesAutoresizingMaskIntoConstraints = false

    self.view.addSubview(_isoLabel)
    _isoLabel.text = "ISO"
    _isoLabel.font = labelFont
    _isoLabel.textColor = MCIndicatorLabelColor
    _isoLabel.translatesAutoresizingMaskIntoConstraints = false

    self.view.addSubview(_shutterSpeedIndicator)
    _shutterSpeedIndicator.text = "-"
    _shutterSpeedIndicator.font = labelFont
    _shutterSpeedIndicator.textColor = MCIndicatorColor
    _shutterSpeedIndicator.translatesAutoresizingMaskIntoConstraints = false

    self.view.addSubview(_shutterLabel)
    _shutterLabel.text = "SHTR"
    _shutterLabel.font = labelFont
    _shutterLabel.textColor = MCIndicatorLabelColor
    _shutterLabel.translatesAutoresizingMaskIntoConstraints = false
  }

  func _buildDials()
  {
    self.view.addSubview(_speedDial)
    _speedDial.dialAction = { (newValue : Float, update : Bool) in self._cameraController.handleShutterSpeedChangeIntent(newValue:newValue, handler:{
        (newDialValue) in
        if update
        {
          self._speedDial.dialValue = newDialValue
          UserDefaults.standard.set(newDialValue, forKey:MCPreferenceKey.Shutter.rawValue)
        }
      })
    }
    _speedDial.tickCount = 36
    _speedDial.tickColor = MCControlColor;
    _speedDial.clipsToBounds = false
    _speedDial.translatesAutoresizingMaskIntoConstraints = false

    self.view.addSubview(_isoDial)
    _isoDial.dialAction = { (newValue : Float, update : Bool) in self._cameraController.handleISOChangeIntent(newValue:newValue, handler:{ (normalizedISO) in
        if update
        {
          self._isoDial.dialValue = normalizedISO
          UserDefaults.standard.set(normalizedISO, forKey:MCPreferenceKey.ISO.rawValue)
        }
      })
    }
    _isoDial.tickCount = 36
    _isoDial.tickColor = MCControlColor
    _isoDial.clipsToBounds = false
    _isoDial.translatesAutoresizingMaskIntoConstraints = false
  }

  func _buildShutterButtonAndHelpButton()
  {
    self.view.addSubview(_shutterButton)
    _shutterButton.normalColor = UIColor(red: 173.0/255.0, green: 80.0/255.0, blue: 80.0/255.0, alpha: 1.0)
    _shutterButton.pressedColor = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
    _shutterButton.buttonAction = { self._captureImage() }
    _shutterButton.clipsToBounds = false
    _shutterButton.translatesAutoresizingMaskIntoConstraints = false

    self.view.addSubview(_helpButton)
    _helpButton.isToggleButton = true
    _helpButton.normalColor = UIColor(red: 0.4, green: 0.4, blue: 0.0, alpha: 1.0)
    _helpButton.pressedColor = UIColor(red: 0.75, green: 0.75, blue: 0.0, alpha: 1.0)
    _helpButton.translatesAutoresizingMaskIntoConstraints = false
  }

  func _buildHistogramButtonAndGridButton()
  {
    let font = UIFont.systemFont(ofSize: _screenVariant(w568: 20.0, w667: 22.0, w736: 24.0, w812:24.0), weight: UIFont.Weight.regular)

    self.view.addSubview(_histogramButton)
    _histogramButton.setTitle("HIST", for: UIControlState())
    _histogramButton.setTitleColor(MCControlColor, for:UIControlState())
    _histogramButton.titleLabel?.font = font
    _histogramButton.addTarget(self, action: #selector(MCMainController.toggleHistogram(_:)), for: .touchUpInside)
    _histogramButton.translatesAutoresizingMaskIntoConstraints = false

    self.view.addSubview(_gridButton)
    _gridButton.setTitle("GRID", for: UIControlState())
    _gridButton.setTitleColor(MCControlColor, for:UIControlState())
    _gridButton.titleLabel?.font = font
    _gridButton.addTarget(self, action: #selector(MCMainController.toggleGrid(_:)), for: .touchUpInside)
    _gridButton.translatesAutoresizingMaskIntoConstraints = false
  }

  func _buildHistogram()
  {
    if _histogramView == nil
    {
      fatalError("The histogram view should have been initialized at this point.")
    }
    if _histogram == nil
    {
    #if arch(arm64)
      let metalLayer = _histogramView!.layer as! CAMetalLayer
      _histogram = MCHistogram(renderLayer: metalLayer)
      _histogram?.enabled = false
    #endif
    }
  }

  func _buildFocusSlider()
  {
    self.view.addSubview(_focusSlider)
    _focusSlider.translatesAutoresizingMaskIntoConstraints = false
    _focusSlider.isOpaque = false
    _focusSlider.style = .tickMarked
    _focusSlider.tickCount = 12
    _focusSlider.delegate = self
  }

  func _buildTopIndicators()
  {
    _exposureOffsetView.maxOffset = 2.0
    _exposureOffsetView.minOffset = -2.0
    self.view.addSubview(_exposureOffsetView)
    _exposureOffsetView.translatesAutoresizingMaskIntoConstraints = false
  }

  func _buildHelpOverlays()
  {
    if _helpOverlayManager == nil
    {
      let help = MCHelpOverlayManager(rootView: self.view)
      _helpButton.buttonAction = { help.enabled = !help.enabled }
      _helpOverlayManager = help
    }
    _helpOverlayManager?.addHelpTag(MCLoc("Help_Histo"), forView:_histogramButton, anchor:.top, offset:0.0)
    _helpOverlayManager?.addHelpTag(MCLoc("Help_Level"), forView:_gridButton, anchor:.bottom, offset:0.0)
    _helpOverlayManager?.addHelpTag(MCLoc("Help_ExpOffset"), forView:_exposureOffsetView, anchor:.bottom, offset:2.0)
    _helpOverlayManager?.addHelpTag(MCLoc("Help_Focus"), forView:_focusSlider, anchor:(_layoutStyle == .right) ? .left : .right, offset:10.0)
    _helpOverlayManager?.addHelpTag(MCLoc("Help_ISO"), forView:_isoDial, anchor:(_layoutStyle == .right) ? .topLeft : .topRight, offset:-60.0)
    _helpOverlayManager?.addHelpTag(MCLoc("Help_Speed"), forView:_speedDial, anchor:(_layoutStyle == .right) ? .bottomLeft : .bottomRight, offset:-60.0)
    _helpOverlayManager?.addHelpTag(MCLoc("Help_Shutter"), forView:_shutterButton, anchor:(_layoutStyle == .right) ? .bottomLeft : .bottomRight, offset:-45.0)
    _helpOverlayManager?.addHelpTag(MCLoc("Help_Disable"), forView:_helpButton, anchor:(_layoutStyle == .right) ? .topLeft : .topRight, offset:-45.0)
  }

  func _buildMessageLabel()
  {
    if _messageLabel == nil
    {
      let messageLabel = UILabel(frame: CGRect.zero)
      messageLabel.isOpaque = false
      messageLabel.backgroundColor = nil;
      messageLabel.numberOfLines = 0;
      messageLabel.layer.cornerRadius = 18.0
      messageLabel.layer.backgroundColor = MCBackgroundColor.cgColor
      messageLabel.textColor = MCWarningColor
      messageLabel.textAlignment = .center
      messageLabel.font = UIFont.systemFont(ofSize: 14.0)
      messageLabel.isHidden = true
      messageLabel.isUserInteractionEnabled = true
      messageLabel.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(MCMainController.openSettings(_:))))
      self.view.addSubview(messageLabel)
      messageLabel.translatesAutoresizingMaskIntoConstraints = false
      _messageLabel = messageLabel
    }
  }

}
