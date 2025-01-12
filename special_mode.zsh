# Enable zle
zmodload zsh/zle

# Special mode flag
typeset -g SPECIAL_MODE=0

# Function to enter special mode
function special-mode-enter() {
	SPECIAL_MODE=1
	BUFFER=""
	print -n "\r\033[K✨ "
}

# Function to exit special mode
function special-mode-exit() {
	SPECIAL_MODE=0
	BUFFER=""
	zle reset-prompt
}

# Function to handle input
function special-mode-handler() {
	if [[ $SPECIAL_MODE -eq 1 ]]; then
		if [[ -z $BUFFER ]]; then
			special-mode-exit
			return
		fi
		print -r -- "$BUFFER"
		BUFFER=""
		special-mode-exit
	else
		zle .accept-line
	fi
}

# Function to handle Ctrl+C
function special-mode-interrupt() {
	if [[ $SPECIAL_MODE -eq 1 ]]; then
		special-mode-exit
	else
		zle .send-break
	fi
}

# Function to handle ] key
function special-mode-trigger() {
	if [[ $SPECIAL_MODE -eq 0 && $BUFFER == "" ]]; then
		special-mode-enter
	else
		LBUFFER+=$KEYS
	fi
}

# Create widgets
zle -N special-mode-handler
zle -N special-mode-interrupt
zle -N special-mode-trigger

# Bind keys
bindkey '^M' special-mode-handler
bindkey '^C' special-mode-interrupt
bindkey ']' special-mode-trigger

# Print initialization message
print "Special mode initialized. Press ] to enter special mode."



