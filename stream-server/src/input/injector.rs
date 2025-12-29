//! CGEvent input injection for mouse and keyboard events

use anyhow::{anyhow, Result};
use core_graphics::display::CGDisplay;
use core_graphics::event::{
    CGEvent, CGEventFlags, CGEventTapLocation, CGEventType, CGMouseButton,
};
use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};
use core_graphics::geometry::CGPoint;
use serde::{Deserialize, Serialize};
use tracing::debug;

use crate::capture::WindowBounds;

/// Mouse button types
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MouseButton {
    Left,
    Right,
    Middle,
}

/// Mouse action types
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MouseAction {
    Click,
    DoubleClick,
    Down,
    Up,
    Move,
    Drag,
    Scroll,
}

/// Mouse input event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MouseEvent {
    pub window_id: u32,
    pub action: MouseAction,
    #[serde(default)]
    pub button: Option<MouseButton>,
    /// Normalized X coordinate (0.0 - 1.0)
    pub x: f64,
    /// Normalized Y coordinate (0.0 - 1.0)
    pub y: f64,
    /// Scroll delta for scroll events
    #[serde(default)]
    pub scroll_delta: Option<i32>,
}

/// Key action types
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum KeyAction {
    Down,
    Up,
}

/// Keyboard modifier keys
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum KeyModifier {
    Cmd,
    Shift,
    Alt,
    Ctrl,
    Fn,
}

/// Keyboard input event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyEvent {
    pub window_id: u32,
    pub action: KeyAction,
    /// macOS virtual key code
    pub key_code: u16,
    /// Active modifier keys
    #[serde(default)]
    pub modifiers: Vec<KeyModifier>,
}

/// Text input event - for typing text characters
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextEvent {
    pub window_id: u32,
    /// The text to type
    pub text: String,
}

/// Handles input injection via CGEvent
pub struct InputInjector {
    /// Cache of window bounds for coordinate conversion
    window_bounds_cache: parking_lot::RwLock<std::collections::HashMap<u32, WindowBounds>>,
}

impl InputInjector {
    pub fn new() -> Self {
        Self {
            window_bounds_cache: parking_lot::RwLock::new(std::collections::HashMap::new()),
        }
    }

    /// Update cached window bounds
    pub fn update_window_bounds(&self, window_id: u32, bounds: WindowBounds) {
        self.window_bounds_cache.write().insert(window_id, bounds);
    }

    /// Get window bounds from cache
    fn get_bounds(&self, window_id: u32) -> Option<WindowBounds> {
        self.window_bounds_cache.read().get(&window_id).cloned()
    }

    /// Convert normalized coordinates to screen coordinates
    /// 
    /// Note: Window bounds from ScreenCaptureKit are in Quartz coordinates (origin at bottom-left),
    /// but CGEvent uses coordinates with origin at top-left. We need to convert Y.
    fn to_screen_coords(&self, window_id: u32, norm_x: f64, norm_y: f64) -> Result<CGPoint> {
        let bounds = self
            .get_bounds(window_id)
            .ok_or_else(|| anyhow!("Window bounds not found for {}", window_id))?;

        // Get main display height for Y coordinate conversion
        let main_display = CGDisplay::main();
        let screen_height = main_display.bounds().size.height;

        // X coordinate is straightforward (left-to-right is same in both systems)
        let screen_x = bounds.x + (norm_x * bounds.width);
        
        // Y coordinate conversion:
        // - Quartz: bounds.y is distance from screen BOTTOM to window BOTTOM
        // - CGEvent: needs distance from screen TOP
        // 
        // Window top in Quartz = bounds.y + bounds.height
        // Window top in CGEvent = screen_height - (bounds.y + bounds.height)
        // Click position = window_top_cgevent + (norm_y * bounds.height)
        let window_top_cgevent = screen_height - (bounds.y + bounds.height);
        let screen_y = window_top_cgevent + (norm_y * bounds.height);

        debug!(
            "Coord conversion: norm({:.3},{:.3}) -> screen({:.1},{:.1}), bounds=({:.1},{:.1},{:.1},{:.1}), screen_h={:.1}",
            norm_x, norm_y, screen_x, screen_y, bounds.x, bounds.y, bounds.width, bounds.height, screen_height
        );

        Ok(CGPoint::new(screen_x, screen_y))
    }

