# Template for a new product. Copy this directory, fill in the four selectors, drop a logo + fonts in assets/.
# How the recorder finds things on the page (bsk snapshot refs look like: @e12 button "Send").
INPUT_SEL='textarea'                         # CSS: the chat/prompt input
SEND_RE='@e[0-9]+ button "Send"'             # regex over `bsk observe` lines; '' = press Enter instead
BUSY_JS="document.querySelector('[aria-busy=true]')?'streaming':'idle'"   # JS returning 'streaming' while the product works
# Optional approvals (write cards). Either a ref regex + scroll JS (Claude style) ...
APPROVE_RE=''
APPROVE_SCROLL_JS=''
# ... or a JS finder file exporting (mode)=>... that scrolls/clicks the card's primary button (see the Claude profile for the regex style; a JS finder suits cards without a stable label).
APPROVE_JS_FILE=''
TRANSCRIPT_JS="document.body.innerText"      # JS returning the visible transcript, for 'turn finished' checks
