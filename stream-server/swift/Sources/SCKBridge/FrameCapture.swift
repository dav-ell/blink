// FrameCapture - Advanced frame capture utilities
// Provides encoding and frame processing helpers

import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import VideoToolbox

/// Frame capture and encoding utilities
@available(macOS 12.3, *)
public enum FrameCapture {
    
    /// Encode a pixel buffer to H264
    public static func encodeToH264(
        pixelBuffer: CVPixelBuffer,
        session: VTCompressionSession,
        timestamp: CMTime,
        duration: CMTime
    ) -> Data? {
        var flags: VTEncodeInfoFlags = []
        var encodedData: Data?
        
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: duration,
            frameProperties: nil,
            infoFlagsOut: &flags,
            outputHandler: { status, flags, sampleBuffer in
                guard status == noErr, let sampleBuffer = sampleBuffer else {
                    return
                }
                
                // Extract NAL units from sample buffer
                if let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                    var length: Int = 0
                    var dataPointer: UnsafeMutablePointer<Int8>?
                    
                    CMBlockBufferGetDataPointer(
                        dataBuffer,
                        atOffset: 0,
                        lengthAtOffsetOut: nil,
                        totalLengthOut: &length,
                        dataPointerOut: &dataPointer
                    )
                    
                    if let dataPointer = dataPointer {
                        encodedData = Data(bytes: dataPointer, count: length)
                    }
                }
            }
        )
        
        guard status == noErr else {
            return nil
        }
        
        return encodedData
    }
    
    /// Create an H264 compression session
    public static func createEncoderSession(
        width: Int,
        height: Int,
        bitrate: Int = 5_000_000, // 5 Mbps
        frameRate: Int = 60
    ) -> VTCompressionSession? {
        var session: VTCompressionSession?
        
        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        
        guard status == noErr, let session = session else {
            return nil
        }
        
        // Configure session
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: frameRate as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: (frameRate * 2) as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        
        VTCompressionSessionPrepareToEncodeFrames(session)
        
        return session
    }
}