    /// Inject a mouse event
    pub fn inject_mouse(&self, event: &MouseEvent) -> Result<()> {
        let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
            .map_err(|_| anyhow!("Failed to create event source"))?;

        let point = self.to_screen_coords(event.window_id, event.x, event.y)?;

        match event.action {
            MouseAction::Move => {
                let cg_event = CGEvent::new_mouse_event(
                    source,
                    CGEventType::MouseMoved,
                    point,
                    CGMouseButton::Left,
                )
                .map_err(|_| anyhow!("Failed to create mouse move event"))?;

                cg_event.post(CGEventTapLocation::HID);
                debug!("Injected mouse move to ({}, {})", point.x, point.y);
            }

            MouseAction::Drag => {
                // Drag is a mouse move while button is held down
                let cg_event = CGEvent::new_mouse_event(
                    source,
                    CGEventType::LeftMouseDragged,
                    point,
                    CGMouseButton::Left,
                )
                .map_err(|_| anyhow!("Failed to create mouse drag event"))?;

                cg_event.post(CGEventTapLocation::HID);
                debug!("Injected mouse drag to ({}, {})", point.x, point.y);
            }

            MouseAction::Click => {
                let button = event.button.unwrap_or(MouseButton::Left);
                self.inject_click(&source, point, button)?;
            }

            MouseAction::DoubleClick => {
                let button = event.button.unwrap_or(MouseButton::Left);
                self.inject_double_click(&source, point, button)?;
            }

            MouseAction::Down => {
                let button = event.button.unwrap_or(MouseButton::Left);
                self.inject_mouse_down(&source, point, button)?;
            }

            MouseAction::Up => {
                let button = event.button.unwrap_or(MouseButton::Left);
                self.inject_mouse_up(&source, point, button)?;
            }

            MouseAction::Scroll => {
                let delta = event.scroll_delta.unwrap_or(0);
                self.inject_scroll(&source, point, delta)?;
            }
        }

        Ok(())
    }

    fn inject_click(
        &self,
        source: &CGEventSource,
        point: CGPoint,
        button: MouseButton,
    ) -> Result<()> {
        self.inject_mouse_down(source, point, button)?;
        self.inject_mouse_up(source, point, button)?;
        debug!("Injected {:?} click at ({}, {})", button, point.x, point.y);
        Ok(())
    }

    fn inject_double_click(
        &self,
        source: &CGEventSource,
        point: CGPoint,
        button: MouseButton,
    ) -> Result<()> {
        // Double click requires setting click count on the events
        let (down_type, up_type, cg_button) = match button {
            MouseButton::Left => (CGEventType::LeftMouseDown, CGEventType::LeftMouseUp, CGMouseButton::Left),
            MouseButton::Right => (CGEventType::RightMouseDown, CGEventType::RightMouseUp, CGMouseButton::Right),
            MouseButton::Middle => (CGEventType::OtherMouseDown, CGEventType::OtherMouseUp, CGMouseButton::Center),
        };

        // First click
        let down1 = CGEvent::new_mouse_event(source.clone(), down_type, point, cg_button)
            .map_err(|_| anyhow!("Failed to create mouse down event"))?;
        down1.set_integer_value_field(core_graphics::event::EventField::MOUSE_EVENT_CLICK_STATE, 1);
        down1.post(CGEventTapLocation::HID);

        let up1 = CGEvent::new_mouse_event(source.clone(), up_type, point, cg_button)
            .map_err(|_| anyhow!("Failed to create mouse up event"))?;
        up1.set_integer_value_field(core_graphics::event::EventField::MOUSE_EVENT_CLICK_STATE, 1);
        up1.post(CGEventTapLocation::HID);

        // Second click with click count = 2
        let down2 = CGEvent::new_mouse_event(source.clone(), down_type, point, cg_button)
            .map_err(|_| anyhow!("Failed to create mouse down event"))?;
        down2.set_integer_value_field(core_graphics::event::EventField::MOUSE_EVENT_CLICK_STATE, 2);
        down2.post(CGEventTapLocation::HID);

        let up2 = CGEvent::new_mouse_event(source.clone(), up_type, point, cg_button)
            .map_err(|_| anyhow!("Failed to create mouse up event"))?;
        up2.set_integer_value_field(core_graphics::event::EventField::MOUSE_EVENT_CLICK_STATE, 2);
        up2.post(CGEventTapLocation::HID);

        debug!("Injected {:?} double-click at ({}, {})", button, point.x, point.y);
        Ok(())
    }

    fn inject_mouse_down(
        &self,
        source: &CGEventSource,
        point: CGPoint,
        button: MouseButton,
    ) -> Result<()> {
        let (event_type, cg_button) = match button {
            MouseButton::Left => (CGEventType::LeftMouseDown, CGMouseButton::Left),
            MouseButton::Right => (CGEventType::RightMouseDown, CGMouseButton::Right),
            MouseButton::Middle => (CGEventType::OtherMouseDown, CGMouseButton::Center),
        };

        let event = CGEvent::new_mouse_event(source.clone(), event_type, point, cg_button)
            .map_err(|_| anyhow!("Failed to create mouse down event"))?;

        event.post(CGEventTapLocation::HID);
        Ok(())
    }

