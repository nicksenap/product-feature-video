# Claude.ai with an MCP connector. Sourced by scene.sh via PROFILE=claude.
INPUT_SEL='[contenteditable=true]'
SEND_RE=''                       # empty: press Enter in the textbox instead of clicking a send button
BUSY_JS="document.querySelector('[data-is-streaming=true]')?'streaming':'idle'"
APPROVE_RE='@e[0-9]+ button "Allow once'
APPROVE_SCROLL_JS="(()=>{const b=[...document.querySelectorAll('button')].find(x=>x.innerText.trim().startsWith('Allow once'));b&&b.scrollIntoView({block:'center',behavior:'smooth'});return !!b})()"
TRANSCRIPT_JS="document.body.innerText"
