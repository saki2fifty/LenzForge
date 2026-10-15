"""
Simple launcher script for the Flask web server
"""
import sys
import json
from pathlib import Path

# Add both paths to Python path
backend_dir = Path(__file__).parent
parent_dir = backend_dir.parent

# Add parent so backend_v2 can be imported
sys.path.insert(0, str(parent_dir))
# Add backend_v2 so server can be imported
sys.path.insert(0, str(backend_dir))


class ConfigManager:
    """Simple configuration manager with persistent storage"""
    
    def __init__(self, config_file='lenzforge_config.json'):
        self.config_file = Path(config_file)
        self.config = self._load_config()
    
    def _load_config(self):
        """Load configuration from disk"""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                print(f"Error loading config: {e}")
                return {}
        return {}
    
    def get(self, key, default=None):
        """Get configuration value"""
        return self.config.get(key, default)
    
    def set(self, key, value):
        """Set configuration value and save to disk"""
        self.config[key] = value
        self._save_config()
    
    def _save_config(self):
        """Save configuration to disk"""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
        except Exception as e:
            print(f"Error saving config: {e}")


if __name__ == '__main__':
    print("Starting LenzForge V2 Web Server...")
    
    # Initialize config manager
    config_manager = ConfigManager()
    
    # Load and apply logging configuration
    from server.routes.system import apply_logging_config, set_config_manager, set_pipeline_manager
    
    logging_config = config_manager.get('logging_config', {
        'master_enabled': True,
        'categories': {
            'mediapipe': False,
            'matplotlib': False,
            'camera': True,
            'streaming': True,
            'tracking': True,
            'system': True,
            'werkzeug': False
        }
    })
    
    print(f"Applying logging config: MediaPipe={'enabled' if logging_config.get('categories', {}).get('mediapipe', True) else 'disabled'}")
    apply_logging_config(logging_config)
    
    # Set config manager for system routes
    set_config_manager(config_manager)
    
    # Initialize pipeline manager
    print("Initializing Pipeline Manager...")
    try:
        # Try to import using the backend_v2 package structure
        import backend_v2.pipeline.manager as pipeline_module
        import backend_v2.config as config_module
        
        config = config_module.get_config()
        pipeline_manager = pipeline_module.PipelineManager(config)
        set_pipeline_manager(pipeline_manager)
        print("[OK] Pipeline Manager initialized and ready")
    except Exception as e:
        print(f"[WARN] Could not initialize pipeline manager: {e}")
        print("[INFO] Pipeline will be created on first start request")
        # Don't fail - let it initialize later when needed
        pass
    
    # Import and run the server
    from server.app import run_server
    run_server(debug=True)
