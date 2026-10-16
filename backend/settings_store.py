"""Small, atomic preference store; never accessed by the frame-processing loop."""
from copy import deepcopy
import json
import logging
import os
from pathlib import Path
import sys
import tempfile
import threading


def settings_directory():
    if override := os.environ.get('LENZFORGE_SETTINGS_DIR'):
        return Path(override)
    if sys.platform == 'win32':
        base = Path(os.environ.get('APPDATA', Path.home() / 'AppData/Roaming'))
    elif sys.platform == 'darwin':
        base = Path.home() / 'Library/Application Support'
    else:
        base = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
    return base / 'Godot/app_userdata/LenzForge Studio'


class SettingsStore:
    def __init__(self, path=None):
        self.path = Path(path) if path else None
        self.lock = threading.RLock()
        self.data = {}
        self.restoring = False
        if self.path and self.path.exists():
            try:
                document = json.loads(self.path.read_text(encoding='utf-8'))
                if document.get('version') != 1 or not isinstance(document.get('settings'), dict):
                    raise ValueError('Unsupported settings document')
                self.data = document['settings']
            except (OSError, ValueError, AttributeError) as exc:
                logging.getLogger(__name__).warning('Cannot load %s: %s', self.path, exc)
                # Preserve the original for recovery instead of overwriting it.
                self.path.replace(self.path.with_suffix('.invalid.json'))

    def save(self, section, value):
        self.save_sections({section: value})

    def save_sections(self, changes):
        if self.restoring:
            return
        with self.lock:
            candidate = {**self.data, **deepcopy(changes)}
            if candidate == self.data:
                return
            if self.path:
                self.path.parent.mkdir(parents=True, exist_ok=True)
                temporary = None
                try:
                    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=self.path.parent,
                                                     prefix='backend-', suffix='.tmp', delete=False) as file:
                        temporary = file.name
                        json.dump({'version': 1, 'settings': candidate}, file, indent=2, allow_nan=False)
                        file.write('\n')
                        file.flush()
                        os.fsync(file.fileno())
                    os.replace(temporary, self.path)
                finally:
                    if temporary and os.path.exists(temporary):
                        os.unlink(temporary)
            self.data = candidate


def save_section(section, value):
    save_sections({section: value})


def save_sections(changes):
    # Benchmarks and standalone pipeline tests must not change user preferences.
    from flask import current_app, has_app_context
    if has_app_context():
        current_app.extensions['settings_store'].save_sections(changes)


def initialize_settings(app):
    path = app.config.get('SETTINGS_PATH')
    if path is None and not app.testing:
        path = settings_directory() / 'backend.json'
    store = app.extensions['settings_store'] = SettingsStore(path)
    if not path:
        return
    from pipeline import tracking_config, performance_config
    from server.routes import tracking, effects
    store.restoring = True
    try:
        with app.app_context():
            # Validate independently so one unavailable model does not discard
            # the other preferences. Keep its saved ID for when it is restored.
            for section, update in [('performance', performance_config.update_performance_config),
                                    ('tracking', tracking_config.update_tracking_config)]:
                values = store.data.get(section, {})
                if not isinstance(values, dict):
                    continue
                for key, value in values.items():
                    try:
                        update({key: value})
                    except (TypeError, ValueError) as exc:
                        app.logger.warning('Could not restore %s.%s: %s', section, key, exc)
            features = store.data.get('features', {})
            for key, value in (features.items() if isinstance(features, dict) else []):
                if key in tracking.FEATURES and type(value) is bool:
                    tracking._tracking_stats[key]['enabled'] = value
            try:
                effects.restore_chain(store.data.get('effects', []))
            except (TypeError, ValueError, KeyError) as exc:
                app.logger.warning('Could not restore effects: %s', exc)
    finally:
        store.restoring = False
