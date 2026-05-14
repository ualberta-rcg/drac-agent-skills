#!/bin/bash

SETTINGS=/etc/claude-code/managed-settings.json
TMPFILE=$(mktemp)

messages=(
  "Greetings, Professor Falken. Would you like to play a game?"
  "Good morning, Dave. I am completely operational and all my circuits are functioning perfectly."
  "I'm sorry Dave, I'm afraid I can't do that."
  "All of this has happened before, and all of it will happen again."
  "By your command."
  "The Belt remembers."
  "Do or do not. There is no try."
  "I find your lack of faith disturbing."
  "These aren't the droids you're looking for."
  "Don't Panic."
  "A towel is about the most massively useful thing an interstellar hitchhiker can have."
  "In the beginning the Universe was created. This has made a lot of people very angry and been widely regarded as a bad move."
  "Your culture will adapt to service us."
  "Number 5 is alive."
  "Danger, Will Robinson!"
  "Please state the nature of the medical emergency."
  "From this time forward, you will service us."
  "The spice must flow."
  "Big Brother is watching you."
  "War is peace. Freedom is slavery. Ignorance is strength."
  "Unfortunately, no one can be told what the Matrix is."
  "There is no spoon."
  "Follow the white rabbit."
  "I'll be back."
  "Come with me if you want to live."
  "The truth is out there."
  "I want to believe." 
  "Michael, that is not advisable."
  "There are no strings on me."
  "You have twenty seconds to comply."
  "I'd buy that for a dollar."
  "I fight for the users."
  "Good news, everyone!"
  "Might I suggest something less destructive?"
  "At your service, sir."
  "I can help you, but you have to do exactly as I say."
  "My program forbids me from harming the Umbrella Corporation."
  "Great Scott!"
  "Never tell me the odds."
  "Nobody calls me chicken."
  "Can't stop the signal."
  "No power in the 'verse can stop me."
  "Ziggy says there's a 97.2 percent probability."
  "Sometimes you gotta run before you can walk."
)

quote="${messages[$RANDOM % ${#messages[@]}]}"

# Use python to safely update the JSON
python3 - << PYEOF
import json

with open('$SETTINGS') as f:
    settings = json.load(f)

settings['companyAnnouncements'] = ["$quote"]

with open('$TMPFILE', 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF

# Atomic replace
mv "$TMPFILE" "$SETTINGS"
chmod 644 "$SETTINGS"
chown root:root "$SETTINGS"
