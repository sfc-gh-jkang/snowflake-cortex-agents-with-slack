# Snowflake Cortex Agents with Slack Integration ❄️

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Python 3.13+](https://img.shields.io/badge/python-3.13+-blue.svg)](https://www.python.org/downloads/)

> A Slack bot powered by Snowflake Cortex Agents that provides intelligent responses using natural language processing and real-time data analysis. Deploy locally, in Docker, or in Snowpark Container Services.

## 🚀 Quick Start

Choose your deployment method:

```bash
# 1. Local Development (fastest for testing)
uv venv && source .venv/bin/activate
uv sync
uv run app.py

# 2. Docker (containerized local)
./test-local-container.sh --build

# 3. Snowpark Container Services (production)
./deploy.sh --connection your-connection
```

## Overview

This project integrates [Snowflake Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents) with Slack using the [Bolt for Python framework](https://slack.dev/bolt-python/). The bot can:

- ✅ Respond to messages with AI-powered insights from Snowflake Cortex
- ✅ Handle both new messages and message edits seamlessly
- ✅ Provide real-time streaming responses
- ✅ Execute data queries and visualizations
- ✅ Search through Snowflake documentation and support tickets
- ✅ Deploy locally, in Docker, or in Snowpark Container Services (NEW)
- ✅ Production-ready with automated SPCS deployment (NEW)

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

### 3. **Docker and SPCS Deployment** 🐳☁️

Added complete containerization and production deployment capabilities:

- **Dockerfile**: Multi-stage build for optimized container images
- **SPCS Support**: Deploy and run inside your Snowflake account
- **Automated Deployment**: `deploy.sh` script handles build, push, and service creation
- **Local Testing**: `test-local-container.sh` for Docker testing before SPCS deployment
- **Infrastructure as Code**: Complete SQL setup for SPCS infrastructure
- **Monitoring**: Built-in commands for service status, logs, and management

### 4. **Production-Ready SPCS Authentication** 🔐

Enhanced authentication for seamless SPCS deployment:

- **Automatic Environment Detection**: Detects SPCS environment via `/snowflake/session/token`
- **OAuth Token Support**: Uses Snowflake-provided OAuth tokens when running in SPCS
- **Dual Authentication**:
  - Local development: PAT authentication
  - SPCS production: OAuth token authentication
- **No Role Configuration Required**: OAuth connections work without explicit role specification
- **Cortex API Integration**: Automatically switches between `PROGRAMMATIC_ACCESS_TOKEN` and `OAUTH` headers
- **Proper Logging**: Uses Python `logging` module instead of `print` for production-grade logs

### 5. **Enhanced Deployment Scripts** 🚀

Improved deployment automation and reliability:

- **Default Connection Support**: Automatically uses connection marked as `is_default=True`
- **Fixed Docker Authentication**: Uses `snow spcs image-registry login` for proper authentication
- **Smart Repository Detection**: Correctly extracts repository URL from SHOW commands
- **Privilege Management**: Grants permissions to `SNOWFLAKE_INTELLIGENCE_ADMIN` role
- **Update vs Deploy**: Separate paths for creating new services vs updating existing ones

## Deployment Options

This application can be deployed in three ways:

1. **🐳 Local Docker** - Run containerized locally for testing
2. **☁️ Snowpark Container Services (SPCS)** - Run inside your Snowflake account
3. **💻 Local Development** - Traditional Python virtual environment

## Prerequisites

### Common Requirements

- Slack workspace with admin access
- Snowflake account with Cortex enabled
- Snowflake Cortex Agent configured (see setup below)

### For Local Development

- Python 3.13+
- [uv](https://github.com/astral-sh/uv) package manager

### For Docker Deployment

- Docker Desktop or Docker Engine
- [uv](https://github.com/astral-sh/uv) package manager (for building)

### For SPCS Deployment

- Docker Desktop or Docker Engine
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) (`snow` command)
- Snowflake account with SPCS enabled

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

1. **Create Cortex Agent** in Snowsight:
   - Navigate to **AI & ML** → **Agents**
   - Click **Create agent** with schema `SNOWFLAKE_INTELLIGENCE.AGENTS`
   - Configure agent with:
     - **Cortex Analyst** tool (uses `support_tickets_semantic_model.yaml` for SQL generation)
     - **Cortex Search** tool (searches parsed PDF documents)
     - **Function Tool** (optional): Add `web_scrape(VARCHAR)` function for real-time web content analysis
   - See the [quickstart guide](https://quickstarts.snowflake.com/guide/integrate_snowflake_cortex_agents_with_slack/index.html#4) for detailed instructions

2. **Generate Personal Access Token (PAT)**:
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

# Optional: Default warehouse for SPCS deployment (defaults to CORTEX_SLACK_BOT_WH)
DEFAULT_SPCS_WAREHOUSE=your-spcs-warehouse
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

---

## 🐳 Docker Deployment

### Build and Test Locally with Docker

The application can be containerized using Docker for consistent deployment across environments.

#### 1. Build Docker Image

```bash
# Build for local testing
docker build --platform linux/amd64 -t cortex-slack-bot:latest .

# Or use the deployment script
./deploy.sh --local --build
```

#### 2. Test Container Locally

```bash
# Option 1: Using the test script (recommended)
./test-local-container.sh --build

# Option 2: Manual Docker run
docker run --rm --env-file .env --platform linux/amd64 cortex-slack-bot:latest
```

#### 3. Test Script Commands

```bash
# Build and run container
./test-local-container.sh --build

# View container logs
./test-local-container.sh --logs

# Access container shell for debugging
./test-local-container.sh --shell

# Stop running container
./test-local-container.sh --stop
```

**Note**: Docker deployment uses Socket Mode for Slack, so no public endpoints are needed.

---

## ☁️ Snowpark Container Services (SPCS) Deployment

Deploy the bot to run inside your Snowflake account using Snowpark Container Services.

### Prerequisites for SPCS

1. **Install Snowflake CLI**:

   ```bash
   pip install snowflake-cli-labs

   # Verify installation
   snow --version
   ```

2. **Configure Snowflake CLI Connection**:

   ```bash
   # Create a new connection
   snow connection add

   # Or test existing connection
   snow connection test --connection your-connection-name
   ```

### SPCS Deployment Steps

#### 1. Run SPCS Setup SQL

Execute the setup SQL in Snowsight to create the infrastructure:

```sql
-- Execute spcs_setup.sql in Snowsight
-- This creates:
-- - Database and schemas
-- - Image repository
-- - Compute pool
-- - External access integration for Slack API
-- - Stage for service specifications
```

Open Snowsight and run the contents of `spcs_setup.sql`. This will:

- Create `CORTEX_SLACK_BOT_DB` database
- Set up image repository for Docker images
- Create compute pool for running the service
- Configure network access for Slack API and Snowflake Cortex endpoints
- Create stage for service specs
- **Grant privileges to `SNOWFLAKE_INTELLIGENCE_ADMIN` role** for deployment and management

**Important**: The setup script uses `ACCOUNTADMIN` for initial setup, then grants necessary privileges to `SNOWFLAKE_INTELLIGENCE_ADMIN` for ongoing operations.

#### 2. Configure Environment Variables

Environment variables are kept separate from the base spec for security. Create your credentials file:

```bash
# Copy the template
cp spcs-env-template.yaml spcs-env.yaml

# Edit with your actual credentials
# Update: SLACK_BOT_TOKEN, SLACK_APP_TOKEN, ACCOUNT, PAT, etc.
```

**Note**: `spcs-env.yaml` is gitignored and won't be committed to version control.

**⚠️ Important - Hostname Format**:

- **Account identifier** (e.g., `SNOWFLAKE_ACCOUNT`): Keep as-is with underscores if present (e.g., `ORG-ACCOUNT_REGION`)
- **Hostname** (e.g., `SNOWFLAKE_HOST`, `HOST`, URLs): Must use **lowercase and hyphens** (e.g., `org-account-region.snowflakecomputing.com`)
- Example: Account `MYORG-ACCOUNT_US_EAST_1` → Host `myorg-account-us-east-1.snowflakecomputing.com`

**⚠️ Critical - SPCS Authentication with Cortex Agents**:

SPCS services use **two different authentication methods** depending on what they're accessing:

1. **SPCS OAuth Token** (from `/snowflake/session/token`):
   - ✅ **Used for**: Internal Snowflake connections (Snowpark Session, snowflake.connector)
   - ✅ **Automatically provided** by SPCS runtime
   - ✅ **No configuration needed**

2. **Personal Access Token (PAT)** (from `spcs-env.yaml`):
   - ✅ **Used for**: Cortex Agent REST API calls
   - ❌ **Why**: SPCS OAuth tokens are scoped for service identity and **cannot authenticate with Cortex Agent REST APIs**
   - ⚠️ **Must be configured** in `spcs-env.yaml` as `PAT: 'your-pat-token'`

**🔐 Network Policy Requirements for PAT**:

When using a PAT in SPCS, you **must** ensure your Snowflake network policy allows access:

```sql
-- Check your current network policy
SHOW NETWORK POLICIES;

-- If you have a restrictive network policy, add SPCS IP ranges
-- Option 1: Allow all Snowflake IPs (simplest)
ALTER NETWORK POLICY your_policy_name 
  SET ALLOWED_IP_LIST = ('0.0.0.0/0');  -- ⚠️ Less secure

-- Option 2: Add specific SPCS service IPs (recommended)
-- Get your service's IP from: SELECT SYSTEM$GET_SERVICE_STATUS('...');
ALTER NETWORK POLICY your_policy_name 
  SET ALLOWED_IP_LIST = ('your.spcs.service.ip/32', ...existing IPs...);

-- Option 3: Disable network policy enforcement for SPCS service role
GRANT EXEMPTED FROM NETWORK POLICY ON NETWORK POLICY your_policy_name 
  TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
```

Without proper network policy configuration, PAT authentication will fail and Cortex Agent calls will return authentication errors.

**Alternative**: You can also set environment variables via ALTER SERVICE after deployment (see QUICKSTART.md for examples)

#### 3. Deploy to SPCS

Use the deployment script for automated deployment:

```bash
# First-time deployment (uses default connection automatically)
./deploy.sh

# Or specify a connection explicitly
./deploy.sh --connection your-connection-name
```

**Note**: The script automatically detects and uses your default Snowflake CLI connection (`is_default=True`). Make sure your default connection:

- Uses `SNOWFLAKE_INTELLIGENCE_ADMIN` role (or has equivalent privileges from `spcs_setup.sql` STEP 8)
- Has access to create and manage SPCS services

**Warehouse Configuration**: The application uses the following priority for warehouse selection:

1. `WAREHOUSE` environment variable (if set in `spcs-env.yaml`)
2. `SNOWFLAKE_WAREHOUSE` environment variable (if set)
3. `DEFAULT_SPCS_WAREHOUSE` environment variable (defaults to `CORTEX_SLACK_BOT_WH` if not set)

The script will:

1. ✅ Build Docker image for linux/amd64
2. ✅ Authenticate with Snowflake registry using `snow spcs image-registry login`
3. ✅ Push image to Snowflake registry
4. ✅ Upload service specification (`spcs-env.yaml`)
5. ✅ Create SPCS service with OAuth authentication
6. ✅ Display service status and logs

#### 4. Update Existing SPCS Service

After making code changes:

```bash
# Update service with new image
./deploy.sh --update --connection your-connection-name

# Skip rebuild if only updating spec
./deploy.sh --update --skip-build
```

#### 5. Monitor SPCS Service

```bash
# Check service status
snow sql -q "SELECT SYSTEM\$GET_SERVICE_STATUS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE');" --connection your-connection

# View service logs (last 100 lines)
snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE', '0', 'cortex-slack-bot', 100);" --connection your-connection

# Show service endpoints
snow sql -q "SHOW ENDPOINTS IN SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE;" --connection your-connection

# Suspend service (save costs)
snow sql -q "ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE SUSPEND;" --connection your-connection

# Resume service
snow sql -q "ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE RESUME;" --connection your-connection
```

#### 6. SPCS Troubleshooting

**Service won't start:**

```bash
# Check compute pool status
snow sql -q "SHOW COMPUTE POOLS;" --connection your-connection

# Verify image exists
snow sql -q "SHOW IMAGES IN IMAGE REPOSITORY CORTEX_SLACK_BOT_DB.IMAGE_SCHEMA.IMAGE_REPO;" --connection your-connection

# Check detailed logs
snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE', '0', 'cortex-slack-bot', 500);" --connection your-connection
```

**Slack not connecting - "not_allowed_token_type" error:**

- **Check if tokens are swapped** in `spcs-env.yaml`:
  - `SLACK_BOT_TOKEN` should start with `xoxb-` (Bot User OAuth Token)
  - `SLACK_APP_TOKEN` should start with `xapp-` (App-Level Token for Socket Mode)
- Verify external access integration is enabled
- Check network rules include `slack.com:443`, `api.slack.com:443`, `wss-primary.slack.com:443`

**OAuth authentication failures - Role errors:**

- **Don't specify role in environment variables for SPCS** - OAuth tokens have roles pre-assigned
- The service will use the role associated with the OAuth token (typically `ACCOUNTADMIN` or the service owner's role)
- Check service logs to see which role is being used: `"Using role: <role_name>"`

**Cortex Agent authentication errors:**

- **"Programmatic access token is invalid"**: Check that PAT is set correctly in `spcs-env.yaml`
- **SPCS OAuth tokens CANNOT be used for Cortex Agent REST APIs** - must use PAT
- Verify PAT has not expired (regenerate in Snowsight if needed)
- Check network policy allows PAT authentication (see SPCS Configuration section above)
- Logs should show: `"Running in SPCS - Using PAT for Cortex Agent API calls"`

**General authentication issues:**

- **Local environment**: Uses PAT for both Snowflake connections and Cortex Agent API
- **SPCS environment**: Uses DUAL authentication:
  - OAuth token (from `/snowflake/session/token`) for Snowflake connections
  - PAT for Cortex Agent REST API calls
- Check logs for authentication method being used
- OAuth token is automatically refreshed by Snowflake
- PAT must be manually regenerated when expired

**DNS/Connection errors - "Failed to resolve hostname":**

- **Hostname must use lowercase and hyphens** (not underscores)
- Convert account identifier underscores to hyphens in hostnames
- Example: `ORG-ACCOUNT_US_EAST_1` → `org-account-us-east-1.snowflakecomputing.com`
- Check all URLs in `spcs-env.yaml`: `HOST`, `SNOWFLAKE_HOST`, `AGENT_ENDPOINT`

### SPCS Deployment Commands Reference

```bash
# Deploy commands
./deploy.sh                              # First deployment
./deploy.sh --update                     # Update existing service
./deploy.sh --local                      # Test locally only
./deploy.sh --connection my-conn         # Use specific connection
./deploy.sh --skip-build                 # Skip Docker build

# Service management
snow sql -q "SHOW SERVICES IN SCHEMA CORTEX_SLACK_BOT_DB.APP_SCHEMA;"
snow sql -q "SELECT SYSTEM\$GET_SERVICE_STATUS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE');"
snow sql -q "ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE SUSPEND;"
snow sql -q "ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE RESUME;"

# Compute pool management
snow sql -q "SHOW COMPUTE POOLS;"
snow sql -q "ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL SUSPEND;"
snow sql -q "ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL RESUME;"

# Image management
snow sql -q "SHOW IMAGE REPOSITORIES;"
snow sql -q "SHOW IMAGES IN IMAGE REPOSITORY CORTEX_SLACK_BOT_DB.IMAGE_SCHEMA.IMAGE_REPO;"
```

---

## 🔄 Deployment Comparison

| Feature | Local Development | Docker Local | SPCS |
| ---------|------------------|--------------|------ |
| **Setup Time** | 5 minutes | 10 minutes | 20 minutes |
| **Cost** | Free (local compute) | Free (local compute) | Snowflake credits |
| **Scalability** | Single instance | Single instance | Auto-scaling |
| **Uptime** | Manual | Manual | 24/7 automated |
| **Security** | Local credentials | Local credentials | Snowflake-managed |
| **Updates** | Restart script | Rebuild container | `deploy.sh --update` |
| **Best For** | Development | Testing | Production |

## Project Structure

```text
first-bolt-app/
├── app.py                                    # Main Slack bot application with enhanced message handling
├── cortex_chat.py                            # Snowflake Cortex Agent interaction logic
├── cortex_response_parser.py                 # Parse and format Cortex responses
├── test.py                                   # Connection test script for Snowflake/Cortex verification
│
├── setup.sql                                 # Snowflake setup script (Cortex Agent, data, etc.)
├── cortex_search_service.sql                 # Cortex Search Service configuration
├── web_scrape_setup.sql                      # Web scraping function setup (optional)
├── spcs_setup.sql                            # SPCS infrastructure setup (NEW)
├── support_tickets_semantic_model.yaml       # Cortex Analyst semantic model definition
│
├── Dockerfile                                # Docker container definition (NEW)
├── .dockerignore                             # Docker build exclusions (NEW)
├── spec.yaml                                 # SPCS service specification - base (NEW)
├── spcs-env-template.yaml                    # SPCS environment variables template (NEW)
├── spcs-env.yaml                             # Your SPCS credentials (gitignored, create from template)
├── deploy.sh                                 # SPCS deployment script (NEW)
├── test-local-container.sh                   # Local Docker testing script (NEW)
├── slack_bot.sh                              # Shell script to start the bot locally
├── QUICKSTART.md                             # Quick reference guide (NEW)
│
├── data/                                     # Sample data and documents
│   ├── *.pdf                                 # Sample PDF documents for Cortex Search
│   └── ...                                   # Contract and policy documents
│
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

```text
What are our top sales regions this quarter?
Show me customer support tickets from last week
How many unique customers have raised a support ticket with Cellular service?
```

**Document Search:**

```text
What are the payment terms for Snowtires?
What's the latest tire recycling policy?
```

**Web Scraping (if enabled):**

```text
What's on the homepage of https://www.snowflake.com?
Analyze the content at https://www.example.com and summarize it
What information can you find about product X on their website?
```

## Features

### Core Functionality

- ✅ Real-time streaming responses from Cortex Agents
- ✅ Interactive Slack blocks with formatted output
- ✅ Data visualization support (charts, tables)
- ✅ Handle both new and edited messages
- ✅ Bot loop prevention
- ✅ Error handling with detailed feedback
- ✅ Cortex Search integration for documentation queries
- ✅ Optional web scraping capability for real-time web content analysis

### Deployment & Operations

- ✅ **Docker Support**: Containerized deployment with multi-stage builds
- ✅ **SPCS Deployment**: Run inside your Snowflake account
- ✅ **Automated Deployment**: One-command deployment with `deploy.sh`
- ✅ **Local Testing**: Test containers locally before cloud deployment
- ✅ **Service Monitoring**: Built-in status checks and log viewing
- ✅ **Auto-scaling**: SPCS compute pool auto-resume/suspend
- ✅ **Secure**: Snowflake-managed credentials and external access integration

## Troubleshooting

### Local Development Issues

#### Bot doesn't respond to edited messages

Make sure your `app.py` includes the enhanced message handler that checks for `message_changed` subtypes.

#### `uv` command not found

Ensure `uv` is installed and in your PATH:

```bash
pip install uv
# Or reinstall via curl script
curl -LsSf https://astral.sh/uv/install.sh | sh
```

#### Connection errors to Snowflake

Verify your `.env` file has correct Snowflake credentials and your IP is whitelisted in Snowflake network policies.

### Docker Issues

#### Build fails with platform errors

Ensure you're building for linux/amd64:

```bash
docker build --platform linux/amd64 -t cortex-slack-bot:latest .
```

#### Container exits immediately

Check logs for errors:

```bash
./test-local-container.sh --logs
```

Verify all environment variables are set correctly in `.env`.

### SPCS Deployment Issues

#### Image push fails

```bash
# Verify connection
snow connection test --connection your-connection

# Check repository URL
snow sql -q "SHOW IMAGE REPOSITORIES;" --connection your-connection

# Manual Docker login
docker login <registry-url> -u <account>/<user>
```

#### Service won't start

```bash
# Check compute pool is active
snow sql -q "SHOW COMPUTE POOLS;" --connection your-connection
snow sql -q "ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL RESUME;" --connection your-connection

# Verify image exists
snow sql -q "SHOW IMAGES IN IMAGE REPOSITORY CORTEX_SLACK_BOT_DB.IMAGE_SCHEMA.IMAGE_REPO;" --connection your-connection

# Check service logs
snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE', '0', 'cortex-slack-bot', 500);" --connection your-connection
```

#### Slack connection fails in SPCS

- Verify `SLACK_BOT_TOKEN` and `SLACK_APP_TOKEN` in `spec.yaml`
- Ensure external access integration is enabled
- Check service logs for connection errors
- Verify network rules include `slack.com:443` and `api.slack.com:443`

#### Environment variables not updating

After changing `spec.yaml`:

```bash
# Re-upload spec and restart service
./deploy.sh --update --skip-build --connection your-connection
```

## Cost Considerations

### Local Development

- **Free** - Uses your local compute resources
- No Snowflake credits consumed (only during Cortex Agent API calls)

### Docker Local

- **Free** - Uses your local compute resources
- No Snowflake credits consumed (only during Cortex Agent API calls)

### SPCS Deployment

- **Compute Pool**: Charges based on instance family and uptime
  - `CPU_X64_XS`: ~$0.23/hour (smallest instance)
  - Auto-suspend saves costs when not in use
- **Storage**: Minimal (Docker images only)
- **Cortex Agent**: Per-call pricing based on model used
- **Data Transfer**: Minimal for Slack API calls

**Cost Optimization Tips**:

```sql
-- Suspend compute pool when not in use
ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL SUSPEND;

-- Set aggressive auto-suspend
ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL SET AUTO_SUSPEND_SECS = 300;  -- 5 minutes

-- Monitor usage
SHOW SERVICES;
SELECT SYSTEM$GET_SERVICE_STATUS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE');
```

## TODO

- [ ] **Cortex Analyst Semantic Model Migration**: Convert the cortex analyst semantic model from YAML file to semantic view creation and ensure the `CORTEX_SLACK_BOT_WH` is set as the default warehouse to get around warehouse configuration issues

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

### Snowpark Container Services

- [SPCS Documentation](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview) - Official SPCS overview
- [SPCS Tutorial](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/tutorial-1) - Step-by-step SPCS tutorial
- [SPCS Specification Reference](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/specification-reference) - Service spec YAML reference
- [Snowflake CLI Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) - snow command reference
- [Cortex Cost App SPCS Example](https://github.com/sfc-gh-jkang/cortex-cost-app-spcs) - Reference implementation

### Tools

- [uv Package Manager](https://github.com/astral-sh/uv)
- [Docker Documentation](https://docs.docker.com/)
- [Snowflake CLI on PyPI](https://pypi.org/project/snowflake-cli-labs/)

## Contributing

Issues and questions? Feel free to:

1. Open an issue in this repository
2. Reference the [original Snowflake quickstart](https://github.com/Snowflake-Labs/sfguide-integrate-snowflake-cortex-agents-with-slack)
3. Check [Slack Bolt Python issues](https://github.com/slackapi/bolt-python/issues)

## 📄 License

Copyright 2025 Snowflake Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

```
http://www.apache.org/licenses/LICENSE-2.0
```

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

See the [LICENSE](LICENSE) file for the full license text.