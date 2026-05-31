#!/usr/bin/env python3
"""Simulate an elevated 5xx error rate so the AIOps loop has a signal to detect."""
print("Simulating 500 errors...")
print("5xx error rate measured: 0.08 (SLO is 0.05)")
print("Feed this into AIOps:")
print("  python3 aiops/score_and_summarize.py --signal error_rate --service flask-api --value 0.08")
