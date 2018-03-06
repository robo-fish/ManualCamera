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

protocol MCCameraControllerDelegate
{
  func cameraController(_ controller : MCCameraController, didUpdateExposureTargetOffset offset : Float)
  func cameraController(_ controller : MCCameraController, didUpdateExposureDuration duration : Double)
  func cameraController(_ controller : MCCameraController, didUpdateISO iso : Float)
  func cameraControllerShouldPassVideoData(_ controller : MCCameraController) -> Bool
  func cameraController(_ controller : MCCameraController, hasNewVideoData pixelBuffer : CVPixelBuffer, completionHandler : @escaping ()->())
  var currentUserFocusPosition : Float {get}
  var lastStoredUserFocusPosition : Float {get}
  func update(userFocusPosition : Float, forCameraController controller : MCCameraController)
  var lastStoredUserISO : Float {get}
  func update(userISO newISO : Float, forCameraController controller : MCCameraController)
  var lastStoredUserShutter : Float {get}
  func update(userShutter newShutter : Float, forCameraController : MCCameraController)
  func previewLayer(forCameraController controller : MCCameraController) -> AVCaptureVideoPreviewLayer
}

class MCCameraController : NSObject
{
  var delegate : MCCameraControllerDelegate?
  var cameraIsReady : Bool { return _cameraDevice != nil }

  private let MaxShutterSpeed = Double(8000.0)
  private let MinShutterSpeed = Double(20.0) // The lower the minimum shutter speed, the more likely a session runtime error is.
  private let _testMode = MCRuntimeDebugOption(name: "TestMode")

  private var _cameraDevice : AVCaptureDevice?
  private var _cameraInput : AVCaptureDeviceInput?
  private var _cameraPhotoOutput : AVCapturePhotoOutput?
  private var _cameraVideoOutput : AVCaptureVideoDataOutput?
  private var _cameraSession : AVCaptureSession?
  private lazy var _cameraSessionQueue : DispatchQueue = { return DispatchQueue(label:"camera capture session") }()
  private var _videoOrientation = AVCaptureVideoOrientation.landscapeRight
  private var _imageCaptureHandler : ((UIImage)->())?
  private var _valueObservations = [NSKeyValueObservation]()

  override init()
  {
    super.init()
  }

  func setUpCamera()
  {
    if _testMode { return }
    guard let device = _getManualCameraDevice() else { return }
    _cameraDevice = device
    let cameraVideoOutput = AVCaptureVideoDataOutput()
    cameraVideoOutput.alwaysDiscardsLateVideoFrames = true
    cameraVideoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]
    cameraVideoOutput.setSampleBufferDelegate(self, queue:DispatchQueue(label:"camera sample buffer"));
    _cameraVideoOutput = cameraVideoOutput
    _cameraPhotoOutput = AVCapturePhotoOutput()

    do { _cameraInput = try AVCaptureDeviceInput(device:device) }
    catch { print("Error while initializing the camera. \(error.localizedDescription)") }

