#!/usr/bin/env bash
# A small website in git; the only change is a new colour and a reworded greeting.
set -e
git init -q -b main
git config user.name "Test"; git config user.email "test@example.com"
echo '<html><body><h1>Ming'"'"'s Coffee</h1><p>Welcome!</p></body></html>' > index.html
echo 'h1 { color: #333; }' > style.css
git add -A && git commit -qm "First version"
echo 'h1 { color: #6b4226; }' > style.css
echo '<html><body><h1>Ming'"'"'s Coffee</h1><p>Welcome, friend! Come in and stay a while.</p></body></html>' > index.html
