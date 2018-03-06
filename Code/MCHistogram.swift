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

#if arch(arm64)
import AVFoundation
import Metal
#endif

private let numIntensityLevels = 256
private let computeTileCount = 64
private let kAlignment4K = 0x1000
private let kAlignment16K = 0x4000

private func pageAlignedBytes(forBytes bytes : Int) -> Int
{
  let alignment = kAlignment16K
  return ((bytes + alignment - 1) / alignment) * alignment
}

@discardableResult
private func pageAlign<T>(_ buffer : UnsafeMutablePointer<T>, size : Int) -> Int
{
#if true
  let p = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 1)
  p.initialize(to: buffer)
  return Int(posix_memalign(p, Int(getpagesize()), size))
#else
  let MetalBufferSizeAlignment : Int = 16384
  if size < MetalBufferSizeAlignment
  {
    return MetalBufferSizeAlignment
  }
  else if (size % MetalBufferSizeAlignment) > 0
  {
    return ((size / MetalBufferSizeAlignment) + 1) * MetalBufferSizeAlignment
  }
  return size
#endif
}

private func _allocatePageAligned<T>(_ bytes : Int) -> UnsafeMutablePointer<T>
{
  var p : UnsafeMutableRawPointer? = UnsafeMutableRawPointer.allocate(bytes: bytes, alignedTo: kAlignment4K)
  posix_memalign(&p, kAlignment4K, bytes)
  return p!.bindMemory(to: T.self, capacity: bytes / MemoryLayout<T>.size)
}


class MCHistogram : NSObject
{
  var enabled : Bool = true
  {
    didSet
    {
      if enabled
      {
        _renderLayer.isHidden = false
        _histogramCleared = false
        _willRenderClearedHistogram = false
      }
      else
      {
      #if arch(arm64)
        _clearHistogramData()
      #endif
        _histogramCleared = true
      }
    }
  }

#if arch(arm64)
  private let _histogramData : UnsafeMutablePointer<Float32>
  private let _histogramDataLength = pageAlignedBytes(forBytes: numIntensityLevels * MemoryLayout<Float32>.size)
  private let _histogramTileData : UnsafeMutablePointer<UInt32>
  private let _histogramTileDataLength = pageAlignedBytes(forBytes: computeTileCount * numIntensityLevels * MemoryLayout<UInt32>.size)
  private var _renderLayer : CAMetalLayer
  private var _currentDrawable : CAMetalDrawable?
  private var _commandQueue : MTLCommandQueue?
  private var _library : MTLLibrary?
  private var _GPUIsAvailableIndicator : DispatchSemaphore
  private var _computeState : MTLComputePipelineState?
  private var _renderState : MTLRenderPipelineState?
  private var _renderPassDescriptor : MTLRenderPassDescriptor?
  private var _vertexPositionBuffer : MTLBuffer?
  private var _vertexTextureCoordsBuffer : MTLBuffer?
  private var _vertexIndexBuffer : MTLBuffer?
  private var _fragmentHistogramDataBuffer : MTLBuffer?
#else
  private var _renderLayer = CALayer()
#endif
  private var _histogramCleared = false
  private var _willRenderClearedHistogram = false

  private let _waitForGPU = !MCRuntimeDebugOption(name:"HistogramShouldNotWaitForGPU")

#if arch(arm64)
  init(renderLayer:CAMetalLayer)
  {
    _renderLayer = renderLayer
    _renderLayer.isHidden = true
    _renderLayer.framebufferOnly = true
    _GPUIsAvailableIndicator = DispatchSemaphore(value: 1)
    _histogramData = _allocatePageAligned(_histogramDataLength)
    _histogramTileData = _allocatePageAligned(_histogramTileDataLength)
    let device = MTLCreateSystemDefaultDevice()
    _commandQueue = device?.makeCommandQueue()
    _library = _commandQueue?.device.makeDefaultLibrary()
    super.init()
    _computeState = _createComputeState()
    _renderState = _createRenderState()
    _renderPassDescriptor = _createRenderPass()
    _createRenderDataBuffers()
  }
#else
  init(renderLayer:CALayer)
  {
    super.init()
  }
#endif

#if arch(arm64)
  deinit
  {
    free(_histogramData)
    free(_histogramTileData)
  }

