"""
LenzForge V2 - HTTP API Server
Advanced web interface with real-time updates

This module provides a Flask-based HTTP API server with:
- RESTful API endpoints for all backend features
- WebSocket support for real-time updates
- Advanced web UI with professional dashboard
- CORS enabled for web access
"""

__version__ = "2.0.0"
__author__ = "LenzForge"

from .app import create_app

__all__ = ['create_app']
