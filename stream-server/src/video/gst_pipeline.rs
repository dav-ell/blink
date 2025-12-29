//! GStreamer pipeline for video scaling and cropping
//!
//! Provides efficient CPU-based video processing using GStreamer's
//! videocrop and videoscale elements.

use std::sync::{Arc, Mutex};
use anyhow::{anyhow, Result};
use gstreamer as gst;
use gstreamer::prelude::*;
use gstreamer_app::{AppSink, AppSrc};
use gstreamer_video::{VideoFormat, VideoInfo};
use tracing::{debug, error, info, warn};

/// Video processing configuration
#[derive(Debug, Clone)]
pub struct VideoConfig {
    /// Target output width (default: 1280 for 720p)
    pub target_width: u32,
    /// Target output height (default: 720 for 720p)
    pub target_height: u32,
    /// Whether scaling is enabled
    pub enable_scaling: bool,
}

impl Default for VideoConfig {
    fn default() -> Self {
        Self {
            target_width: 1280,
            target_height: 720,
            enable_scaling: true,
        }
    }
}

impl VideoConfig {
    /// Create a 480p configuration
    pub fn resolution_480p() -> Self {
        Self {
            target_width: 854,
            target_height: 480,
            enable_scaling: true,
        }
    }

    /// Create a 720p configuration
    pub fn resolution_720p() -> Self {
        Self {
            target_width: 1280,
            target_height: 720,
            enable_scaling: true,
        }
    }

    /// Create a 1080p configuration
    pub fn resolution_1080p() -> Self {
        Self {
            target_width: 1920,
            target_height: 1080,
            enable_scaling: true,
        }
    }
}

/// Viewport definition for cropping (normalized coordinates 0.0-1.0)
#[derive(Debug, Clone, Copy)]
pub struct Viewport {
    /// Left edge (0.0 = left, 1.0 = right)
    pub x: f32,
    /// Top edge (0.0 = top, 1.0 = bottom)
    pub y: f32,
    /// Width as fraction of source (1.0 = full width)
    pub width: f32,
    /// Height as fraction of source (1.0 = full height)
    pub height: f32,
}

impl Default for Viewport {
    fn default() -> Self {
        Self {
            x: 0.0,
            y: 0.0,
            width: 1.0,
            height: 1.0,
        }
    }
}

impl Viewport {
    /// Create a full-frame viewport (no cropping)
    pub fn full() -> Self {
        Self::default()
    }

    /// Check if this is a full-frame viewport
    pub fn is_full(&self) -> bool {
        (self.x - 0.0).abs() < 0.001
            && (self.y - 0.0).abs() < 0.001
            && (self.width - 1.0).abs() < 0.001
            && (self.height - 1.0).abs() < 0.001
    }

    /// Convert to pixel coordinates given source dimensions
    pub fn to_pixels(&self, src_width: u32, src_height: u32) -> (u32, u32, u32, u32) {
        let x = (self.x * src_width as f32) as u32;
        let y = (self.y * src_height as f32) as u32;
        let w = (self.width * src_width as f32) as u32;
        let h = (self.height * src_height as f32) as u32;
        
        // Ensure minimum size and bounds
        let w = w.max(16).min(src_width - x);
        let h = h.max(16).min(src_height - y);
        
        (x, y, w, h)
    }
}

/// Callback type for receiving processed frames
pub type FrameCallback = Box<dyn Fn(&[u8], u32, u32, u64) + Send + Sync>;

/// GStreamer video processing pipeline
pub struct VideoPipeline {
    pipeline: gst::Pipeline,
    appsrc: AppSrc,
    appsink: AppSink,
    videocrop: gst::Element,
    videoscale: gst::Element,
    capsfilter: gst::Element,
    
    config: VideoConfig,
    source_width: u32,
    source_height: u32,
    viewport: Arc<Mutex<Viewport>>,
    
    frame_callback: Arc<Mutex<Option<FrameCallback>>>,
}

impl VideoPipeline {
    /// Initialize GStreamer (call once at startup)
    pub fn init() -> Result<()> {
        gst::init().map_err(|e| anyhow!("Failed to initialize GStreamer: {}", e))?;
        info!("GStreamer initialized: version {}", gst::version_string());
        Ok(())
    }

