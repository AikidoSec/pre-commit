from setuptools import setup

setup(
    name="aikido-local-scanner-hook",
    version="1.0.0",
    py_modules=["aikido_local_scanner_wrapper"],
    entry_points={
        "console_scripts": [
            "aikido_local_scanner_wrapper=aikido_local_scanner_wrapper:main",
        ],
    }
)