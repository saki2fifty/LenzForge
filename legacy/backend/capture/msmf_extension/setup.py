"""
Setup script for MSMF Camera Capture Python Extension
Builds msmf_capture.pyd for Windows
"""
import sys
import os
from pathlib import Path
from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext

class get_pybind_include:
    """Helper class to determine pybind11 include path"""
    def __str__(self):
        import pybind11
        return pybind11.get_include()

class get_python_include:
    """Helper class to determine Python include path"""
    def __str__(self):
        import sysconfig
        return sysconfig.get_path('include')

# Extension module
ext_modules = [
    Extension(
        'msmf_capture',
        sources=['msmf_capture.cpp'],
        include_dirs=[
            get_pybind_include(),
            get_python_include(),  # Add Python include directory
        ],
        libraries=[
            'mfplat',
            'mf',
            'mfreadwrite',
            'mfuuid',
            'propsys',
            'ole32',      # COM functions (CoInitializeEx, CoTaskMemFree, etc.)
            'oleaut32',   # For _com_error
        ],
        language='c++',
        define_macros=[
            ('UNICODE', None),
            ('_UNICODE', None),
        ],
    ),
]

# Custom build_ext to set C++17 with compiler detection
class BuildExt(build_ext):
    def build_extensions(self):
        # Detect compiler and use appropriate flags
        compiler_type = self.compiler.compiler_type
        
        for ext in self.extensions:
            if compiler_type == 'msvc':
                # MSVC (Visual Studio) flags
                ext.extra_compile_args = ['/std:c++17', '/EHsc']
            elif compiler_type == 'mingw32':
                # MinGW (GCC) flags
                ext.extra_compile_args = ['-std=c++17']
                ext.extra_link_args = ['-static-libgcc', '-static-libstdc++']
            else:
                # Generic GCC flags
                ext.extra_compile_args = ['-std=c++17']
        
        build_ext.build_extensions(self)

setup(
    name='msmf_capture',
    version='1.0.0',
    author='LenzForge',
    description='MSMF Camera Capture - Pure Media Foundation',
    long_description='Python extension for camera capture using Microsoft Media Foundation (MSMF). No DirectShow.',
    ext_modules=ext_modules,
    install_requires=['pybind11>=2.6.0', 'numpy'],
    cmdclass={'build_ext': BuildExt},
    zip_safe=False,
    python_requires='>=3.7',
)