    /// Create a new video pipeline for a window
    pub fn new(
        window_id: u32,
        source_width: u32,
        source_height: u32,
        config: VideoConfig,
    ) -> Result<Self> {
        let pipeline_name = format!("video-pipeline-{}", window_id);
        let pipeline = gst::Pipeline::with_name(&pipeline_name);

        // Create elements
        let appsrc = AppSrc::builder()
            .name(&format!("appsrc-{}", window_id))
            .is_live(true)
            .do_timestamp(true)
            .format(gst::Format::Time)
            .build();

        let videocrop = gst::ElementFactory::make("videocrop")
            .name(&format!("videocrop-{}", window_id))
            .build()
            .map_err(|e| anyhow!("Failed to create videocrop: {}", e))?;

        let videoscale = gst::ElementFactory::make("videoscale")
            .name(&format!("videoscale-{}", window_id))
            .build()
            .map_err(|e| anyhow!("Failed to create videoscale: {}", e))?;

        let videoconvert = gst::ElementFactory::make("videoconvert")
            .name(&format!("videoconvert-{}", window_id))
            .build()
            .map_err(|e| anyhow!("Failed to create videoconvert: {}", e))?;

        // Capsfilter to enforce output resolution
        let capsfilter = gst::ElementFactory::make("capsfilter")
            .name(&format!("capsfilter-{}", window_id))
            .build()
            .map_err(|e| anyhow!("Failed to create capsfilter: {}", e))?;

        // Set output caps for target resolution
        let output_caps = gst::Caps::builder("video/x-raw")
            .field("format", VideoFormat::Bgra.to_str())
            .field("width", config.target_width as i32)
            .field("height", config.target_height as i32)
            .build();
        capsfilter.set_property("caps", &output_caps);

        let appsink = AppSink::builder()
            .name(&format!("appsink-{}", window_id))
            .sync(false)
            .build();

        // Set input caps on appsrc
        let input_caps = gst::Caps::builder("video/x-raw")
            .field("format", VideoFormat::Bgra.to_str())
            .field("width", source_width as i32)
            .field("height", source_height as i32)
            .field("framerate", gst::Fraction::new(30, 1))
            .build();
        appsrc.set_caps(Some(&input_caps));

        // Add elements to pipeline
        pipeline.add_many([
            appsrc.upcast_ref(),
            &videocrop,
            &videoscale,
            &videoconvert,
            &capsfilter,
            appsink.upcast_ref(),
        ])?;

        // Link elements
        gst::Element::link_many([
            appsrc.upcast_ref(),
            &videocrop,
            &videoscale,
            &videoconvert,
            &capsfilter,
            appsink.upcast_ref(),
        ])?;

        let frame_callback: Arc<Mutex<Option<FrameCallback>>> = Arc::new(Mutex::new(None));
        let callback_clone = Arc::clone(&frame_callback);
        let target_w = config.target_width;
        let target_h = config.target_height;

        // Set up appsink callback
        appsink.set_callbacks(
            gstreamer_app::AppSinkCallbacks::builder()
                .new_sample(move |sink| {
                    match sink.pull_sample() {
                        Ok(sample) => {
                            if let Some(buffer) = sample.buffer() {
                                if let Ok(map) = buffer.map_readable() {
                                    let pts = buffer.pts().map(|p| p.nseconds()).unwrap_or(0);
                                    if let Some(ref cb) = *callback_clone.lock().unwrap() {
                                        cb(map.as_slice(), target_w, target_h, pts);
                                    }
                                }
                            }
                            Ok(gst::FlowSuccess::Ok)
                        }
                        Err(_) => Err(gst::FlowError::Error),
                    }
                })
                .build(),
        );

        info!(
            "Created video pipeline for window {}: {}x{} -> {}x{}",
            window_id, source_width, source_height, config.target_width, config.target_height
        );

        Ok(Self {
            pipeline,
            appsrc,
            appsink,
            videocrop,
            videoscale,
            capsfilter,
            config,
            source_width,
            source_height,
            viewport: Arc::new(Mutex::new(Viewport::default())),
            frame_callback,
        })
    }

    /// Start the pipeline
    pub fn start(&self) -> Result<()> {
        self.pipeline
            .set_state(gst::State::Playing)
            .map_err(|e| anyhow!("Failed to start pipeline: {}", e))?;
        info!("Video pipeline started");
        Ok(())
    }

    /// Stop the pipeline
    pub fn stop(&self) -> Result<()> {
        self.pipeline
            .set_state(gst::State::Null)
            .map_err(|e| anyhow!("Failed to stop pipeline: {}", e))?;
        info!("Video pipeline stopped");
        Ok(())
    }

