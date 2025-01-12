#!/bin/zsh

# Load config
CONFIG_FILE="$HOME/.config/aizsh.env"
[[ ! -f "$CONFIG_FILE" ]] && { echo "Error: $CONFIG_FILE not found"; exit 1; }
source "$CONFIG_FILE"

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Collect system info
SYS_INFO=$(cat <<EOF
OS: $(uname -s)
Kernel: $(uname -r)
Arch: $(uname -m)
CPU: $(grep -m 1 'model name' /proc/cpuinfo | cut -d ':' -f2 | xargs)
Mem: $(free -h | awk '/^Mem:/ {print $2}')
Distro: $([ -f /etc/os-release ] && grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')
EOF
)

# Form system prompt
OPENROUTER_SYSTEM_PROMPT="You are a Linux sysadmin assistant. Keep responses short. Include bash commands in \`\`\`bash ... \`\`\` blocks. Running on:

$SYS_INFO"

# Check env vars
export OPENROUTER_SYSTEM_PROMPT=${OPENROUTER_SYSTEM_PROMPT}
export PROMPT=${PROMPT:-"How to check disk usage?"}
[[ -z "${OPENROUTER_API_KEY}" || -z "${OPENROUTER_MODEL}" || -z "${PROMPT}" ]] && {
    echo "Error: Set OPENROUTER_API_KEY and OPENROUTER_MODEL in $CONFIG_FILE";
    exit 1;
}

# Get AI response
RESPONSE=$(jq -n \
  --arg model "$OPENROUTER_MODEL" \
  --arg system "$OPENROUTER_SYSTEM_PROMPT" \
  --arg prompt "$PROMPT" \
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

# Format and print response with colored code blocks
BLOCK_NUM=0
IN_BLOCK=false
TEMP_RESPONSE=""

while IFS= read -r line; do
    if [[ "$line" =~ ^'```bash' ]]; then
        BLOCK_NUM=$((BLOCK_NUM + 1))
        IN_BLOCK=true
        continue
    elif [[ "$line" =~ ^'```'$ && "$IN_BLOCK" == true ]]; then
        IN_BLOCK=false
        TEMP_RESPONSE+="${NC}\n"
        continue
    fi
    
    if [[ "$IN_BLOCK" == true ]]; then
        # For first line in block, add block number
        if [[ "$PREV_LINE" =~ ^'```bash' ]]; then
            TEMP_RESPONSE+="${CYAN}${line}${YELLOW} [${BLOCK_NUM}]${NC}\n"
        else
            TEMP_RESPONSE+="${CYAN}${line}${NC}\n"
        fi
    else
        TEMP_RESPONSE+="${line}\n"
    fi
    PREV_LINE="$line"
done < <(echo "$RESPONSE")

echo -e "$TEMP_RESPONSE"

# Extract and validate code blocks
declare -a CODE_BLOCKS
CURRENT_BLOCK=""
READING=false

while IFS= read -r line; do
    if [[ "$line" =~ ^'```bash' ]]; then
        READING=true
        CURRENT_BLOCK=""
        continue
    elif [[ "$line" =~ ^'```'$ && "$READING" == true ]]; then
        if [[ -n "$CURRENT_BLOCK" ]]; then
            # Remove whitespace and comments
            CLEANED_BLOCK=$(echo "$CURRENT_BLOCK" | grep -v '^[[:space:]]*#' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [[ -n "$CLEANED_BLOCK" ]]; then
                if bash -n <(echo "$CLEANED_BLOCK") 2>/dev/null; then
                    CODE_BLOCKS+=("$CLEANED_BLOCK")
                fi
            fi
        fi
        READING=false
    elif [[ "$READING" == true ]]; then
        CURRENT_BLOCK+="$line"$'\n'
    fi
done < <(echo "$RESPONSE")

# Execute code block if valid
execute_block() {
    local block="$1"
    echo -e "\n${BLUE}Executing:${NC}"
    echo -e "${CYAN}$block${NC}"
    echo -e "${BLUE}Output:${NC}"
    eval "$block" 2>&1
    return $?
}

if [[ ${#CODE_BLOCKS[@]} -eq 0 ]]; then
    echo -e "\nNo executable code blocks found"
elif [[ ${#CODE_BLOCKS[@]} -eq 1 ]]; then
    echo -e "\nExecute? [y/N] "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        execute_block "${CODE_BLOCKS[0]}"
    fi
elif [[ ${#CODE_BLOCKS[@]} -le 9 ]]; then
    echo -e "\nChoose block (1-${#CODE_BLOCKS[@]}) or N: "
    read -r CHOICE
    if [[ "$CHOICE" =~ ^[1-9]$ ]] && [ "$CHOICE" -le "${#CODE_BLOCKS[@]}" ]; then
        execute_block "${CODE_BLOCKS[$CHOICE-1]}"
    fi
else
    echo -e "\nToo many code blocks"
fi