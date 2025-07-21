"""Convenience wrapper to run the CLI with python validate.py."""

from __future__ import annotations

import sys
from pathlib import Path

# Ensure the src directory is on the path when executed from repo root
sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))

from cli import main

if __name__ == "__main__":
    main()
