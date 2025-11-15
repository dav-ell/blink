use crate::error::{AppError, Result};
use crate::Settings;
use rusqlite::Connection;
use std::path::Path;

/// Get a connection to the Cursor database
///
/// This returns a synchronous rusqlite connection which should be used
/// inside tokio::task::spawn_blocking for async contexts.
pub fn get_cursor_db_connection(settings: &Settings) -> Result<Connection> {
    let db_path = &settings.db_path;

    if !Path::new(db_path).exists() {
        return Err(AppError::NotFound(format!(
            "Database not found at {}",
            db_path.display()
        )));
    }

    Connection::open(db_path).map_err(AppError::Database)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cursor_connection_missing_db() {
        let mut settings = Settings::default();
        settings.db_path = "/nonexistent/path/db.sqlite".into();

        let result = get_cursor_db_connection(&settings);
        assert!(result.is_err());
    }
}
