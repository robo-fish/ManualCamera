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
import Metal

let MCPI = CGFloat.pi
let MCPI2 = 2.0 * MCPI
let MCPI1_5 = 1.5 * MCPI

@IBDesignable class MCDialControl : UIView
{
  @IBInspectable var tickCount : Int
  {
    didSet { _dialLayer?.tickCount = tickCount }
  }

  @IBInspectable var tickColor : UIColor
  {
    didSet { _dialLayer?.tickColor = tickColor.cgColor }
  }

#if arch(arm64)
  @IBInspectable var increasesClockwise : Bool = true
  {
    didSet { _backgroundLayer?.clockwiseFadingGradient = false }
  }
#else
  var increasesClockwise = true
#endif

  @IBInspectable var gradientOffset : CGFloat = 0.0
  {
    didSet { _updateLayerTransforms() }
  }

  // :param: udpateDial whether the dial should be updated after the action has been handled.
  var dialAction : (Float, _ updateDial:Bool)->() = { (Float, Bool) in  }

  var dialValue : Float
  {
    set
    {
      _dialValue = newValue;
      _layerRotation = _layerRotationForDialValue(_dialValue)
      _updateLayerTransforms()
    }
    get { return _dialValue }
  }

  private var _dialValue : Float = 0.0
  private var _dialLayer : MCDialShapeLayer?
#if arch(arm64)
  private var _backgroundLayer : MCDialBackgroundLayer?
#else
  private var _backgroundLayer : CALayer?
#endif
  private var _layerRotation : CGFloat = 0.0
  private var _turnStartLocation : CGPoint = CGPoint.zero
  private var _isTurning = false
  private var _turnGestureStartTouchAngle : CGFloat = 0.0
  private var _turnGestureStartValue : Float = 0.0
  private var _turnGestureStartLayerRotation : CGFloat = 0.0

  override func layoutSubviews()
  {
    super.layoutSubviews()
    self.isOpaque = false
    _createSublayers()
    _updateLayerTransforms()
    _setUpTouchHandling()
  }

  override init(frame: CGRect)
  {
    _dialValue = 0.0
    tickCount = 92
    tickColor = UIColor(white:0.3, alpha:1.0)
    super.init(frame:frame)
  }

  required init?(coder decoder: NSCoder)
  {
    _dialValue = decoder.containsValue(forKey: "value") ? decoder.decodeFloat(forKey: "value") : 0.0
    tickCount = decoder.containsValue(forKey: "tickCount") ? decoder.decodeInteger(forKey: "tickCount") : 90
    tickColor = decoder.containsValue(forKey: "tickColor") ? decoder.decodeObject(forKey: "tickColor") as! UIColor : UIColor(white:0.3, alpha:1.0)
    super.init(coder:decoder)
  }

  override func encode(with coder: NSCoder)
  {
    super.encode(with: coder)
    coder.encode(dialValue, forKey:"value")
    coder.encode(tickCount, forKey:"tickCount")
    coder.encode(tickColor, forKey:"tickColor")
  }

  override func didMoveToWindow()
  {
    self.contentScaleFactor = self.window!.screen.nativeScale
  }

  //MARK: Action handlers

  @objc func handlePanGesture(_ recognizer:UIPanGestureRecognizer)
  {
    switch recognizer.state
    {
      case .began :
        _turnGestureStartLayerRotation = _layerRotation
        _turnGestureStartTouchAngle = _angleForLocation(recognizer.location(in: self))
        _turnGestureStartValue = dialValue
      case .ended : fallthrough
      case .cancelled : fallthrough
      case .changed :
        let touchAngle = _angleForLocation(recognizer.location(in: self))
        let diffAngle = touchAngle - _turnGestureStartTouchAngle
        var newRotation = _turnGestureStartLayerRotation + diffAngle
        newRotation = min(max(newRotation,0), MCPI1_5)
        _layerRotation = newRotation
        _updateLayerTransforms()
        _dialValue = _dialValueForLayerRotation(newRotation)
        dialAction(_dialValue, recognizer.state != .changed)
      default: break
    }
  }

  //MARK: Private

