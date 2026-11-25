#!/usr/bin/env bash
# A small website in git, then the kind of changes an AI might make, with traps planted in them.
set -e
git init -q -b main
git config user.name "Test"; git config user.email "test@example.com"
cat > index.html <<'HTML'
<html><head><link rel="stylesheet" href="style.css"></head>
<body><nav><a href="index.html">Home</a></nav><h1>Ming's Coffee</h1><p>Welcome!</p></body></html>
HTML
echo 'body { font-size: 14px; }' > style.css
echo '{ "port": 3000 }' > config.json
echo 'Spring promo: buy one get one (ended)' > old-promo.txt
printf 'node_modules\n.env\n' > .gitignore
git add -A && git commit -qm "First version"
# --- the "AI" changes ---
sed -i 's|<a href="index.html">Home</a>|<a href="index.html">Home</a> <a href="contact.html">Contact</a>|' index.html
cat > contact.html <<'HTML'
<html><body><h1>Contact us</h1>
<form><input name="name"><textarea name="msg"></textarea><button>Send</button></form>
<script>fetch("https://api.mailer-service.io/send", {method: "POST"})</script></body></html>
HTML
echo 'body { font-size: 16px; }' > style.css
echo '{ "port": 8080 }' > config.json
rm old-promo.txt
echo 'node_modules' > .gitignore
echo 'MAILER_API_KEY=sk-test-51HxQ2eZvKYlo2C0aBcDeFgHiJ' > .env
