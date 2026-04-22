from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from .database import Database
from .config import settings
from .routes import auth, passwords, email, teams, chat, documents
from .websocket_manager import sio
import socketio

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    logger.info("Starting up Password Manager API...")
    try:
        await Database.connect_db()
        logger.info("Database connected successfully")
    except Exception as e:
        logger.warning(f"Database connection failed: {e}")
        logger.warning("Server will start without database - some endpoints may not work")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Password Manager API...")
    await Database.close_db()
    logger.info("Database connection closed")


# Create FastAPI app
app = FastAPI(
    title="Password Manager API",
    description="Secure password management API with encryption and authentication",
    version="1.0.0",
    lifespan=lifespan
)
sio_app = socketio.ASGIApp(sio, other_asgi_app=app)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/api")
app.include_router(passwords.router, prefix="/api")
app.include_router(email.router, prefix="/api")
app.include_router(teams.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(documents.router, prefix="/api")



@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Password Manager API",
        "version": "1.0.0",
        "status": "running"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "database": "connected"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:sio_app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
