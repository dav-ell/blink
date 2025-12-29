// H264Encoder - Hardware H.264 encoding via VideoToolbox
// Encodes CVPixelBuffer frames to H.264 NAL units for WebRTC streaming

import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo

/// Callback for receiving encoded NAL units
public typealias EncodedFrameCallback = (
    _ windowId: UInt32,
    _ timestampMs: UInt64,
    _ isKeyframe: Bool,
    _ nalData: Data,
    _ width: Int,
    _ height: Int
) -> Void

/// H.264 encoder using VideoToolbox hardware acceleration
@available(macOS 12.3, *)
public class H264Encoder {
    
    private var compressionSession: VTCompressionSession?
    private let windowId: UInt32
    private let width: Int
    private let height: Int
    private var frameCallback: EncodedFrameCallback?
    private var frameCount: UInt64 = 0
    private let encoderQueue = DispatchQueue(label: "h264encoder", qos: .userInteractive)
    
    /// SPS and PPS NAL units (needed for decoder initialization)
    private var sps: Data?
    private var pps: Data?
    
    public init(windowId: UInt32, width: Int, height: Int) {
        self.windowId = windowId
        self.width = width
        self.height = height
    }
    
    deinit {
        stop()
    }
    
    /// Start the encoder
    public func start(callback: @escaping EncodedFrameCallback) -> Bool {
        self.frameCallback = callback
        
        // Encoder output callback
        let outputCallback: VTCompressionOutputCallback = { (
            outputCallbackRefCon,
            sourceFrameRefCon,
            status,
            infoFlags,
            sampleBuffer
        ) in
            guard let refCon = outputCallbackRefCon else { return }
            let encoder = Unmanaged<H264Encoder>.fromOpaque(refCon).takeUnretainedValue()
            encoder.handleEncodedFrame(status: status, sampleBuffer: sampleBuffer)
        }
        
        // Create compression session
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: outputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &compressionSession
        )
        
        guard status == noErr, let session = compressionSession else {
            print("Failed to create compression session: \(status)")
            return false
        }
        
        // Configure for real-time streaming
        configureSession(session)
        
        // Prepare to encode
        VTCompressionSessionPrepareToEncodeFrames(session)
        
