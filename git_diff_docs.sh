#!/bin/bash

# git-doc-changes.sh - Document git changes using AI

source ./.env

# Configuration
API_KEY="${ANTHROPIC_API_KEY}"  # Set this environment variable
OUTPUT_FILE="changes_$(date +%Y%m%d_%H%M%S).md"
COMMIT_RANGE="${1:-HEAD~1..HEAD}"  # Default to last commit, or use provided range

echo -e "Documenting changes for: $COMMIT_RANGE${NC}"

# Get the git diff
echo "Getting git diff..."
DIFF_OUTPUT=$(git diff $COMMIT_RANGE)

if [ -z "$DIFF_OUTPUT" ]; then
    echo -e "${RED}No changes found for the specified range.${NC}"
    exit 1
fi

# Get commit messages for context
COMMIT_MESSAGES=$(git log --oneline $COMMIT_RANGE)

# Create the prompt for the AI
PROMPT="Please analyze the following git diff and create comprehensive documentation in markdown format.

Include:
- A summary of what changed
- Technical details of the changes
- Impact assessment
- Any potential concerns or notes

Commit messages for context:
$COMMIT_MESSAGES

Git diff:
\`\`\`diff
$DIFF_OUTPUT
\`\`\`"

echo "Sending to AI for analysis..."

# Call Anthropic Claude API
RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d "{
    \"model\": \"claude-opus-4-20250514\",
    \"max_tokens\": 4000,
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": $(echo "$PROMPT" | jq -R -s .)
      }
    ]
  }")

# Extract the content from the response
DOCUMENTATION=$(echo "$RESPONSE" | jq -r '.content[0].text // empty')

if [ -z "$DOCUMENTATION" ]; then
    echo -e "${RED}Error: Failed to get response from AI${NC}"
    echo "API Response: $RESPONSE"
    exit 1
fi

# Write to markdown file
cat > "$OUTPUT_FILE" << EOF
# Code Changes Documentation

**Generated:** $(date)
**Commit Range:** $COMMIT_RANGE
**Repository:** $(git remote get-url origin 2>/dev/null || echo "Local repository")

---

$DOCUMENTATION

---

## Raw Diff
\`\`\`diff
$DIFF_OUTPUT
\`\`\`
EOF

echo -e "${GREEN}Documentation saved to: $OUTPUT_FILE${NC}"
echo -e "${YELLOW}Preview:${NC}"
head -n 20 "$OUTPUT_FILE"