    fn inject_mouse_up(
        &self,
        source: &CGEventSource,
        point: CGPoint,
        button: MouseButton,
    ) -> Result<()> {
        let (event_type, cg_button) = match button {
            MouseButton::Left => (CGEventType::LeftMouseUp, CGMouseButton::Left),
            MouseButton::Right => (CGEventType::RightMouseUp, CGMouseButton::Right),
            MouseButton::Middle => (CGEventType::OtherMouseUp, CGMouseButton::Center),
        };

        let event = CGEvent::new_mouse_event(source.clone(), event_type, point, cg_button)
            .map_err(|_| anyhow!("Failed to create mouse up event"))?;

        event.post(CGEventTapLocation::HID);
        Ok(())
    }

    fn inject_scroll(&self, source: &CGEventSource, point: CGPoint, delta: i32) -> Result<()> {
        // Create a scroll wheel event using mouse event type
        // CGEventType::ScrollWheel is not directly available in core-graphics 0.23
        // We'll use a workaround by creating a generic event and setting scroll wheel data
        
        // First move to the target position
        let move_event = CGEvent::new_mouse_event(
            source.clone(),
            CGEventType::MouseMoved,
            point,
            CGMouseButton::Left,
        )
        .map_err(|_| anyhow!("Failed to create mouse move event for scroll"))?;
        move_event.post(CGEventTapLocation::HID);

        // For scroll, we use the scroll wheel event type (value 22)
        // This requires using the raw CGEvent API through core-foundation
        // For now, we'll simulate scroll via keyboard arrows as a fallback
        if delta != 0 {
            let key_code = if delta > 0 { 126 } else { 125 }; // Up/Down arrow
            let count = delta.abs().min(10) as usize;
            
            for _ in 0..count {
                let down_event = CGEvent::new_keyboard_event(source.clone(), key_code, true)
                    .map_err(|_| anyhow!("Failed to create scroll key down event"))?;
                down_event.post(CGEventTapLocation::HID);
                
                let up_event = CGEvent::new_keyboard_event(source.clone(), key_code, false)
                    .map_err(|_| anyhow!("Failed to create scroll key up event"))?;
                up_event.post(CGEventTapLocation::HID);
            }
        }

        debug!("Injected scroll delta {} at ({}, {})", delta, point.x, point.y);
        Ok(())
    }

    /// Inject a keyboard event
    pub fn inject_key(&self, event: &KeyEvent) -> Result<()> {
        let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
            .map_err(|_| anyhow!("Failed to create event source"))?;

        let is_down = matches!(event.action, KeyAction::Down);

        let cg_event = CGEvent::new_keyboard_event(source, event.key_code, is_down)
            .map_err(|_| anyhow!("Failed to create keyboard event"))?;

        // Apply modifiers
        let flags = self.modifiers_to_flags(&event.modifiers);
        cg_event.set_flags(flags);

        cg_event.post(CGEventTapLocation::HID);

        debug!(
            "Injected key {} (code: {}, modifiers: {:?})",
            if is_down { "down" } else { "up" },
            event.key_code,
            event.modifiers
        );

        Ok(())
    }

    fn modifiers_to_flags(&self, modifiers: &[KeyModifier]) -> CGEventFlags {
        let mut flags = CGEventFlags::empty();

        for modifier in modifiers {
            match modifier {
                KeyModifier::Cmd => flags |= CGEventFlags::CGEventFlagCommand,
                KeyModifier::Shift => flags |= CGEventFlags::CGEventFlagShift,
                KeyModifier::Alt => flags |= CGEventFlags::CGEventFlagAlternate,
                KeyModifier::Ctrl => flags |= CGEventFlags::CGEventFlagControl,
                KeyModifier::Fn => flags |= CGEventFlags::CGEventFlagSecondaryFn,
            }
        }

        flags
    }

    /// Inject text input by typing each character
    pub fn inject_text(&self, event: &TextEvent) -> Result<()> {
        let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
            .map_err(|_| anyhow!("Failed to create event source"))?;

        for ch in event.text.chars() {
            // Create a keyboard event and set the Unicode string
            let key_down = CGEvent::new_keyboard_event(source.clone(), 0, true)
                .map_err(|_| anyhow!("Failed to create key down event for text"))?;
            
            // Set the Unicode character to type
            let ch_str = ch.to_string();
            key_down.set_string(&ch_str);
            key_down.post(CGEventTapLocation::HID);

            let key_up = CGEvent::new_keyboard_event(source.clone(), 0, false)
                .map_err(|_| anyhow!("Failed to create key up event for text"))?;
            key_up.set_string(&ch_str);
            key_up.post(CGEventTapLocation::HID);

            debug!("Injected text character: '{}'", ch);
        }

        Ok(())
    }
}

impl Default for InputInjector {
    fn default() -> Self {
        Self::new()
    }
}
