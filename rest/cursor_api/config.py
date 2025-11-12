"""
Configuration management using Pydantic Settings

Environment variables can be set via:
- .envrc (direnv)
- .env file
- System environment variables
"""

import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings with type-safe configuration"""
    
    # Database configuration
    db_path: str = os.path.expanduser(
        '~/Library/Application Support/Cursor/User/globalStorage/state.vscdb'
    )
    
    # Cursor agent configuration
    cursor_agent_path: str = os.path.expanduser('~/.local/bin/cursor-agent')
    cursor_agent_timeout: int = 90  # seconds
    
    # API server configuration
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    api_reload: bool = False  # Enable reload for development
    
    # Job management configuration
    job_cleanup_max_age_hours: int = 1
    job_cleanup_interval_minutes: int = 30
    
    # CORS configuration
    cors_allow_origins: list[str] = ["*"]
    cors_allow_credentials: bool = True
    cors_allow_methods: list[str] = ["*"]
    cors_allow_headers: list[str] = ["*"]
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        # Allow environment variables with CURSOR_API_ prefix
        env_prefix="",
    )


# Global settings instance
settings = Settings()