  func updateFromPixelData(_ pixelBuffer:CVPixelBuffer, completionHandler: @escaping ()->())
  {
    var didUpdate = false
    // Note: Apps that attempt to execute Metal commands in the background will be terminated.
    if UIApplication.shared.applicationState == .active
    {
      //let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
      let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
      let imageDataSize = CVPixelBufferGetBytesPerRow(pixelBuffer) * imageHeight
      CVPixelBufferLockBaseAddress(pixelBuffer, [])
      defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
      let imageDataPointer = CVPixelBufferGetBaseAddress(pixelBuffer)

      if _waitForGPU
      {
        _ = _GPUIsAvailableIndicator.wait(timeout: .distantFuture)
      }

      if enabled
      {
        if let computeCommands = _createComputeCommandsForImageData(imageDataPointer!, inputDataSize:Int(imageDataSize))
        {
          computeCommands.addCompletedHandler({ (commandBuffer:MTLCommandBuffer!) -> Void in
            if (commandBuffer.status == .error) && (commandBuffer.error != nil)
            {
              NSLog("Metal command buffer execution failed. \(commandBuffer.error!.localizedDescription)")
            }
            else
            {
              if self.enabled
              {
                self._mergeTilesAndNormalize()
              }
              else
              {
                self._clearHistogramData()
              }
            }
          })
          computeCommands.commit()
        }
      }

      if enabled || (_histogramCleared && !_willRenderClearedHistogram)
      {
        if let renderCommands = _createRenderCommands()
        {
          if _histogramCleared
          {
            _willRenderClearedHistogram = true
          }
          renderCommands.addCompletedHandler({ (commandBuffer:MTLCommandBuffer!) -> Void in
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
            if self._willRenderClearedHistogram
            {
              DispatchQueue.main.async(execute: { self._renderLayer.isHidden = !self.enabled } )
            }
            if self._waitForGPU
            {
              _ = self._GPUIsAvailableIndicator.signal()
            }
            completionHandler()
          })

        #if arch(arm64)
          renderCommands.present(_currentDrawable!)
        #endif
          renderCommands.commit()
          didUpdate = true
        }
      }
    }

    if !didUpdate
    {
      if _waitForGPU
      {
        _ = _GPUIsAvailableIndicator.signal()
      }
      completionHandler()
    }
  }
#endif

}

#if arch(arm64)
//MARK:- Histogram computing -

private extension MCHistogram
{
  func _createComputeState() -> MTLComputePipelineState?
  {
    var result : MTLComputePipelineState? = nil
    if let library = _library
    {
      if let computeFunction = library.makeFunction(name: "hist_processTile")
      {
        do
        {
          result = try _commandQueue?.device.makeComputePipelineState(function: computeFunction)
        }
        catch let computeError as NSError
        {
          NSLog("Could not create a compute pipeline. \(computeError.localizedDescription)")
        }
      }
      else
      {
        NSLog("Could not get the compute function from the Metal library.")
      }
    }
    return result
  }

