# PowerShell script to remove .terraform directory from Git history

Write-Host "Removing .terraform directory from Git tracking..." -ForegroundColor Yellow
git rm -r --cached infra/.terraform 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host ".terraform not in index or already removed" -ForegroundColor Gray
}

Write-Host "Removing .terraform from Git history..." -ForegroundColor Yellow
# Use git filter-branch to remove from all commits
git filter-branch --force --index-filter "git rm -rf --cached --ignore-unmatch infra/.terraform" --prune-empty --tag-name-filter cat -- --all

Write-Host "Cleaning up..." -ForegroundColor Yellow
# Clean up refs
Remove-Item -Recurse -Force .git/refs/original/ -ErrorAction SilentlyContinue
git reflog expire --expire=now --all
git gc --prune=now --aggressive

Write-Host "`nDone! You can now push with: git push origin --force --all" -ForegroundColor Green
Write-Host "WARNING: This rewrites history. Make sure no one else is working on this repo." -ForegroundColor Red
