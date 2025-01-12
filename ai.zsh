#!/bin/zsh

# Module definition
typeset -g AICALL_CONFIG_FILE="$HOME/.config/aizsh.env"

# Define color variables as module-scoped
typeset -g AICALL_CYAN='\033[0;36m'
typeset -g AICALL_YELLOW='\033[1;33m'
typeset -g AICALL_GREEN='\033[0;32m'
typeset -g AICALL_BLUE='\033[0;34m'
typeset -g AICALL_NC='\033[0m'

# Helper function to format and print response
_aicall_format_response() {
    local response="$1"
    local term_width=$(tput cols)
    local block_num=0
    local in_block=false
    local temp_response=""
    local first_line_in_block=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^'```bash' ]]; then
            ((block_num++))
            in_block=true
            first_line_in_block=true
            continue
        elif [[ "$line" =~ ^'```'$ && "$in_block" == true ]]; then
            in_block=false
            first_line_in_block=false
            temp_response+="${AICALL_NC}\n"
            continue
        fi
        
        if [[ "$in_block" == true ]]; then
            if [[ "$first_line_in_block" == true ]]; then
                local line_length=${#line}
                local block_num_str=" [$block_num]"
                local padding_length=$((term_width - line_length - ${#block_num_str}))
                local padding=$(printf '%*s' $padding_length '')
                temp_response+="${AICALL_CYAN}${line}${padding}${AICALL_YELLOW}${block_num_str}${AICALL_NC}\n"
                first_line_in_block=false
            else
                temp_response+="${AICALL_CYAN}${line}${AICALL_NC}\n"
            fi
        else
            temp_response+="${line}\n"
        fi
    done < <(echo "$response")
    
    echo -e "$temp_response"
}

# Helper function to execute code block
_aicall_execute_block() {
    local block="$1"
    echo -e "\n${AICALL_BLUE}Executing:${AICALL_NC}"
    echo -e "${AICALL_CYAN}$block${AICALL_NC}"
    echo -e "${AICALL_BLUE}Output:${AICALL_NC}"
    eval "$block" 2>&1
    return $?
}

# Helper function to extract and validate code blocks
_aicall_extract_blocks() {
    local response="$1"
    local -a code_blocks
    local current_block=""
    local reading=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^'```bash' ]]; then
            reading=true
            current_block=""
            continue
        elif [[ "$line" =~ ^'```'$ && "$reading" == true ]]; then
            if [[ -n "$current_block" ]]; then
                local cleaned_block=$(echo "$current_block" | grep -v '^[[:space:]]*#' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                if [[ -n "$cleaned_block" ]]; then
                    if bash -n <(echo "$cleaned_block") 2>/dev/null; then
                        code_blocks+=("$cleaned_block")
                    fi
                fi
            fi
            reading=false
        elif [[ "$reading" == true ]]; then
            current_block+="$line"$'\n'
        fi
    done < <(echo "$response")
    
    echo "${(j:|:)code_blocks}"
}

# Main function that can be called from other modules
aicall() {
    # Check if config file exists
    [[ ! -f "$AICALL_CONFIG_FILE" ]] && { echo "Error: $AICALL_CONFIG_FILE not found"; return 1; }
    source "$AICALL_CONFIG_FILE"
    
    # Get system information
    local sys_info=$(cat <<EOF
OS: $(uname -s)
Kernel: $(uname -r)
Arch: $(uname -m)
CPU: $(grep -m 1 'model name' /proc/cpuinfo | cut -d ':' -f2 | xargs)
Mem: $(free -h | awk '/^Mem:/ {print $2}')
Distro: $([ -f /etc/os-release ] && grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')
EOF
)
    
    # Form system prompt
    local openrouter_system_prompt="You are a Linux system administrator assistant. Always include at most ONE code block in your responses, formatted as \`\`\`bash ... \`\`\`. Your output should be concise and practical. You are helping on the following system:

$sys_info"
    
    # Set prompt from argument
    local prompt="${1}"
    
    # Validate environment variables
    [[ -z "${OPENROUTER_API_KEY}" || -z "${OPENROUTER_MODEL}" ]] && {
        echo "Error: Set OPENROUTER_API_KEY and OPENROUTER_MODEL in $AICALL_CONFIG_FILE"
        return 1
    }
    
    echo
    echo 
    echo "Asking AI Assistant..."
    
    # Get AI response
    local response=$(jq -n \
      --arg model "$OPENROUTER_MODEL" \
      --arg system "$openrouter_system_prompt" \
      --arg prompt "$prompt" \
      '{
        model: $model,
        messages: [
          {role: "system", content: $system},
          {role: "user", content: $prompt}
        ]
      }' | curl -s "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
        -H "HTTP-Referer: http://localhost:3000" \
        -H "Content-Type: application/json" \
        -d @- | jq -r '.choices[0].message.content')
    
    # Format and print response
    _aicall_format_response "$response"
    
    # Extract and handle code blocks
    local IFS='|'
    local -a code_blocks=("${(@s:|:)$(_aicall_extract_blocks "$response")}")
    
    if [[ ${#code_blocks} -eq 0 ]]; then
        print ""
    elif [[ ${#code_blocks} -eq 1 ]]; then
        print "Execute? [y/N] "
        exec < /dev/tty
        read -r confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && _aicall_execute_block "${code_blocks[1]}"
    elif [[ ${#code_blocks} -le 9 ]]; then
        print  "Choose block (1-${#code_blocks}) or N: "
        exec < /dev/tty
        read -r choice
        [[ "$choice" =~ ^[1-9]$ && "$choice" -le "${#code_blocks}" ]] && _aicall_execute_block "${code_blocks[$choice]}"
    else
        print ""
    fi
}


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
		if [[ ${#BUFFER} -gt 3 ]]; then
            local prompt="${BUFFER}"
            special-mode-exit
            aicall "$prompt"
            zle .accept-line
		fi
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
	if [[ $SPECIAL_MODE -eq 0 && $BUFFER == "" && ${#PREBUFFER} -eq 0 ]]; then
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
	else
        # LBUFFER="${LBUFFER:0:-1}"
        zle $ORIG_BACKSPACE
    fi	
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
# print "Special mode initialized. Press ] to enter special mode."



