# Snowflake Cortex Agents with Slack Integration ❄️

> A Slack bot powered by Snowflake Cortex Agents that provides intelligent responses using natural language processing and real-time data analysis.

## Overview

This project integrates [Snowflake Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents) with Slack using the [Bolt for Python framework](https://slack.dev/bolt-python/). The bot can:

- Respond to messages with AI-powered insights from Snowflake Cortex
- Handle both new messages and message edits seamlessly
- Provide real-time streaming responses
- Execute data queries and visualizations
- Search through Snowflake documentation and support tickets

Based on the [Snowflake Cortex Agents Slack Quickstart](https://github.com/Snowflake-Labs/sfguide-integrate-snowflake-cortex-agents-with-slack). For detailed step-by-step setup instructions, see the [official quickstart guide](https://quickstarts.snowflake.com/guide/integrate_snowflake_cortex_agents_with_slack/index.html).

## Major Changes from Original Quickstart

### 1. **Enhanced Message Handling** 🔄

The `app.py` has been updated to handle both regular messages and edited messages:

- **Regular messages**: Processed normally from `event['text']`
- **Edited messages** (`message_changed` events): Extracted from `event['message']['text']`
- **Bot message filtering**: Prevents infinite loops by ignoring bot-generated messages
- **Empty message validation**: Skips processing for messages without text content

```python
@app.event("message")
def handle_message_events(ack, body, say):
    event = body.get('event', {})
    
    # Skip bot messages to avoid loops
    if event.get('bot_id') or event.get('subtype') == 'bot_message':
        return
    
    # Handle different message subtypes
    if event.get('subtype') == 'message_changed':
        # For edited messages, get text from message object
        prompt = event.get('message', {}).get('text', '')
    else:
        # For regular messages, get text directly
        prompt = event.get('text', '')
```

### 2. **Modern Dependency Management with `uv`** ⚡️

Switched from traditional `pip` to [`uv`](https://github.com/astral-sh/uv) for faster and more reliable dependency management:

- **10-100x faster** than pip
- **Better dependency resolution**
- **Managed via `pyproject.toml`** for modern Python dependency management

## Prerequisites

- Python 3.13+
- Slack workspace with admin access
- Snowflake account with Cortex enabled
- [uv](https://github.com/astral-sh/uv) package manager

## Setup Instructions

### 1. Install `uv` Package Manager

```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or via pip
pip install uv
```

### 2. Clone and Setup Project

```bash
# Clone this repository
git clone <your-repo-url>
cd first-bolt-app

# Create virtual environment using uv with Python 3.13
uv venv --python 3.13 .venv

# Activate the virtual environment
source .venv/bin/activate

# Install dependencies using uv sync (reads from pyproject.toml)
uv sync
```

### 3. Configure Slack App

You can set up your Slack app using either the **Slack CLI** (recommended) or manually through the **web interface**.

#### Option A: Using Slack CLI (Recommended)

Follow the [official Bolt for Python quickstart guide](https://docs.slack.dev/tools/bolt-python/getting-started/) for the smoothest setup experience.

1. **Install Slack CLI** (if not already installed):
   ```bash
   # macOS & Linux
   curl -fsSL https://downloads.slack-edge.com/slack-cli/install.sh | bash
   
   # Windows - download from Slack
   ```

2. **Authenticate with Slack**:
   ```bash
   slack login
   ```

3. **Create/configure the app** using the included `manifest.json`:
   ```bash
   slack run
   ```
   
   Select "Create a new app" when prompted and choose your workspace.

The Slack CLI will automatically:
- Create the app with proper scopes and settings
- Generate app tokens
- Set up Socket Mode
- Handle authentication

#### Option B: Manual Setup via Web Interface

If you prefer to set up manually:

1. Create a new Slack app at [api.slack.com/apps](https://api.slack.com/apps)
2. Use the `manifest.json` file in this project or configure manually:
   - Enable **Socket Mode** and generate an **App-Level Token** with `connections:write` scope
   - Add **Bot Token Scopes**:
     - `app_mentions:read`
     - `channels:history`
     - `channels:read`
     - `chat:write`
     - `im:history`
     - `im:read`
     - `im:write`
   - Subscribe to **Event Subscriptions**:
     - `app_mention`
     - `message.channels`
     - `message.im`
3. Install the app to your workspace
4. Save the tokens as environment variables (see step 5 below)

### 4. Configure Snowflake

Follow the [Snowflake setup instructions](https://quickstarts.snowflake.com/guide/integrate_snowflake_cortex_agents_with_slack/index.html#2) from the official quickstart guide.

**Quick Setup:**

1. **Run setup SQL** to create database, schema, tables, and load data:
   ```sql
   -- Execute setup.sql in Snowsight
   -- This creates DASH_AGENT_SLACK database and loads sample data
   ```

2. **Upload semantic model and PDF documents**:
   - Upload `support_tickets_semantic_model.yaml` to `DASH_AGENT_SLACK.DATA.SEMANTIC_MODELS` stage
   - Upload PDF files from `data/` folder to `DASH_AGENT_SLACK.DATA.PDFS` stage
   - These files enable Cortex Analyst and Cortex Search capabilities

3. **Create Cortex Search Service**:
   ```sql
   -- Execute cortex_search_service.sql in Snowsight
   -- This parses PDFs and creates semantic search index
   ```

4. **(Optional) Setup Web Scraping Capability**:
   
   Enable your agent to scrape and analyze web content in real-time:
   
   ```sql
   -- Execute web_scrape_setup.sql in Snowsight
   -- This creates external access integration and web_scrape function
   ```
   
   This allows the agent to:
   - Access and scrape any public website
   - Extract and analyze web content
   - Answer questions about current web information
   
   Based on [Snowflake AI Demo web scraping implementation](https://github.com/NickAkincilar/Snowflake_AI_DEMO/blob/main/sql_scripts/demo_setup.sql).

5. **Create Cortex Agent** in Snowsight:
   - Navigate to **AI & ML** → **Agents**
   - Click **Create agent** with schema `SNOWFLAKE_INTELLIGENCE.AGENTS`
   - Configure agent with:
     - **Cortex Analyst** tool (uses `support_tickets_semantic_model.yaml` for SQL generation)
     - **Cortex Search** tool (searches parsed PDF documents)
     - **Function Tool** (optional): Add `web_scrape(VARCHAR)` function for real-time web content analysis
   - See the [quickstart guide](https://quickstarts.snowflake.com/guide/integrate_snowflake_cortex_agents_with_slack/index.html#4) for detailed instructions

6. **Generate Personal Access Token (PAT)**:
   - In Snowsight, go to your user profile
   - Generate PAT for `SNOWFLAKE_INTELLIGENCE_ADMIN` role
   - Save this token for the `.env` file

### 7. Setup Environment Variables

Copy the example environment file and configure with your credentials:

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your actual credentials
```

Required environment variables (see `.env.example` for full template):

```bash
# Slack Credentials (from https://api.slack.com/apps)
SLACK_BOT_TOKEN=xoxb-your-bot-token-here
SLACK_APP_TOKEN=xapp-your-app-token-here

# Snowflake Credentials
SNOWFLAKE_ACCOUNT=your-account-identifier
SNOWFLAKE_USER=your-username
SNOWFLAKE_PASSWORD=your-password
SNOWFLAKE_WAREHOUSE=your-warehouse
SNOWFLAKE_DATABASE=your-database
SNOWFLAKE_SCHEMA=your-schema
SNOWFLAKE_ROLE=your-role

# Snowflake PAT Authentication
PAT=your-personal-access-token

# Cortex Agent Configuration
AGENT_ENDPOINT=https://your-account.snowflakecomputing.com/api/v2/cortex/agent/your-agent-name/message
CORTEX_AGENT_NAME=your-agent-name
```

**Note**: Never commit your `.env` file to git. It's already in `.gitignore`.

### 8. Test Snowflake Connection (Optional but Recommended)

Before running the bot, verify your Snowflake connection is working:

```bash
# Make sure virtual environment is activated
source .venv/bin/activate

# Run the test script to verify Snowflake connectivity
python test.py
```

This will:
- ✅ Test authentication with your Snowflake account
- ✅ Verify the Cortex Agent endpoint is accessible
- ✅ Show raw API responses and planning steps
- ✅ Execute sample queries to ensure everything works

If the test succeeds, you're ready to run the bot!

### 9. Start the Bot

```bash
# Make sure virtual environment is activated
source .venv/bin/activate

# Run the application
python app.py

# Or use the shell script
./slack_bot.sh
```

## Project Structure

```
first-bolt-app/
├── app.py                                    # Main Slack bot application with enhanced message handling
├── cortex_chat.py                            # Snowflake Cortex Agent interaction logic
├── cortex_response_parser.py                 # Parse and format Cortex responses
├── test.py                                   # Connection test script for Snowflake/Cortex verification
├── setup.sql                                 # Snowflake setup script
├── cortex_search_service.sql                 # Cortex Search Service configuration
├── web_scrape_setup.sql                      # Web scraping function setup (optional)
├── support_tickets_semantic_model.yaml       # Cortex Analyst semantic model definition
├── data/                                     # Sample data and documents
│   ├── *.pdf                                 # Sample PDF documents for Cortex Search
│   └── ...                                   # Contract and policy documents
├── slack_bot.sh                              # Shell script to start the bot
├── manifest.json                             # Slack app configuration manifest
├── pyproject.toml                            # Project metadata and dependencies
├── uv.lock                                   # Dependency lock file (managed by uv)
├── .env.example                              # Environment variable template
├── .env                                      # Your actual environment variables (not tracked in git)
└── README.md                                 # This file
```

## Usage

### In Slack

1. **Direct Message**: Send a DM to your bot
2. **Mention in Channel**: Mention `@YourBot` in a channel
3. **Edit Messages**: Edit your previous messages and the bot will reprocess them

### Example Queries

**Data Analysis:**
```
What are our top sales regions this quarter?
Show me customer support tickets from last week
How many unique customers have raised a support ticket with Cellular service?
```

**Document Search:**
```
What are the payment terms for Snowtires?
What's the latest tire recycling policy?
```

**Web Scraping (if enabled):**
```
What's on the homepage of https://www.snowflake.com?
Analyze the content at https://www.example.com and summarize it
What information can you find about product X on their website?
```

## Features

- ✅ Real-time streaming responses from Cortex Agents
- ✅ Interactive Slack blocks with formatted output
- ✅ Data visualization support (charts, tables)
- ✅ Handle both new and edited messages
- ✅ Bot loop prevention
- ✅ Error handling with detailed feedback
- ✅ Cortex Search integration for documentation queries
- ✅ Optional web scraping capability for real-time web content analysis

## Troubleshooting

### Bot doesn't respond to edited messages

Make sure your `app.py` includes the enhanced message handler that checks for `message_changed` subtypes.

### `uv` command not found

Ensure `uv` is installed and in your PATH:
```bash
pip install uv
# Or reinstall via curl script
```

### Connection errors to Snowflake

Verify your `.env` file has correct Snowflake credentials and your IP is whitelisted in Snowflake network policies.

## References

### Quickstart Guides
- [Integrate Snowflake Cortex Agents with Slack - Official Quickstart](https://quickstarts.snowflake.com/guide/integrate_snowflake_cortex_agents_with_slack/index.html) - Complete step-by-step tutorial
- [GitHub Repository - Original Quickstart Code](https://github.com/Snowflake-Labs/sfguide-integrate-snowflake-cortex-agents-with-slack)

### Slack Integration
- [Slack Bolt for Python Quickstart Guide](https://docs.slack.dev/tools/bolt-python/getting-started/) - Official guide for Slack CLI setup and authentication
- [Slack Bolt for Python Documentation](https://slack.dev/bolt-python/)

### Snowflake Cortex
- [Snowflake Cortex Agents Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Snowflake Cortex Analyst Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Snowflake Cortex Search Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search)

### Tools
- [uv Package Manager](https://github.com/astral-sh/uv)

## Contributing

Issues and questions? Feel free to:

1. Open an issue in this repository
2. Reference the [original Snowflake quickstart](https://github.com/Snowflake-Labs/sfguide-integrate-snowflake-cortex-agents-with-slack)
3. Check [Slack Bolt Python issues](https://github.com/slackapi/bolt-python/issues)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
