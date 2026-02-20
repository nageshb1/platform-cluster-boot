#!/bin/bash
# Script to remove .terraform directory from Git history

echo "Removing .terraform directory from Git tracking..."
git rm -r --cached infra/.terraform 2>/dev/null || echo ".terraform not in index"

echo "Removing .terraform from Git history..."
# Use git filter-branch to remove from all commits
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch infra/.terraform" \
  --prune-empty --tag-name-filter cat -- --all

echo "Cleaning up..."
# Clean up refs
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "Done! You can now push with: git push origin --force --all"
echo "WARNING: This rewrites history. Make sure no one else is working on this repo."
