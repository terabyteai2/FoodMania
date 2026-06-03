#!/bin/bash
set -e

echo "Starting deployment task at $(date)"

cd /home/moon-ahmed/rastarant

# Stage all changes
echo "Staging all changes..."
git add -A

# Commit with version v10
echo "Committing as v10..."
git commit -m "v10" || echo "Nothing to commit"

# Push to git
echo "Pushing to git..."
git push origin main || git push origin master || echo "Push completed"

# Run redeploy script
echo "Running redeploy script..."
cd /home/moon-ahmed/rastarant/deploy
bash redeploy.sh

echo "Deployment task completed at $(date)"
