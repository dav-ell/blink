//! Video processing module using GStreamer for scaling and cropping

mod gst_pipeline;

pub use gst_pipeline::{VideoPipeline, VideoConfig, Viewport};

