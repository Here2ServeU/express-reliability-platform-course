# AIOps Prediction and Remediation
print("AIOps is watching your app...")
problem = input("Type a problem (latency, 500 error, cpu, fail): ")
if problem == "latency":
    print("AIOps says: Latency detected! Try restarting the app.")
elif problem == "500 error":
    print("AIOps says: 500 error found! Check your code and restart.")
elif problem == "cpu":
    print("AIOps says: CPU/memory issue! Try clearing memory or restarting.")
elif problem == "fail":
    print("AIOps says: App failed! Try running the fix script.")
else:
    print("AIOps says: Everything looks good!")