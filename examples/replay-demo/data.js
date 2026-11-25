window.WHATDID = {
  "lang": "en",
  "title": "Added a Contact Us page to the coffee shop site, plus a few setting tweaks and one risky change around a secret key",
  "project": "demo-site",
  "source": "session",
  "stats": { "files": 7, "added": 8, "removed": 5 },
  "steps": [
    { "action": "read", "zone": "rooms", "target": "index.html", "note": "Looked at the home page first" },
    { "action": "create", "zone": "rooms", "target": "pages/contact.html", "note": "New Contact Us page with a name + message form", "added": 4, "removed": 0, "risk": "medium", "why": "It contacts an outside website as soon as the page opens" },
    { "action": "edit", "zone": "rooms", "target": "index.html", "note": "Added a Contact Us link to the home page menu", "added": 1, "removed": 1 },
    { "action": "edit", "zone": "decor", "target": "css/style.css", "note": "Text size bumped from 14px to 16px", "added": 1, "removed": 1 },
    { "action": "edit", "zone": "wiring", "target": "config.json", "note": "Changed the port 3000 → 8080", "added": 1, "removed": 1, "risk": "medium", "why": "The site now opens at a different address" },
    { "action": "run", "zone": "wiring", "target": "npm install", "note": "Installed the add-ons the project needs" },
    { "action": "delete", "zone": "decor", "target": "css/print.css", "note": "Removed a style file nothing used any more", "removed": 12 },
    { "action": "create", "zone": "foundation", "target": ".env", "note": "New file holding what looks like a secret key (value hidden)", "added": 1, "removed": 0, "risk": "high", "why": "A secret key now sits in your project and could be uploaded" },
    { "action": "edit", "zone": "foundation", "target": ".gitignore", "note": "Removed the rule that kept .env from being uploaded", "added": 0, "removed": 1, "risk": "high", "why": "Your secret key file will be uploaded to GitHub with everything else" },
    { "action": "delete", "zone": "yard", "target": "docs/old-promo.txt", "note": "Deleted the old promo notes", "removed": 1, "risk": "high", "why": "You didn't ask for this, and the file is gone" }
  ],
  "risks": [
    { "level": "high", "text": ".env holds a secret key and is no longer ignored, so it may get uploaded" },
    { "level": "high", "text": "Deleted old-promo.txt (old promo notes)" },
    { "level": "medium", "text": "Port changed 3000 → 8080: the site address changes" },
    { "level": "medium", "text": "Contact page connects to api.example-mail.com as soon as it opens" }
  ],
  "check": "Open index.html → click Contact → you should see a form with name and message boxes",
  "undo": { "command": "git stash -u" }
};