    do
    {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      device.exposureMode = .custom
      device.focusMode = .locked
      device.setFocusModeLocked(lensPosition:self.delegate?.currentUserFocusPosition ?? 0.0)
      // device.activeVideoMaxFrameDuration = CMTimeMakeWithSeconds(1.0/MinShutterSpeed, 1000000)
      // device.activeVideoMinFrameDuration = CMTimeMakeWithSeconds(1.0/MaxShutterSpeed, 1000000)

      _addParameterObservers(forDevice:device)
    }
    catch
    {
      print("Error while setting camera parameters. \(error.localizedDescription)")
    }
  }

  private func _addParameterObservers(forDevice device : AVCaptureDevice)
  {
    //_valueObservations.append( device.observe(\.lensPosition) { (observed, change) in /* do nothing */ }
    _valueObservations.append( device.observe(\.exposureTargetOffset) { (observed, change) in
      self.delegate?.cameraController(self, didUpdateExposureTargetOffset:observed.exposureTargetOffset)
    })
    _valueObservations.append( device.observe(\.exposureDuration) { (observed, change)->() in
      self.delegate?.cameraController(self, didUpdateExposureDuration:CMTimeGetSeconds(observed.exposureDuration))
    })
    _valueObservations.append( device.observe(\AVCaptureDevice.ISO) { (observed, change)->() in
      self.delegate?.cameraController(self, didUpdateISO:observed.iso)
    })
  }

  private func _addParameterObservers(forSession session : AVCaptureSession)
  {
    _valueObservations.append( session.observe(\.running) { (observed, change) in
      if let isRunning = change.newValue
      {
        if isRunning
        {
          self._restoreUserState()
        }
      }
    })
    _valueObservations.append( session.observe(\.interrupted) { (observed, change) in
      if let isInterrupted = change.newValue
      {
        print("Camera session is \(isInterrupted ? "interrupted" : "resumed")")
      }
    })
  }

  func shutDownCamera()
  {
    _valueObservations.removeAll()
    if let session = _cameraSession
    {
      session.stopRunning()
      session.beginConfiguration()
      session.removeInput(_cameraInput!)
      session.removeOutput(_cameraPhotoOutput!)
      session.removeOutput(_cameraVideoOutput!)
      session.commitConfiguration()
    }
    _cameraInput = nil
    _cameraPhotoOutput = nil
    _cameraVideoOutput = nil
    _cameraDevice = nil
  }

  var videoDimensions : CGSize
  {
    guard !_testMode else { return CGSize(width:800, height:400) }
    guard let videoSettings = _cameraVideoOutput?.videoSettings else { return .zero }
    var result = CGSize.zero
    if let widthNumber = videoSettings[AVVideoWidthKey] as? NSNumber
    {
      result.width = CGFloat(widthNumber.intValue)
    }
    else if let widthNumber = videoSettings["Width"] as? NSNumber
    {
      result.width = CGFloat(widthNumber.intValue)
    }
    if let heightNumber = videoSettings[AVVideoHeightKey] as? NSNumber
    {
      result.height = CGFloat(heightNumber.intValue)
    }
    else if let heightNumber = videoSettings["Height"] as? NSNumber
    {
      result.height = CGFloat(heightNumber.intValue)
    }
    return result
  }

  var videoOrientation : AVCaptureVideoOrientation
  {
    get { return _videoOrientation }
    set
    {
      if _videoOrientation != newValue
      {
        _videoOrientation = newValue
        _cameraPhotoOutput?.connection(with:.video)?.videoOrientation = _videoOrientation
        _cameraVideoOutput?.connection(with:.video)?.videoOrientation = _videoOrientation
        self.delegate?.previewLayer(forCameraController:self).connection?.videoOrientation = _videoOrientation
      }
    }
  }

  func captureImage(handler : @escaping (UIImage)->())
  {
    guard !_testMode else { return }
    _imageCaptureHandler = handler
    _cameraPhotoOutput?.capturePhoto(with: AVCapturePhotoSettings(format:[AVVideoCodecKey:AVVideoCodecType.jpeg]), delegate: self)
  }

  func handleFocusChangeIntent(newValue : Float, handler : @escaping (Float)->())
  {
    guard let device = _cameraDevice else { return }
    do
    {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      device.setFocusModeLocked(lensPosition:newValue) { (completionTimestamp : CMTime) in
        handler(device.lensPosition)
      }
    }
    catch
    {
      print("Error while setting focus length parameter: \(error.localizedDescription)")
    }
  }

  func handleISOChangeIntent(newValue : Float, handler : @escaping (Float)->())
  {
    guard let device = _cameraDevice else { return }
    do
    {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      let newISOValue = _standardISOForNormalizedISO(max(min(newValue, 1.0), 0.0))
      device.setExposureModeCustom(duration:AVCaptureDevice.currentExposureDuration, iso:newISOValue) { (completionTimestamp : CMTime) in
        let normalizedValue = self._normalizedISOForStandardISO(device.iso)
        handler(normalizedValue)
      }
    }
    catch
    {
      print("Error while setting the ISO parameter: \(error.localizedDescription)")
    }
  }

  func handleShutterSpeedChangeIntent(newValue : Float, handler : @escaping (Float)->())
  {
    guard let device = _cameraDevice else { return }
    do
    {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      let newExposureDuration = _exposureDurationForDialValue(newValue)
      device.setExposureModeCustom(duration:newExposureDuration, iso:AVCaptureDevice.currentISO) { (completionTimestamp : CMTime) in
        handler(self._dialValueForExposureDuration(device.exposureDuration))
      }
    }
    catch
    {
      print("Error while setting the shutter speed parameter: \(error.localizedDescription)")
    }
  }

  func startCapturingVideo()
  {
    guard !_testMode else { return }
    let session = AVCaptureSession()
    _cameraSession = session
    _addParameterObservers(forSession:session)
    guard session.canSetSessionPreset(.photo) else { print("Can not initialize a photo capture session.") ; return }
    guard let input = _cameraInput else { return }
    session.beginConfiguration()
    session.sessionPreset = .photo
    if session.canAddInput(input)
    {
      session.addInput(input)
    }
    if let photoOutput = _cameraPhotoOutput, session.canAddOutput(photoOutput)
    {
      session.addOutput(photoOutput)
      photoOutput.connection(with: .video)?.videoOrientation = _videoOrientation
    }
    if let videoOutput = _cameraVideoOutput, session.canAddOutput(videoOutput)
    {
      session.addOutput(videoOutput)
      videoOutput.connection(with: .video)?.videoOrientation = _videoOrientation
    }
    session.commitConfiguration()

    if let previewLayer = self.delegate?.previewLayer(forCameraController:self)
    {
      previewLayer.session = session
      previewLayer.connection?.videoOrientation = _videoOrientation
      previewLayer.videoGravity = .resizeAspect
    }

    // Actions and configurations done on the session or the camera device are blocking calls.
    // For this reason the session will run in a background queue.
    _cameraSessionQueue.async {
      session.startRunning()
    }
  }

  @objc func handleSessionRuntimeError(notification : Notification)
  {
    if let errorMessage = notification.userInfo?[AVCaptureSessionErrorKey]
    {
      print("An error occurred during the image capture session.\n\(errorMessage)")
      _cameraSessionQueue.async {
        self._cameraSession?.startRunning() // Restarting the session
      }
    }
  }

  private func _getManualCameraDevice() -> AVCaptureDevice?
  {
    //device = AVCaptureDevice.defaultDevice(mediaType:.video)
    let types : [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera
    //, .builtInTelephotoCamera
    //, .builtInDualCamera
    //, .builtInTrueDepthCamera
    ]
    let session = AVCaptureDevice.DiscoverySession(deviceTypes:types, mediaType:.video, position:.back)
    for device in session.devices
    {
      if device.isFocusModeSupported(.locked) && device.isExposureModeSupported(.custom)
      {
        return device
      }
    }
    return nil
  }

  private func _exposureDurationForDialValue(_ dialValue : Float) -> CMTime
  {
    guard let format = _cameraDevice?.activeFormat else { return kCMTimeZero }
    let maxSpeed = log10(min(MaxShutterSpeed, 1.0/CMTimeGetSeconds(format.minExposureDuration)))
    let minSpeed = log10(max(MinShutterSpeed, 1.0/CMTimeGetSeconds(format.maxExposureDuration)))
    let speed = minSpeed + max(0.0,(min(1.0,Double(dialValue)))) * (maxSpeed - minSpeed)
    let exposure = pow(10.0,-speed)
    return (exposure == 0.0) /* because speed == inf */? format.maxExposureDuration : CMTimeMakeWithSeconds(exposure, 1000000)
  }

  private func _dialValueForExposureDuration(_ duration : CMTime) -> Float
  {
    guard let format = _cameraDevice?.activeFormat else { return 0 }
    let maxSpeed = log10(min(MaxShutterSpeed, 1.0/CMTimeGetSeconds(format.minExposureDuration)))
    let minSpeed = log10(max(MinShutterSpeed, 1.0/CMTimeGetSeconds(format.maxExposureDuration)))
    let speed = -log10(CMTimeGetSeconds(duration))
    return max(0.0, min(1.0, Float((speed - minSpeed)/(maxSpeed - minSpeed))))
  }

  private func _standardISOForNormalizedISO(_ dialValue : Float) -> Float
  {
    guard let format = _cameraDevice?.activeFormat else { return 200.0 }
    return format.minISO + dialValue * (format.maxISO - format.minISO)
  }

  private func _normalizedISOForStandardISO(_ ISO : Float) -> Float
  {
    guard let format = _cameraDevice?.activeFormat else { return 0.0 }
    if (format.minISO > 0.0) && (format.maxISO > format.minISO) && (ISO > format.minISO)
    {
      return (ISO - format.minISO) / (format.maxISO - format.minISO)
    }
    return 0.0
  }

  private func _restoreUserState()
  {
    guard let dele = self.delegate else { return }
    guard let device = _cameraDevice else { return }
    let restoredISODialValue = dele.lastStoredUserISO
    let restoredShutterDialValue = dele.lastStoredUserShutter
    let restoredFocalDistanceSliderValue = dele.lastStoredUserFocusPosition
    do
    {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      let isoValue = _standardISOForNormalizedISO(restoredISODialValue)
      let exposureDuration = _exposureDurationForDialValue(restoredShutterDialValue)
      device.setExposureModeCustom(duration:exposureDuration, iso:isoValue) { (syncTime : CMTime) in
        let newISODialValue = self._normalizedISOForStandardISO(device.iso)
        dele.update(userISO:newISODialValue, forCameraController:self)
        let newShutterDialValue = self._dialValueForExposureDuration(device.exposureDuration)
        dele.update(userShutter:newShutterDialValue, forCameraController:self)
        do
        {
          try device.lockForConfiguration()
          defer { device.unlockForConfiguration() }
          device.setFocusModeLocked(lensPosition:restoredFocalDistanceSliderValue) { (syncTime : CMTime) in
            dele.update(userFocusPosition:device.lensPosition, forCameraController:self)
          }
        }
        catch
        {
          print("Error while restoring the saved lens position: \(error.localizedDescription)")
        }
      }
    }
    catch
    {
      print("Error while trying to restore user state: \(error.localizedDescription)")
    }
  }

}

extension MCCameraController : AVCaptureVideoDataOutputSampleBufferDelegate
{
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
  {
    if _testMode { return }
    guard let delegate_ = self.delegate else { return }
    guard delegate_.cameraControllerShouldPassVideoData(self) else { return }
    guard let samplingConnection = _cameraVideoOutput?.connection(with: .video) else { return }
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    samplingConnection.isEnabled = false
    delegate_.cameraController(self, hasNewVideoData: pixelBuffer) {
      samplingConnection.isEnabled = true
    }
  }
}

extension MCCameraController : AVCapturePhotoCaptureDelegate
{
  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?)
  {
    guard let imageData = photo.fileDataRepresentation() else { return }
    guard let image = UIImage(data:imageData) else { return }
    _imageCaptureHandler?(image)
  }
}
