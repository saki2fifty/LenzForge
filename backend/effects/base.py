"""
Base effect classes for LenzForge backend v2

Provides abstract base classes for image effects.
"""
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional
from dataclasses import dataclass
import numpy as np


@dataclass
class EffectParameter:
    """Effect parameter definition"""
    name: str
    type: type
    default: Any
    min_value: Optional[Any] = None
    max_value: Optional[Any] = None
    description: str = ""

    def validate(self, value: Any) -> bool:
        """Validate parameter value"""
        if not isinstance(value, self.type):
            return False

        if self.min_value is not None and value < self.min_value:
            return False

        if self.max_value is not None and value > self.max_value:
            return False

        return True


class Effect(ABC):
    """
    Base class for all effects

    Effects process frames and can be enabled/disabled.
    Each effect exposes parameters that can be adjusted.
    """

    def __init__(self):
        self.enabled = False
        self._parameters: Dict[str, EffectParameter] = {}
        self._values: Dict[str, Any] = {}
        self._register_parameters()

    @abstractmethod
    def _register_parameters(self):
        """Register effect parameters (override in subclass)"""
        pass

    @abstractmethod
    def apply(self, frame: np.ndarray) -> np.ndarray:
        """
        Apply effect to frame

        Args:
            frame: Input frame (BGR format)

        Returns:
            Processed frame (BGR format)
        """
        pass

    def _add_parameter(
        self,
        name: str,
        param_type: type,
        default: Any,
        min_val: Optional[Any] = None,
        max_val: Optional[Any] = None,
        description: str = ""
    ):
        """Add a parameter to this effect"""
        param = EffectParameter(
            name=name,
            type=param_type,
            default=default,
            min_value=min_val,
            max_value=max_val,
            description=description
        )
        self._parameters[name] = param
        self._values[name] = default

    def get_parameter(self, name: str) -> Any:
        """Get parameter value"""
        return self._values.get(name)

    def set_parameter(self, name: str, value: Any) -> bool:
        """
        Set parameter value

        Returns:
            True if value was valid and set
        """
        if name not in self._parameters:
            return False

        param = self._parameters[name]
        if not param.validate(value):
            return False

        self._values[name] = value
        return True

    def get_parameters_info(self) -> Dict[str, Dict[str, Any]]:
        """Get information about all parameters"""
        info = {}
        for name, param in self._parameters.items():
            info[name] = {
                'type': param.type.__name__,
                'default': param.default,
                'current': self._values[name],
                'min': param.min_value,
                'max': param.max_value,
                'description': param.description
            }
        return info

    def enable(self):
        """Enable this effect"""
        self.enabled = True

    def disable(self):
        """Disable this effect"""
        self.enabled = False

    def is_enabled(self) -> bool:
        """Check if effect is enabled"""
        return self.enabled

    def reset(self):
        """Reset all parameters to defaults"""
        for name, param in self._parameters.items():
            self._values[name] = param.default

    @classmethod
    def get_name(cls) -> str:
        """Get effect name"""
        return cls.__name__

    @classmethod
    def get_category(cls) -> str:
        """Get effect category (override in subclass)"""
        return "General"

    @classmethod
    def get_description(cls) -> str:
        """Get effect description (override in subclass)"""
        return ""


class EffectChain:
    """
    Chain of effects applied in sequence

    Manages multiple effects and applies them in order.
    """

    def __init__(self):
        self.effects: list[Effect] = []

    def add_effect(self, effect: Effect):
        """Add effect to chain"""
        self.effects.append(effect)

    def remove_effect(self, effect: Effect):
        """Remove effect from chain"""
        if effect in self.effects:
            self.effects.remove(effect)

    def clear(self):
        """Remove all effects"""
        self.effects.clear()

    def apply(self, frame: np.ndarray) -> np.ndarray:
        """
        Apply all enabled effects in sequence

        Args:
            frame: Input frame

        Returns:
            Processed frame
        """
        result = frame.copy()

        for effect in self.effects:
            if effect.is_enabled():
                result = effect.apply(result)

        return result

    def get_enabled_effects(self) -> list[Effect]:
        """Get list of enabled effects"""
        return [e for e in self.effects if e.is_enabled()]

    def get_effect_by_name(self, name: str) -> Optional[Effect]:
        """Get effect by class name"""
        for effect in self.effects:
            if effect.get_name() == name:
                return effect
        return None