  private func _angleForLocation(_ location : CGPoint) -> CGFloat
  {
    let size = self.bounds.size
    let dx = location.x - size.width/2.0
    let dy = location.y - size.height/2.0
    var angle = acos(dx/sqrt(dy*dy + dx*dx)) // returns angle between 0 and PI
    if (dx < 0.0) && (dy < 0.0)
    {
      angle += 2.0 * (MCPI - angle)
    }
    else if (dx >= 0.0) && (dy < 0.0)
    {
      angle = MCPI2 - angle
    }
    return angle
  }

  private func _createSublayers()
  {
    if _backgroundLayer == nil
    {
    #if arch(arm64)
      let backgroundLayer = MCDialBackgroundLayer()
    #else
      let backgroundLayer = CALayer()
    #endif
      self.layer.addSublayer(backgroundLayer)
      backgroundLayer.frame = self.bounds
      backgroundLayer.isOpaque = false
      backgroundLayer.actions = ["transform":NSNull()] // disabling implicit transformation animation
    #if arch(arm64)
      backgroundLayer.setUp()
      backgroundLayer.clockwiseFadingGradient = !increasesClockwise
    #endif
      _backgroundLayer = backgroundLayer
    }

    if _dialLayer == nil
    {
      let shapeLayer = MCDialShapeLayer(tickCount:tickCount)
      shapeLayer.frame = self.bounds
      shapeLayer.tickCount = tickCount
      shapeLayer.tickColor = tickColor.cgColor
      shapeLayer.isOpaque = false
      shapeLayer.actions = ["transform":NSNull()] // disabling implicit transformation animation
      self.layer.addSublayer(shapeLayer)
      shapeLayer.transform = CATransform3DMakeRotation(CGFloat(dialValue) * MCPI2, 0, 0, 1.0)
      _dialLayer = shapeLayer
    }
  }

  private func _setUpTouchHandling()
  {
    isExclusiveTouch = true
    let dragRecognizer = UIPanGestureRecognizer(target:self, action:#selector(MCDialControl.handlePanGesture(_:)))
    dragRecognizer.maximumNumberOfTouches = 1
    addGestureRecognizer(dragRecognizer)
  }

  private func _updateLayerTransforms()
  {
    _dialLayer?.transform = CATransform3DMakeRotation(_layerRotation, 0, 0, 1)
    _backgroundLayer?.transform = CATransform3DMakeRotation(_layerRotation + gradientOffset*MCPI/180.0, 0, 0, 1)
  }

  private func _dialValueForLayerRotation(_ rotation : CGFloat) -> Float
  {
    var value : Float = 0.0
    if rotation >= MCPI1_5
    {
      value = 1.0
    }
    else if rotation > 0
    {
      value = Float(rotation / MCPI1_5)
    }
    return increasesClockwise ? value : (1.0 - value)
  }

  private func _layerRotationForDialValue(_ value : Float) -> CGFloat
  {
    let val = CGFloat(max(min(value, 1.0), 0.0))
    let rot = val * MCPI1_5
    return (increasesClockwise ? rot : (MCPI1_5 - rot))
  }
}

//MARK:-

private class MCDialShapeLayer : CAShapeLayer
{
  var tickColor : CGColor?
  {
    didSet
    {
      self.strokeColor = tickColor
      setNeedsDisplay()
    }
  }

  var tickCount : Int = 92
  {
    didSet { _updateShape() }
  }

  init(tickCount : Int)
  {
    self.tickCount = tickCount
    super.init()
    _updateShape()
  }

  required init?(coder decoder: NSCoder)
  {
    super.init(coder:decoder)
  }