  func _createComputeCommandsForImageData(_ inputDataPointer : UnsafeMutableRawPointer, inputDataSize : Int) -> MTLCommandBuffer?
  {
    guard let commandQueue = _commandQueue else { return nil }

    guard let inputBuffer = commandQueue.device.makeBuffer(bytesNoCopy: inputDataPointer, length:pageAlignedBytes(forBytes:inputDataSize), options:[], deallocator:nil) else { return nil }
    inputBuffer.label = "ImageDataBuffer"

    guard let outputBuffer = commandQueue.device.makeBuffer(bytesNoCopy: _histogramTileData, length:_histogramTileDataLength, options:[], deallocator:nil) else { return nil }
    outputBuffer.label = "HistogramTilesDataBuffer"

    guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
    commandBuffer.label = "HistogramCommandBuffer"

    if let tileProcessingState = _computeState
    {
      // The input image data is partitioned into 16 tiles, where each Metal thread group works on one tile.
      let threadgroupsPerComputationGrid = MTLSizeMake(computeTileCount, 1, 1)
      // Each partition is again subpartitioned such that threads of a thread group can work on them.
      let threadgroupSize = MTLSizeMake(1/*tileProcessingState.threadExecutionWidth*/, 1, 1) // threadExecutionWidth = execution width of a single compute unit in the GPU

      let numPixelsProcessedPerThread = UInt32(inputDataSize / 4 / threadgroupsPerComputationGrid.width / threadgroupSize.width)
      guard let numPixelsBuffer = commandQueue.device.makeBuffer(length: 4, options:[]) else { return nil }
      numPixelsBuffer.contents().initializeMemory(as: UInt32.self, to: numPixelsProcessedPerThread)

      if let tileProcessingCE = commandBuffer.makeComputeCommandEncoder()
      {
        tileProcessingCE.label = "Histogram Tile Processing Command Encoder"
        tileProcessingCE.pushDebugGroup("Histogram Tile Processing")
        tileProcessingCE.setComputePipelineState(tileProcessingState)
        tileProcessingCE.setBuffer(inputBuffer, offset:0, index:0)
        tileProcessingCE.setBuffer(outputBuffer, offset:0, index:1)
        tileProcessingCE.setBuffer(numPixelsBuffer, offset:0, index:2) // the number pixel to be processed by a thread
        //tileProcessingCE.setThreadgroupMemoryLength(numIntensityLevels, atIndex:0) // must be less than 16 KB (= 16384)

        tileProcessingCE.dispatchThreadgroups(threadgroupsPerComputationGrid, threadsPerThreadgroup:threadgroupSize)
        tileProcessingCE.endEncoding()
        tileProcessingCE.popDebugGroup()
      }
    }

    return commandBuffer
  }

  func _mergeTilesAndNormalize()
  {
    var maxPixelCount : UInt32 = 0

    for k in 0..<numIntensityLevels
    {
      var numPixelsAtIntensityLevel : UInt32 = 0
      for j in 0..<computeTileCount
      {
        numPixelsAtIntensityLevel += _histogramTileData[(j * numIntensityLevels) + k]/UInt32(computeTileCount)
      }
      _histogramData[k] = Float32(numPixelsAtIntensityLevel)
      if numPixelsAtIntensityLevel > maxPixelCount
      {
        maxPixelCount = numPixelsAtIntensityLevel
      }
    }

    for k in 0..<numIntensityLevels
    {
      _histogramData[k] /= Float32(maxPixelCount)
      //print("\(histogramData[k]) : ")
    }
  }

  func _clearHistogramData()
  {
    for i in 0..<numIntensityLevels
    {
      _histogramData[i] = 0.0
    }
  }

  //MARK: Histogram rendering

  func _createRenderState() -> MTLRenderPipelineState?
  {
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = _library?.makeFunction(name: "hist_vertex")
    pipelineDescriptor.fragmentFunction = _library?.makeFunction(name: "hist_fragment")
    pipelineDescriptor.vertexDescriptor = _createVertexDescriptor()
    let ca = pipelineDescriptor.colorAttachments[0]
    ca?.pixelFormat = .bgra8Unorm
    ca?.isBlendingEnabled = true
    ca?.alphaBlendOperation = .add // the clear color becomes the background color of the histogram
    ca?.sourceRGBBlendFactor = .one
    ca?.sourceAlphaBlendFactor = .one
    ca?.destinationRGBBlendFactor = .one
    ca?.destinationAlphaBlendFactor = .one

    var result : MTLRenderPipelineState?
    if let commandQueue = _commandQueue
    {
      do { result = try commandQueue.device.makeRenderPipelineState(descriptor: pipelineDescriptor) }
      catch let error as NSError
      {
        NSLog(error.localizedDescription)
      }
    }
    return result
  }