    /// Set the frame callback
    pub fn set_frame_callback<F>(&self, callback: F)
    where
        F: Fn(&[u8], u32, u32, u64) + Send + Sync + 'static,
    {
        *self.frame_callback.lock().unwrap() = Some(Box::new(callback));
    }

    /// Update the viewport (crop region)
    pub fn set_viewport(&self, viewport: Viewport) {
        let (crop_x, crop_y, crop_w, crop_h) =
            viewport.to_pixels(self.source_width, self.source_height);

        // Calculate crop amounts (how much to remove from each side)
        let left = crop_x;
        let right = self.source_width.saturating_sub(crop_x + crop_w);
        let top = crop_y;
        let bottom = self.source_height.saturating_sub(crop_y + crop_h);

        // Update videocrop properties
        self.videocrop.set_property("left", left as i32);
        self.videocrop.set_property("right", right as i32);
        self.videocrop.set_property("top", top as i32);
        self.videocrop.set_property("bottom", bottom as i32);

        *self.viewport.lock().unwrap() = viewport;

        debug!(
            "Updated viewport: crop L={} R={} T={} B={} (visible {}x{})",
            left, right, top, bottom, crop_w, crop_h
        );
    }

    /// Get the current viewport
    pub fn viewport(&self) -> Viewport {
        *self.viewport.lock().unwrap()
    }

    /// Push a raw BGRA frame into the pipeline
    pub fn push_frame(&self, data: &[u8], timestamp_ns: u64) -> Result<()> {
        let expected_size = (self.source_width * self.source_height * 4) as usize;
        if data.len() != expected_size {
            return Err(anyhow!(
                "Frame size mismatch: got {} bytes, expected {}",
                data.len(),
                expected_size
            ));
        }

        let mut buffer = gst::Buffer::with_size(data.len())
            .map_err(|e| anyhow!("Failed to allocate buffer: {}", e))?;

        {
            let buffer_ref = buffer.get_mut().unwrap();
            buffer_ref.set_pts(gst::ClockTime::from_nseconds(timestamp_ns));
            
            let mut map = buffer_ref
                .map_writable()
                .map_err(|e| anyhow!("Failed to map buffer: {}", e))?;
            map.copy_from_slice(data);
        }

        self.appsrc
            .push_buffer(buffer)
            .map_err(|e| anyhow!("Failed to push buffer: {}", e))?;

        Ok(())
    }

    /// Update the target resolution dynamically
    pub fn set_target_resolution(&mut self, width: u32, height: u32) -> Result<()> {
        let output_caps = gst::Caps::builder("video/x-raw")
            .field("format", VideoFormat::Bgra.to_str())
            .field("width", width as i32)
            .field("height", height as i32)
            .build();

        self.capsfilter.set_property("caps", &output_caps);
        self.config.target_width = width;
        self.config.target_height = height;

        info!("Updated target resolution to {}x{}", width, height);
        Ok(())
    }

    /// Get the current configuration
    pub fn config(&self) -> &VideoConfig {
        &self.config
    }
}

impl Drop for VideoPipeline {
    fn drop(&mut self) {
        if let Err(e) = self.stop() {
            warn!("Error stopping pipeline on drop: {}", e);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_viewport_to_pixels() {
        let viewport = Viewport {
            x: 0.25,
            y: 0.25,
            width: 0.5,
            height: 0.5,
        };

        let (x, y, w, h) = viewport.to_pixels(1920, 1080);
        assert_eq!(x, 480);
        assert_eq!(y, 270);
        assert_eq!(w, 960);
        assert_eq!(h, 540);
    }

    #[test]
    fn test_viewport_full() {
        let viewport = Viewport::full();
        assert!(viewport.is_full());

        let zoomed = Viewport {
            x: 0.1,
            y: 0.1,
            width: 0.8,
            height: 0.8,
        };
        assert!(!zoomed.is_full());
    }

    #[test]
    fn test_video_config_presets() {
        let config_480 = VideoConfig::resolution_480p();
        assert_eq!(config_480.target_width, 854);
        assert_eq!(config_480.target_height, 480);

        let config_720 = VideoConfig::resolution_720p();
        assert_eq!(config_720.target_width, 1280);
        assert_eq!(config_720.target_height, 720);

        let config_1080 = VideoConfig::resolution_1080p();
        assert_eq!(config_1080.target_width, 1920);
        assert_eq!(config_1080.target_height, 1080);
    }
}

