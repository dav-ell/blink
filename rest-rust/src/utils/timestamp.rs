use chrono::{DateTime, TimeZone, Utc};

/// Parse a timestamp (milliseconds since epoch) to ISO string
pub fn parse_timestamp(timestamp_ms: i64) -> String {
    let dt = Utc.timestamp_millis_opt(timestamp_ms).unwrap();
    dt.to_rfc3339()
}

/// Convert DateTime to milliseconds since epoch
pub fn datetime_to_millis(dt: DateTime<Utc>) -> i64 {
    dt.timestamp_millis()
}