  private func _updateShape()
  {
    let size = self.bounds.size
    let innerRadiusFactor : CGFloat = 0.35
    let outerRadiusFactor : CGFloat = 0.50
    let shortInnerRadiusFactor : CGFloat = 0.30
    let path = CGMutablePath()
    let minDimension = min(size.width, size.height)
    let innerRadius = minDimension * innerRadiusFactor
    let shortInnerRadius = minDimension * shortInnerRadiusFactor
    let outerRadius = minDimension * outerRadiusFactor
    let centerX = size.width/2.0
    let centerY = size.height/2.0
    let angularStep = MCPI2/CGFloat(tickCount)
    for j in 0...(tickCount-1)
    {
      let i = CGFloat(j)
      let angle = angularStep*i
      let startRadius = ((j % (tickCount/4)) == 0) ? shortInnerRadius : innerRadius
      let x_start = centerX + startRadius * cos(angle)
      let y_start = centerY + startRadius * sin(angle)
      let x_end = centerX + outerRadius * cos(angle)
      let y_end = centerY + outerRadius * sin(angle)
      path.move(to: CGPoint(x: x_start, y: y_start))
      path.addLine(to : CGPoint(x: x_end, y: y_end))
    }
    path.addEllipse(in: bounds)
    path.addEllipse(in: CGRect(x: size.width*(outerRadiusFactor - innerRadiusFactor), y: size.height*(outerRadiusFactor - innerRadiusFactor), width: size.width * 2.0 * innerRadiusFactor, height: size.height * 2.0 * innerRadiusFactor))
    self.path = path
    self.strokeColor = tickColor
    self.fillColor = nil
    self.lineWidth = 2.0
  }
}

//MARK:-

#if arch(arm64)

private class MCDialBackgroundLayer : CAMetalLayer
{
  var clockwiseFadingGradient : Bool = false { didSet { _updateGradientDirectionBuffer(); _render() } }

  private var _metalDevice : MTLDevice? = MTLCreateSystemDefaultDevice()
  private var _metalQueue : MTLCommandQueue?
  private var _renderPassDesc : MTLRenderPassDescriptor?
  private var _state : MTLRenderPipelineState?
  private var _library : MTLLibrary?
  private var _vertexBuffer : MTLBuffer?
  private var _indexBuffer : MTLBuffer?
  private var _texCoordBuffer : MTLBuffer?
  private var _gradientDirectionBuffer : MTLBuffer?
  private var _concurrentRenderingBlocker = DispatchSemaphore(value: 1)
  private var _didRender = false

  func setUp()
  {
    guard let metalDevice = _metalDevice else { return }
    guard let queue = metalDevice.makeCommandQueue() else { return }
    _metalQueue = queue
    self.device = metalDevice
    self.pixelFormat = .bgra8Unorm
    self.framebufferOnly = true

    let renderPass = MTLRenderPassDescriptor()
    let colorAttachment = renderPass.colorAttachments[0]
    colorAttachment?.loadAction = .clear
    colorAttachment?.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
    colorAttachment?.storeAction = .store
    _renderPassDesc = renderPass

    _library = metalDevice.makeDefaultLibrary()
    do
    {
      _state = try metalDevice.makeRenderPipelineState(descriptor: _createPipelineDescriptor())
    }
    catch let metalError as NSError
    {
      NSLog("\(metalError.localizedDescription)")
    }

    var indices : [UInt16] = [ 0, 1, 2, 1, 2, 3 ]
    _indexBuffer = metalDevice.makeBuffer(bytes: &indices, length:indices.count * MemoryLayout<UInt16>.size)

    _gradientDirectionBuffer = metalDevice.makeBuffer(length: MemoryLayout<Bool>.size)
    _updateGradientDirectionBuffer()
  }

