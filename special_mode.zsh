# Enable zle
zmodload zsh/zle

# Special mode flag
typeset -g SPECIAL_MODE=0

# Save original widget
typeset -g ORIG_BACKSPACE=$(bindkey '^?' | awk '{print $2}')

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
	print -n "\r\033[K"
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

# Function to handle backspace
function special-mode-backspace() {
	if [[ ${#BUFFER} -eq 0 ]]; then
		special-mode-exit
		return
	fi
	# Handle backspace in special mode
	BUFFER="${BUFFER:0:-1}"
	if [[ ${#BUFFER} -eq 0 ]]; then
		special-mode-exit
		return
	fi
	print -n "\r\033[K✨ $BUFFER"
}

# Function to handle normal backspace
function normal-backspace() {
	if [[ $SPECIAL_MODE -eq 1 ]]; then
		special-mode-backspace
	else
		# Use original widget in normal mode
		zle $ORIG_BACKSPACE
	fi
}


# Create widgets
zle -N special-mode-handler
zle -N special-mode-interrupt
zle -N special-mode-trigger
zle -N normal-backspace

# Bind keys

bindkey '^M' special-mode-handler
bindkey '^C' special-mode-interrupt
bindkey ']' special-mode-trigger
bindkey '^?' normal-backspace
bindkey '^H' normal-backspace

# Print initialization message
print "Special mode initialized. Press ] to enter special mode."