  func _createRenderPass() -> MTLRenderPassDescriptor
  {
    let result = MTLRenderPassDescriptor()
    let ca = result.colorAttachments[0]
    ca?.loadAction = .clear
    ca?.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.3)
    ca?.storeAction = .store
    return result
  }

  func _createRenderDataBuffers()
  {
    guard let device = _commandQueue?.device else { return }

    var vertexPositions : [Float32] = [ // the corners of the normalized view volume
      -1.0, -1.0, 0.5, 1.0,
       1.0, -1.0, 0.5, 1.0,
      -1.0,  1.0, 0.5, 1.0,
       1.0,  1.0, 0.5, 1.0
    ]
    _vertexPositionBuffer = device.makeBuffer(bytes: &vertexPositions, length:vertexPositions.count * MemoryLayout<Float32>.size, options:[])

    var textureCoords : [Float32] = [
      0.0, 0.0,
      1.0, 0.0,
      0.0, 1.0,
      1.0, 1.0
    ]
    _vertexTextureCoordsBuffer = device.makeBuffer(bytes: &textureCoords, length:textureCoords.count * MemoryLayout<Float32>.size, options:[])

    var indices : [UInt16] = [ 0, 1, 2, 2, 1, 3 ]
    _vertexIndexBuffer = device.makeBuffer(bytes: &indices, length:indices.count * MemoryLayout<UInt16>.size, options:[])

    _fragmentHistogramDataBuffer = device.makeBuffer(bytesNoCopy: _histogramData, length:_histogramDataLength, options:[], deallocator:nil)
  }

  func _createVertexDescriptor() -> MTLVertexDescriptor
  {
    let vertexDesc = MTLVertexDescriptor()

    let positionAttribute = vertexDesc.attributes[0]
    positionAttribute?.bufferIndex = 0
    positionAttribute?.format = .float4
    positionAttribute?.offset = 0
    let positionDataLayout = vertexDesc.layouts[0]
    positionDataLayout?.stepFunction = .perVertex
    positionDataLayout?.stride = 4 * MemoryLayout<Float>.size

    let textureCoordinateAttribute = vertexDesc.attributes[1]
    textureCoordinateAttribute?.bufferIndex = 1
    textureCoordinateAttribute?.format = .float2
    textureCoordinateAttribute?.offset = 0
    let texCoordDataLayout = vertexDesc.layouts[1]
    texCoordDataLayout?.stepFunction = .perVertex
    texCoordDataLayout?.stride = 2 * MemoryLayout<Float>.size

    return vertexDesc
  }

  func _createRenderCommands() -> MTLCommandBuffer?
  {
    guard let commandBuffer = _commandQueue?.makeCommandBuffer() else { return nil }
    guard let renderState = _renderState else { return nil }
    guard let renderPass = _renderPassDescriptor else { return nil }
    _currentDrawable = _renderLayer.nextDrawable()
    renderPass.colorAttachments[0].texture = _currentDrawable?.texture
    guard let renderCE = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return nil }
    renderCE.setRenderPipelineState(renderState)
    renderCE.setVertexBuffer(_vertexPositionBuffer, offset:0, index:0)
    renderCE.setVertexBuffer(_vertexTextureCoordsBuffer, offset:0, index:1)
    renderCE.setFragmentBuffer(_fragmentHistogramDataBuffer, offset:0, index:0)
    renderCE.drawIndexedPrimitives(type:.triangle, indexCount:6, indexType:.uint16, indexBuffer:_vertexIndexBuffer!, indexBufferOffset:0)
    renderCE.endEncoding()
    return commandBuffer
  }
}

#endif // arch(arm64)

//MARK: -

class MCHistogramView : UIView
{
#if arch(arm64)
  override class var layerClass : AnyClass
  {
    return CAMetalLayer.self
  }
#endif
}


