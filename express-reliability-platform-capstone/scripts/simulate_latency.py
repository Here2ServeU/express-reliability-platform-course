#!/usr/bin/env python3
"""Simulate elevated latency so the AIOps loop has a signal to detect."""
print("Simulating latency...")
print("p95 latency measured: 1200ms (SLO is 500ms)")
print("Feed this into AIOps:")
print("  python3 aiops/score_and_summarize.py --signal latency --service node-api --value 1200")
