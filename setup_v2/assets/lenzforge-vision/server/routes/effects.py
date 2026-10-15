"""
Effects API Routes
Handles effects operations: list, active, apply, configure, enable, remove, clear, chain
"""

from flask import Blueprint, jsonify, request

bp = Blueprint('effects', __name__)

# Global effects state
_effects_manager = None

# Import streaming module to share _active_effects
from . import streaming
_active_effects = streaming._active_effects  # Share the same list


def set_effects_manager(manager):
    """Set the effects manager instance"""
    global _effects_manager
    _effects_manager = manager


@bp.route('/list', methods=['GET'])
def list_effects():
    """
    GET /api/effects/list
    Get list of all available effects
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    global _effects_manager
    try:
        if not _effects_manager:
            import sys
            import traceback
            try:
                from effects import get_effects_manager
            except ImportError as e1:
                try:
                    from backend_v2.effects import get_effects_manager
                except ImportError as e2:
                    from pathlib import Path
                    backend_path = Path(__file__).parent.parent.parent
                    if str(backend_path) not in sys.path:
                        sys.path.insert(0, str(backend_path))
                    try:
                        from effects import get_effects_manager
                    except ImportError as e3:
                        # Return detailed error
                        return jsonify({
                            'success': False,
                            'error': {
                                'code': 'IMPORT_ERROR',
                                'message': f'Failed all import attempts: {str(e1)}; {str(e2)}; {str(e3)}',
                                'traceback': traceback.format_exc()
                            },
                            'categories': {},
                            'total_effects': 0
                        }), 200  # Return 200 so frontend shows error
            _effects_manager = get_effects_manager()
        
        # Get all effects by category
        effects_by_category = _effects_manager.get_all_effects_info()
        
        # Transform data structure for frontend
        # Frontend expects: { 'Category': [{'name': 'EffectName', 'category': 'Category'}, ...] }
        categories = {}
        for category, effects_dict in effects_by_category.items():
            categories[category] = [
                {'name': effect_name, 'category': category}
                for effect_name in effects_dict.keys()
            ]
        
        # Get stats
        stats = _effects_manager.get_statistics()
        
        return jsonify({
            'categories': categories,
            'total_effects': stats['total_effects'],
            'total_categories': len(categories),
            'total_parameters': stats['total_parameters']
        })
    
    except Exception as e:
        import traceback
        return jsonify({
            'success': False,
            'error': {
                'code': 'EFFECTS_LIST_ERROR',
                'message': str(e),
                'traceback': traceback.format_exc()
            },
            'categories': {},
            'total_effects': 0
        }), 200  # Return 200 so frontend shows error


@bp.route('/active', methods=['GET'])
def get_active():
    """
    GET /api/effects/active
    Get currently active effects
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        active_list = []
        
        for effect in _active_effects:
            effect_info = {
                'name': effect.__class__.__name__,
                'enabled': effect.is_enabled(),
                'parameters': effect.get_parameters_info()
            }
            active_list.append(effect_info)
        
        return jsonify({
            'active_effects': active_list,
            'chain_length': len(_active_effects)
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'ACTIVE_EFFECTS_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/apply', methods=['POST'])
def apply_effect():
    """
    POST /api/effects/apply
    Apply an effect to the pipeline
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    global _effects_manager
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        effect_name = data.get('effect_name')
        parameters = data.get('parameters', {})
        enabled = data.get('enabled', True)
        
        if not effect_name:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'effect_name is required'
                }
            }), 400
        
        if not _effects_manager:
            from ...effects import get_effects_manager
            _effects_manager = get_effects_manager()
        
        # Create effect
        effect = _effects_manager.create_effect(effect_name)
        
        if not effect:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'EFFECT_NOT_FOUND',
                    'message': f'Effect "{effect_name}" not found'
                }
            }), 404
        
        # Set parameters
        for param_name, param_value in parameters.items():
            effect.set_parameter(param_name, param_value)
        
        # Enable if requested
        if enabled:
            effect.enable()
        
        # Add to active effects
        _active_effects.append(effect)
        
        return jsonify({
            'success': True,
            'message': 'Effect applied',
            'effect': {
                'name': effect_name,
                'enabled': enabled,
                'position': len(_active_effects) - 1
            }
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'APPLY_EFFECT_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/configure', methods=['POST'])
def configure_effect():
    """
    POST /api/effects/configure
    Configure an active effect's parameters
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        effect_name = data.get('effect_name')
        parameters = data.get('parameters', {})
        
        if not effect_name:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'effect_name is required'
                }
            }), 400
        
        # Find effect in active list
        effect = None
        for eff in _active_effects:
            if eff.__class__.__name__ == effect_name:
                effect = eff
                break
        
        if not effect:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'EFFECT_NOT_ACTIVE',
                    'message': f'Effect "{effect_name}" is not active'
                }
            }), 404
        
        # Update parameters
        updated = []
        for param_name, param_value in parameters.items():
            effect.set_parameter(param_name, param_value)
            updated.append(param_name)
        
        return jsonify({
            'success': True,
            'message': 'Effect configured',
            'updated_parameters': updated
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CONFIGURE_EFFECT_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/enable', methods=['POST'])
def enable_effect():
    """
    POST /api/effects/enable
    Enable/disable an effect
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        effect_name = data.get('effect_name')
        enabled = data.get('enabled', True)
        
        if not effect_name:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'effect_name is required'
                }
            }), 400
        
        # Find effect
        effect = None
        for eff in _active_effects:
            if eff.__class__.__name__ == effect_name:
                effect = eff
                break
        
        if not effect:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'EFFECT_NOT_ACTIVE',
                    'message': f'Effect "{effect_name}" is not active'
                }
            }), 404
        
        # Enable/disable
        if enabled:
            effect.enable()
        else:
            effect.disable()
        
        return jsonify({
            'success': True,
            'message': f'Effect {"enabled" if enabled else "disabled"}',
            'effect': effect_name,
            'enabled': enabled
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'ENABLE_EFFECT_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/remove', methods=['POST'])
def remove_effect():
    """
    POST /api/effects/remove
    Remove an effect from the chain
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        effect_name = data.get('effect_name')
        
        if not effect_name:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'effect_name is required'
                }
            }), 400
        
        # Find and remove effect
        global _active_effects
        removed = False
        for i, eff in enumerate(_active_effects):
            if eff.__class__.__name__ == effect_name:
                _active_effects.pop(i)
                removed = True
                break
        
        if not removed:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'EFFECT_NOT_FOUND',
                    'message': f'Effect "{effect_name}" not found in active chain'
                }
            }), 404
        
        return jsonify({
            'success': True,
            'message': 'Effect removed',
            'effect': effect_name,
            'remaining_count': len(_active_effects)
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'REMOVE_EFFECT_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/clear', methods=['POST'])
def clear_effects():
    """
    POST /api/effects/clear
    Clear all effects from the chain
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    try:
        global _active_effects
        count = len(_active_effects)
        _active_effects = []
        
        return jsonify({
            'success': True,
            'message': 'All effects cleared',
            'cleared_count': count
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'CLEAR_EFFECTS_ERROR',
                'message': str(e)
            }
        }), 500


@bp.route('/chain', methods=['POST'])
def set_chain():
    """
    POST /api/effects/chain
    Set complete effect chain
    
    Status: ✅ IMPLEMENTED
    Tested: ⏳ Pending
    """
    global _effects_manager, _active_effects
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        effects_list = data.get('effects', [])
        
        if not isinstance(effects_list, list):
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_PARAMETER',
                    'message': 'effects must be a list'
                }
            }), 400
        
        if not _effects_manager:
            from ...effects import get_effects_manager
            _effects_manager = get_effects_manager()
        
        # Clear existing effects
        _active_effects = []
        
        # Create new chain
        created_effects = []
        for effect_data in effects_list:
            effect_name = effect_data.get('name')
            parameters = effect_data.get('parameters', {})
            enabled = effect_data.get('enabled', True)
            
            if not effect_name:
                continue
            
            # Create effect
            effect = _effects_manager.create_effect(effect_name)
            if not effect:
                continue
            
            # Set parameters
            for param_name, param_value in parameters.items():
                effect.set_parameter(param_name, param_value)
            
            # Enable if requested
            if enabled:
                effect.enable()
            
            _active_effects.append(effect)
            created_effects.append(effect_name)
        
        return jsonify({
            'success': True,
            'message': 'Effect chain set',
            'effects': created_effects,
            'count': len(created_effects)
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SET_CHAIN_ERROR',
                'message': str(e)
            }
        }), 500
