"""
Effects Manager for LenzForge backend v2

Central registry and management system for all effects.
"""
from typing import Dict, List, Type, Optional
from .base import Effect, EffectChain

# Import all effect classes
from .blur import (
    GaussianBlurEffect, MotionBlurEffect, RadialBlurEffect,
    BoxBlurEffect, BilateralFilterEffect, MedianBlurEffect
)
from .edge_detection import (
    CannyEdgeEffect, SobelEdgeEffect, LaplacianEdgeEffect, ScharrEdgeEffect
)
from .color import (
    BrightnessContrastEffect, HSVAdjustmentEffect, ColorBalanceEffect,
    LevelsEffect, TemperatureTintEffect, CurvesEffect
)
from .filters import (
    SharpenEffect, UnsharpMaskEffect, DenoiseEffect,
    EmbossEffect, FindEdgesEffect
)
from .stylize import (
    PosterizeEffect, QuantizeEffect, OilPaintingEffect,
    CartoonEffect, PencilSketchEffect, StylizationEffect
)
from .morphological import (
    ErodeDilateEffect, OpenCloseEffect,
    MorphologicalGradientEffect, TopHatBlackHatEffect
)
from .background import (
    BackgroundBlurEffect, BackgroundReplaceEffect,
    VirtualBackgroundEffect, GreenScreenEffect
)
from .transform import (
    RotateEffect, FlipEffect, PerspectiveEffect, WarpEffect
)
from .face import (
    BeautyModeEffect, FaceReshapeEffect, MakeupEffect
)
from .advanced import (
    HDREffect, ColorGradingEffect, FilmGrainEffect,
    VignetteEffect, ChromaticAberrationEffect
)


class EffectsManager:
    """
    Central effects registry and management system
    
    Provides:
    - Effect registration and discovery
    - Effect creation by name
    - Category organization
    - Effect introspection
    """
    
    def __init__(self):
        self._effects_registry: Dict[str, Type[Effect]] = {}
        self._categories: Dict[str, List[str]] = {}
        self._register_all_effects()
    
    def _register_all_effects(self):
        """Register all available effects"""
        
        # Blur effects
        self._register(GaussianBlurEffect)
        self._register(MotionBlurEffect)
        self._register(RadialBlurEffect)
        self._register(BoxBlurEffect)
        self._register(BilateralFilterEffect)
        self._register(MedianBlurEffect)
        
        # Edge detection effects
        self._register(CannyEdgeEffect)
        self._register(SobelEdgeEffect)
        self._register(LaplacianEdgeEffect)
        self._register(ScharrEdgeEffect)
        
        # Color effects
        self._register(BrightnessContrastEffect)
        self._register(HSVAdjustmentEffect)
        self._register(ColorBalanceEffect)
        self._register(LevelsEffect)
        self._register(TemperatureTintEffect)
        self._register(CurvesEffect)
        
        # Filter effects
        self._register(SharpenEffect)
        self._register(UnsharpMaskEffect)
        self._register(DenoiseEffect)
        self._register(EmbossEffect)
        self._register(FindEdgesEffect)
        
        # Stylize effects
        self._register(PosterizeEffect)
        self._register(QuantizeEffect)
        self._register(OilPaintingEffect)
        self._register(CartoonEffect)
        self._register(PencilSketchEffect)
        self._register(StylizationEffect)
        
        # Morphological effects
        self._register(ErodeDilateEffect)
        self._register(OpenCloseEffect)
        self._register(MorphologicalGradientEffect)
        self._register(TopHatBlackHatEffect)
        
        # Background effects
        self._register(BackgroundBlurEffect)
        self._register(BackgroundReplaceEffect)
        self._register(VirtualBackgroundEffect)
        self._register(GreenScreenEffect)
        
        # Transform effects
        self._register(RotateEffect)
        self._register(FlipEffect)
        self._register(PerspectiveEffect)
        self._register(WarpEffect)
        
        # Face effects
        self._register(BeautyModeEffect)
        self._register(FaceReshapeEffect)
        self._register(MakeupEffect)
        
        # Advanced effects
        self._register(HDREffect)
        self._register(ColorGradingEffect)
        self._register(FilmGrainEffect)
        self._register(VignetteEffect)
        self._register(ChromaticAberrationEffect)
    
    def _register(self, effect_class: Type[Effect]):
        """Register an effect class"""
        name = effect_class.get_name()
        category = effect_class.get_category()
        
        self._effects_registry[name] = effect_class
        
        if category not in self._categories:
            self._categories[category] = []
        self._categories[category].append(name)
    
    def create_effect(self, name: str) -> Optional[Effect]:
        """
        Create an effect instance by name
        
        Args:
            name: Effect class name
        
        Returns:
            Effect instance or None if not found
        """
        effect_class = self._effects_registry.get(name)
        if effect_class:
            return effect_class()
        return None
    
    def get_all_effects(self) -> List[str]:
        """Get list of all registered effect names"""
        return list(self._effects_registry.keys())
    
    def get_effects_by_category(self, category: str) -> List[str]:
        """Get list of effect names in a category"""
        return self._categories.get(category, [])
    
    def get_categories(self) -> List[str]:
        """Get list of all categories"""
        return list(self._categories.keys())
    
    def get_effect_info(self, name: str) -> Optional[Dict]:
        """
        Get information about an effect
        
        Returns dict with:
        - name: Effect name
        - category: Effect category
        - description: Effect description
        - parameters: Parameter information
        """
        effect_class = self._effects_registry.get(name)
        if not effect_class:
            return None
        
        # Create temporary instance to get parameters
        effect = effect_class()
        
        return {
            'name': effect_class.get_name(),
            'category': effect_class.get_category(),
            'description': effect_class.get_description(),
            'parameters': effect.get_parameters_info()
        }
    
    def get_all_effects_info(self) -> Dict[str, Dict]:
        """Get information about all effects organized by category"""
        info = {}
        
        for category in self.get_categories():
            info[category] = {}
            for effect_name in self.get_effects_by_category(category):
                info[category][effect_name] = self.get_effect_info(effect_name)
        
        return info
    
    def create_effect_chain(self, effect_names: List[str]) -> EffectChain:
        """
        Create an effect chain from a list of effect names
        
        Args:
            effect_names: List of effect names to chain
        
        Returns:
            EffectChain with created effects
        """
        chain = EffectChain()
        
        for name in effect_names:
            effect = self.create_effect(name)
            if effect:
                chain.add_effect(effect)
        
        return chain
    
    def get_statistics(self) -> Dict:
        """Get statistics about registered effects"""
        total_effects = len(self._effects_registry)
        total_params = 0
        
        for effect_name in self._effects_registry.keys():
            effect = self.create_effect(effect_name)
            if effect:
                total_params += len(effect.get_parameters_info())
        
        return {
            'total_effects': total_effects,
            'total_parameters': total_params,
            'categories': len(self._categories),
            'effects_per_category': {
                cat: len(effects) for cat, effects in self._categories.items()
            }
        }


# Global effects manager instance
_effects_manager: Optional[EffectsManager] = None


def get_effects_manager() -> EffectsManager:
    """Get global effects manager instance"""
    global _effects_manager
    if _effects_manager is None:
        _effects_manager = EffectsManager()
    return _effects_manager