        print("H264Encoder started for window \(windowId) at \(width)x\(height)")
        return true
    }
    
    private func configureSession(_ session: VTCompressionSession) {
        // Real-time encoding for low latency
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        
        // Profile: Baseline for maximum compatibility
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, 
                           value: kVTProfileLevel_H264_Baseline_AutoLevel)
        
        // Bitrate: 4 Mbps (adjust based on resolution)
        let bitrate = min(width * height * 4, 8_000_000) // Cap at 8 Mbps
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, 
                           value: bitrate as CFNumber)
        
        // Data rate limits for more consistent streaming
        let byteLimit = Double(bitrate) / 8.0
        let secondLimit = 1.0
        let dataRateLimits = [byteLimit, secondLimit] as CFArray
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_DataRateLimits, 
                           value: dataRateLimits)
        
        // Frame rate
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, 
                           value: 30 as CFNumber)
        
        // Keyframe interval: every 2 seconds at 30fps = 60 frames
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, 
                           value: 60 as CFNumber)
        
        // No B-frames for lower latency
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, 
                           value: kCFBooleanFalse)
        
        // Allow temporal compression
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowTemporalCompression, 
                           value: kCFBooleanTrue)
        
        // Hardware acceleration
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder, 
                           value: kCFBooleanTrue)
    }
    
    /// Stop the encoder
    public func stop() {
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        frameCallback = nil
        print("H264Encoder stopped for window \(windowId)")
    }
    
    /// Encode a frame
    public func encode(pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard let session = compressionSession else {
            print("H264Encoder: No compression session")
            return
        }
        
        let duration = CMTime(value: 1, timescale: 30) // Assume 30fps
        
        // Check if we need to force a keyframe
        var frameProperties: CFDictionary? = nil
        if forceNextKeyframe {
            frameProperties = [kVTEncodeFrameOptionKey_ForceKeyFrame: true] as CFDictionary
            forceNextKeyframe = false
            print("H264Encoder: Forcing keyframe for window \(windowId)")
        }
        
        var flags: VTEncodeInfoFlags = []
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: duration,
            frameProperties: frameProperties,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )
        
        if status != noErr {
            print("H264Encoder: Encode frame failed: \(status)")
        }
        
        frameCount += 1
        
        // Log every 30 frames
        if frameCount % 30 == 1 {
            print("H264Encoder: Encoding frame #\(frameCount) for window \(windowId)")
        }
    }
    
    /// Request a keyframe on the next encode
    public func requestKeyframe() {
        guard let session = compressionSession else { return }
        
        let properties: [CFString: Any] = [
            kVTEncodeFrameOptionKey_ForceKeyFrame: true
        ]
        
        // This will be applied on the next encode call
        print("H264Encoder: Keyframe requested for window \(windowId)")
        forceNextKeyframe = true
    }
    
    private var forceNextKeyframe = true  // Force keyframe on first frame
    
    /// Handle encoded frame output
    private func handleEncodedFrame(status: OSStatus, sampleBuffer: CMSampleBuffer?) {
        guard status == noErr else {
            print("H264Encoder: Encoding error: \(status)")
            return
        }
        
        guard let sampleBuffer = sampleBuffer,
              CMSampleBufferDataIsReady(sampleBuffer) else {
            print("H264Encoder: Sample buffer not ready")
            return
        }
        
        // Check if this is a keyframe
        let isKeyframe = isKeyFrame(sampleBuffer)
        
        // Get timestamp
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampMs = UInt64(CMTimeGetSeconds(pts) * 1000)
        
        // Extract NAL units with Annex-B start codes for WebRTC
        guard let nalData = extractNALUnitsAnnexB(from: sampleBuffer, isKeyframe: isKeyframe) else {
            print("H264Encoder: Failed to extract NAL units")
            return
        }
        
        // Log every 30 frames
        if frameCount % 30 == 0 {
            print("H264Encoder: Encoded frame #\(frameCount) for window \(windowId), size=\(nalData.count), keyframe=\(isKeyframe)")
        }
        
        // Call the frame callback
        frameCallback?(windowId, timestampMs, isKeyframe, nalData, width, height)
    }
    
    /// Check if sample buffer contains a keyframe
    private func isKeyFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
              let first = attachments.first else {
            return false
        }
        
        // If kCMSampleAttachmentKey_NotSync is not present or is false, it's a keyframe
        let notSync = first[kCMSampleAttachmentKey_NotSync] as? Bool ?? false
        return !notSync
    }
    
    /// Extract NAL units from sample buffer in Annex-B format (with start codes)
    private func extractNALUnitsAnnexB(from sampleBuffer: CMSampleBuffer, isKeyframe: Bool) -> Data? {
        // Get format description for parameter sets
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        
        var nalData = Data()
        let startCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        
        // For keyframes, include SPS and PPS
        if isKeyframe {
            // Extract SPS
            var spsSize: Int = 0
            var spsCount: Int = 0
            var spsPointer: UnsafePointer<UInt8>?
            
            var status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDesc,
                parameterSetIndex: 0,
                parameterSetPointerOut: &spsPointer,
                parameterSetSizeOut: &spsSize,
                parameterSetCountOut: &spsCount,
                nalUnitHeaderLengthOut: nil
            )
            
            if status == noErr, let sps = spsPointer {
                nalData.append(contentsOf: startCode)
                nalData.append(sps, count: spsSize)
            }
            
            // Extract PPS
            var ppsSize: Int = 0
            var ppsPointer: UnsafePointer<UInt8>?
            
            status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDesc,
                parameterSetIndex: 1,
                parameterSetPointerOut: &ppsPointer,
                parameterSetSizeOut: &ppsSize,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            )
            
            if status == noErr, let pps = ppsPointer {
                nalData.append(contentsOf: startCode)
                nalData.append(pps, count: ppsSize)
            }
        }
        
        // Get the data buffer
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        
        guard status == kCMBlockBufferNoErr, let data = dataPointer else {
            return nil
        }
        
        // VideoToolbox outputs AVCC format (length-prefixed NAL units)
        // Convert to Annex-B format (start code prefixed)
        var offset = 0
        let avccHeaderLength = 4 // 4-byte length prefix
        
        while offset < totalLength {
            // Read NAL unit length (big-endian)
            var nalLength: UInt32 = 0
            memcpy(&nalLength, data.advanced(by: offset), avccHeaderLength)
            nalLength = CFSwapInt32BigToHost(nalLength)
            
            offset += avccHeaderLength
            
            guard offset + Int(nalLength) <= totalLength else {
                break
            }
            
            // Append start code and NAL unit
            nalData.append(contentsOf: startCode)
            nalData.append(Data(bytes: data.advanced(by: offset), count: Int(nalLength)))
            
            offset += Int(nalLength)
        }
        
        return nalData.isEmpty ? nil : nalData
    }
}

