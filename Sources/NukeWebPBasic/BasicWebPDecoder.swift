import libwebp
import NukeWebP
import Foundation

#if !os(macOS)
import UIKit.UIImage
#else
import AppKit.NSImage
#endif

public final class BasicWebPDecoder: WebPDecoding {
  
  public init() { }
  
  public func decode(data: Data) throws -> ImageType {
    let image = try decodeiCGImage(data: data)

    #if !os(macOS)
    return UIImage(cgImage: image)
    #else
    return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    #endif
  }
  
  public func decodei(data: Data) throws -> ImageType {
    let image = try decodeiCGImage(data: data)
    
    #if !os(macOS)
    return UIImage(cgImage: image)
    #else
    return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    #endif
  }
  
  private func decodeiCGImage(data webPData: Data) throws -> CGImage {
    var mutableWebPData = webPData
    return try mutableWebPData.withUnsafeMutableBytes { rawPtr in
      guard let bindedBasePtr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        throw WebPDecodingError.unknownError
      }
      
      let idec = WebPINewRGB(MODE_rgbA, nil, 0, 0)
      
      let status = WebPIUpdate(idec, bindedBasePtr, webPData.count)
      if status != VP8_STATUS_OK && status != VP8_STATUS_SUSPENDED {
        throw WebPDecodingError.unknownError
      }
      var width: Int32 = 0
      var height: Int32 = 0
      var last_y: Int32 = 0
      var stride: Int32 = 0
      if let rgba = WebPIDecGetRGB(idec, &last_y, &width, &height, &stride) {
        
        if (0 < width + height && 0 < last_y && last_y <= height) {
          let rgbaSize = last_y * stride;
          
          let data = Data(
            bytesNoCopy: rgba,
            count: Int(rgbaSize),
            deallocator: .free
          )
          
          guard let provider = CGDataProvider(data: data as CFData) else {
            throw WebPDecodingError.unknownError
          }
          let colorSpaceRef = CGColorSpaceCreateDeviceRGB()
          let pixelLength: Int = 4
          
          let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
          
          if let image = CGImage(
            width: Int(width),
            height: Int(last_y),
            bitsPerComponent: 8,
            bitsPerPixel: pixelLength * 8,
            bytesPerRow: pixelLength * Int(width),
            space: colorSpaceRef,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: CGColorRenderingIntent.defaultIntent
          ) {
            
            let canvasColorSpaceRef = CGColorSpaceCreateDeviceRGB()
            if let canvas = CGContext(
              data: nil,
              width: Int(width),
              height: Int(height),
              bitsPerComponent: 8,
              bytesPerRow: 0,
              space: canvasColorSpaceRef,
              bitmapInfo: bitmapInfo.rawValue
            ) {
              canvas.draw(
                image,
                in: .init(
                  x: 0,
                  y: Int(height) - Int(last_y),
                  width: Int(width),
                  height: Int(last_y)
                )
              )
              if let newImageRef = canvas.makeImage() {
                return newImageRef
              }
            }
          }
        }
      }
      throw WebPDecodingError.unknownError
    }
  }
  
  private func decodeCGImage(data webPData: Data) throws -> CGImage {
    var mutableWebPData = webPData
    
    return try mutableWebPData.withUnsafeMutableBytes { rawPtr in
      
      guard let bindedBasePtr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        throw WebPDecodingError.unknownError
      }
      
      var features: libwebp.WebPBitstreamFeatures = .init()
      if WebPGetFeatures(bindedBasePtr, webPData.count, &features) != VP8_STATUS_OK {
        throw WebPDecodingError.unknownError
      }
      
      var width: Int32 = 0
      var height: Int32 = 0
      let pixelLength: Int32
      
      let decoded: UnsafeMutablePointer<UInt8>
      if (features.has_alpha != 0) {
        pixelLength = 4
        guard let _decoded = WebPDecodeRGBA(bindedBasePtr, webPData.count, &width, &height) else {
          throw WebPDecodingError.unknownError
        }
        decoded = _decoded
      } else {
        pixelLength = 3
        guard let _decoded = WebPDecodeRGB(bindedBasePtr, webPData.count, &width, &height) else {
          throw WebPDecodingError.unknownError
        }
        decoded = _decoded
      }
      let data = Data(
        bytesNoCopy: decoded,
        count: Int(width * height * pixelLength),
        deallocator: .free
      )
      
      guard let provider = CGDataProvider(data: data as CFData) else {
        throw WebPDecodingError.unknownError
      }
      
      let colorSpaceRef = CGColorSpaceCreateDeviceRGB()
      if let image = CGImage(
        width: Int(width),
        height: Int(height),
        bitsPerComponent: 8,
        bitsPerPixel: Int(pixelLength) * 8,
        bytesPerRow: Int(pixelLength) * Int(width),
        space: colorSpaceRef,
        bitmapInfo: .init(rawValue: UInt32(0)),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: CGColorRenderingIntent.defaultIntent
      ) {
        return image
      }
      throw WebPDecodingError.unknownError
    }
  }
}
