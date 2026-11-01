# Lovable project editor (lovable.dev/projects/<id>): chat on the left, live app preview on the right.
# Probed with bsk observe + one Chat-mode turn. Switch the mode button (Build / Chat / Plan) before recording.
INPUT_SEL='[contenteditable=true][aria-label="Ask Lovable..."], [contenteditable=true]'
SEND_RE='@e[0-9]+ button "Send message"'
BUSY_JS="[...document.querySelectorAll('button')].some(b=>/Stop generating/.test((b.getAttribute('aria-label')||'')+b.innerText))?'streaming':'idle'"
# Build and Chat modes have no approval cards. Plan mode ends with an "Implement the plan" button; set APPROVE_RE to it for a demo with an approval beat.
APPROVE_RE=''
APPROVE_SCROLL_JS=''
APPROVE_JS_FILE=''
TRANSCRIPT_JS="(document.querySelector('[role=log]')||document.querySelector('main')||document.body).innerText"
