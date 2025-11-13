"""
Cursor Chat REST API - Main Application

FastAPI application initialization with router registration and lifecycle management.
"""

import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from .config import settings
from .services import cleanup_old_jobs
from .api import health, chats, messages, agent, jobs, devices
from .database.device_db import ensure_device_db_initialized


# Background task for job cleanup
async def periodic_job_cleanup():
    """Periodically clean up old completed/failed jobs"""
    while True:
        try:
            removed = cleanup_old_jobs(max_age_hours=settings.job_cleanup_max_age_hours)
            if removed > 0:
                print(f"Cleaned up {removed} old jobs")
        except Exception as e:
            print(f"Error during job cleanup: {e}")
        
        # Wait for next cleanup interval
        await asyncio.sleep(settings.job_cleanup_interval_minutes * 60)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup and shutdown events"""
    # Startup
    print("=" * 80)
    print("Cursor Chat REST API Server")
    print("=" * 80)
    print(f"Database: {settings.db_path}")
    print(f"Device Database: {settings.device_db_path}")
    print(f"Cursor Agent: {settings.cursor_agent_path}")
    print(f"API Host: {settings.api_host}:{settings.api_port}")
    print("=" * 80)
    
    # Initialize device database
    ensure_device_db_initialized()
    print("Device database initialized")
    
    # Start background job cleanup task
    cleanup_task = asyncio.create_task(periodic_job_cleanup())
    
    yield
    
    # Shutdown
    cleanup_task.cancel()
    try:
        await cleanup_task
    except asyncio.CancelledError:
        pass
    print("Server shutdown complete")


# Initialize FastAPI application
app = FastAPI(
    title="Cursor Chat API",
    version="2.0.0",
    description="REST API for Cursor chat database with async job support",
    lifespan=lifespan
)

# Configure CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allow_origins,
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=settings.cors_allow_methods,
    allow_headers=settings.cors_allow_headers,
)

# Register routers
app.include_router(health.router)  # / and /health
app.include_router(chats.router)   # /chats/*
app.include_router(messages.router)  # /chats/{id}/messages
app.include_router(agent.router)   # /agent/* and /chats/{id}/agent-prompt*
app.include_router(jobs.router)    # /jobs/*
app.include_router(devices.router)  # /devices/*


def main():
    """Entry point for running the server"""
    uvicorn.run(
        "cursor_api.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=settings.api_reload,
        log_level="info"
    )


if __name__ == "__main__":
    main()

