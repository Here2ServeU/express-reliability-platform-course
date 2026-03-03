# Check SLOs and SLIs
print("Checking if your app is healthy...")
slo = int(input("What is your SLO (goal, like 99)? "))
sli = int(input("What is your SLI (actual, like 95)? "))
if sli >= slo:
    print("Great! Your app is meeting its goal.")
else:
    print("Uh oh! Your app is not meeting its goal. Time to fix it!")