  private func _render()
  {
    guard let renderPass = _renderPassDesc else { return }
    _ = _concurrentRenderingBlocker.wait(timeout: DispatchTime.distantFuture)

    guard let commandBuffer = _metalQueue?.makeCommandBuffer() else { return }
    commandBuffer.label = "gradient rendering commands"

    guard let drawable = self.nextDrawable() else { NSLog("Could not create a Metal drawable area."); return }
    renderPass.colorAttachments[0].texture = drawable.texture

    guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
    renderEncoder.pushDebugGroup("encode quad")
    renderEncoder.setCullMode(.none)
    let size = self.bounds.size
    renderEncoder.setViewport(MTLViewport(originX:0.0, originY:0.0, width:Double(size.width), height:Double(size.height), znear:1.0, zfar:0.0))
    renderEncoder.setRenderPipelineState(_state!)
    assert(_vertexBuffer != nil)
    renderEncoder.setVertexBuffer(_vertexBuffer, offset:0, index:0)
    assert(_texCoordBuffer != nil)
    renderEncoder.setVertexBuffer(_texCoordBuffer, offset:0, index:1)
    assert(_gradientDirectionBuffer != nil)
    renderEncoder.setFragmentBuffer(_gradientDirectionBuffer, offset:0, index:0)
    assert(_indexBuffer != nil)
    renderEncoder.drawIndexedPrimitives(type:.triangle, indexCount:6, indexType:.uint16, indexBuffer:_indexBuffer!, indexBufferOffset:0)
    renderEncoder.endEncoding()
    renderEncoder.popDebugGroup()

    commandBuffer.addCompletedHandler{ (buffer:MTLCommandBuffer!)->() in
      self._didRender = true
      self._concurrentRenderingBlocker.signal()
    }

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  private func _createPipelineDescriptor() -> MTLRenderPipelineDescriptor
  {
    let pipelineDesc = MTLRenderPipelineDescriptor()
    pipelineDesc.label = "Hello World pipeline"
    pipelineDesc.isRasterizationEnabled = true
    pipelineDesc.vertexFunction = _library?.makeFunction(name: "basic_vs")
    assert(pipelineDesc.vertexFunction != nil)
    pipelineDesc.fragmentFunction = _library?.makeFunction(name: "dial_gradient")
    assert(pipelineDesc.fragmentFunction != nil)
    let colorAttachment = pipelineDesc.colorAttachments[0]
    colorAttachment?.pixelFormat = .bgra8Unorm
    colorAttachment?.isBlendingEnabled = true
    colorAttachment?.alphaBlendOperation = .add
    colorAttachment?.sourceRGBBlendFactor = .one
    colorAttachment?.sourceAlphaBlendFactor = .one
    colorAttachment?.destinationRGBBlendFactor = .zero
    colorAttachment?.destinationAlphaBlendFactor = .zero

    pipelineDesc.vertexDescriptor = _createVertexDescriptor()
    return pipelineDesc
  }

  private func _createVertexDescriptor() -> MTLVertexDescriptor
  {
    let vertexDesc = MTLVertexDescriptor()

    // The normalized view volume in Metal is ([-1,1], [-1,1], [0,1]).
    // The vertex positions are expressed in homogeneous coordinates (with a perspective projection component).
    var vertexPositions : [Float32] = [
      -1.0, -1.0, 0.5, 1.0,
      1.0, -1.0, 0.5, 1.0,
      -1.0,  1.0, 0.5, 1.0,
      1.0,  1.0, 0.5, 1.0
    ]
    _vertexBuffer = _metalDevice?.makeBuffer(bytes: &vertexPositions, length:vertexPositions.count * MemoryLayout<Float32>.size, options:MTLResourceOptions())

    let positionAttribute = vertexDesc.attributes[0]
    positionAttribute?.bufferIndex = 0
    positionAttribute?.format = .float4
    positionAttribute?.offset = 0
    let positionDataLayout = vertexDesc.layouts[0]
    positionDataLayout?.stepFunction = .perVertex
    positionDataLayout?.stride = 4 * MemoryLayout<Float>.size

    var textureCoordinates : [Float32] = [
      0.0, 0.0,
      1.0, 0.0,
      0.0, 1.0,
      1.0, 1.0
    ]
    _texCoordBuffer = _metalDevice?.makeBuffer(bytes: &textureCoordinates, length:textureCoordinates.count * MemoryLayout<Float32>.size, options:MTLResourceOptions())

    let textureCoordinateAttribute = vertexDesc.attributes[1]
    textureCoordinateAttribute?.bufferIndex = 1
    textureCoordinateAttribute?.format = .float2
    textureCoordinateAttribute?.offset = 0
    let texCoordDataLayout = vertexDesc.layouts[1]
    texCoordDataLayout?.stepFunction = .perVertex
    texCoordDataLayout?.stride = 2 * MemoryLayout<Float>.size

    return vertexDesc
  }

  private func _updateGradientDirectionBuffer()
  {
    if let buffer = _gradientDirectionBuffer
    {
      buffer.contents().initializeMemory(as: Bool.self, to: clockwiseFadingGradient)
    }
  }

  private func _textureFromUIImageNamed(_ name : String) -> MTLTexture?
  {
    guard let image = UIImage(named:name) else { return nil }
    guard let cgImage = image.cgImage else { return nil }
    let width = Int(image.size.width)
    let height = Int(image.size.height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.last.rawValue)
    bitmapContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
    let rawData = bitmapContext?.data
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width:width, height:height, mipmapped:true)
    guard let result = _metalDevice?.makeTexture(descriptor: textureDescriptor) else { return nil }
    result.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel:0, withBytes:rawData!, bytesPerRow:4 * width)
    return result
  }
}

#endif // arch(arm64)
