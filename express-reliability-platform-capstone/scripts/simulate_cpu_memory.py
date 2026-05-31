#!/usr/bin/env python3
"""Simulate CPU/memory saturation so the AIOps loop has a signal to detect."""
print("Simulating CPU/memory saturation...")
print("CPU saturation measured: 0.92 (SLO is 0.85)")
print("Feed this into AIOps:")
print("  python3 aiops/score_and_summarize.py --signal cpu --service node-api --value 0.92")
