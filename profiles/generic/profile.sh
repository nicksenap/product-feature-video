# What a profile is. probe.sh writes one of these from a live page; this file documents the fields.
# Values are read by scene.sh. bsk observe lines look like: @e12 button "Send"
INPUT_SEL='textarea'                         # CSS: the chat input (probe: the focused element after clicking the textbox ref)
SEND_RE='@e[0-9]+ button "Send"'             # regex over `bsk observe` lines; '' = press Enter (probe: the button that enables when text is typed)
BUSY_JS="document.querySelector('[aria-busy=true]')?'streaming':'idle'"   # JS returning 'streaming' while the product works (probe: the signal present only while the answer streams)
# Approvals (write cards), optional. Either a ref regex + scroll JS (stable button label) ...
APPROVE_RE=''                                # e.g. '@e[0-9]+ button "Allow once'   (probe.sh approval proposes this)
APPROVE_SCROLL_JS=''                         # JS that scrolls the card's primary button to the centre before the click
# ... or a JS finder file when the primary button's label changes per action: (mode)=>{...}
#     mode 'scroll': scroll the card's primary button into view, return 'found' (or '' if no card)
#     mode 'click' : click it once, return its label. Remember clicked buttons (a WeakSet) so each card is approved once.
APPROVE_JS_FILE=''
TRANSCRIPT_JS="document.body.innerText"      # JS returning the visible transcript; scene.sh logs its tail when the turn ends
