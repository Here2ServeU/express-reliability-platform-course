#!/bin/bash
echo '========================================='
echo '  Version 1 Cleanup Starting...'
echo '========================================='

# Step 1: Kill any process still using port 3000
echo 'Stopping any server on port 3000...'
lsof -ti:3000 | xargs kill -9 2>/dev/null || echo 'No server running on port 3000'

# Step 2: Remove downloaded packages
echo 'Removing node_modules folder...'
rm -rf node_modules
echo 'node_modules removed.'

# Step 3: Verify the server is really stopped
echo 'Verifying cleanup...'
curl -s http://localhost:3000/health > /dev/null \
  && echo 'WARNING: Server still responding on port 3000!' \
  || echo 'CONFIRMED: Server is fully stopped.'

echo '========================================='
echo '  Version 1 Cleanup Complete!'
echo '========================================='
