"""
API Routes Package
Contains all Flask blueprints for different API categories
"""

# Import blueprints for registration in app.py
from . import system
from . import camera
from . import tracking
from . import effects
from . import export_data
from . import logs
from . import docs

__all__ = [
    'system',
    'camera',
    'tracking',
    'effects',
    'export_data',
    'logs',
    'docs'
]
