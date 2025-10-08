# Quickstart Guide - Snowflake Cortex Slack Bot

Quick reference for deploying and managing the Cortex Slack Bot.

## 🚀 Three Ways to Run

### 1. Local Development
```bash
# Setup (one-time)
uv venv --python 3.13 .venv
source .venv/bin/activate
uv sync

# Configure credentials
cp .env.example .env
# Edit .env with your actual values

# Run
python app.py
```

### 2. Docker Local
```bash
# Build and run
./test-local-container.sh --build

# View logs
./test-local-container.sh --logs

# Stop
./test-local-container.sh --stop
```

### 3. SPCS Production
```bash
# 1. Setup infrastructure (in Snowsight)
# Execute: spcs_setup.sql

# 2. Configure credentials
cp spcs-env-template.yaml spcs-env.yaml
# Edit spcs-env.yaml with your tokens

# 3. Deploy
./deploy.sh --connection your-connection-name

# 4. Update after changes
./deploy.sh --update --connection your-connection-name
```

### ⚠️ SPCS Critical Notes

**Hostname Format:**
- Account: `ORG-ACCOUNT_REGION` (uppercase, underscores OK)
- Host: `org-account-region.snowflakecomputing.com` (lowercase, hyphens required)

**Authentication:**
- SPCS uses **OAuth** for Snowflake connections (automatic)
- SPCS uses **PAT** for Cortex Agent API calls (configure in `spcs-env.yaml`)
- Network policy must allow PAT access ([see README](README.md#spcs-deployment))

**Required Variables in spcs-env.yaml:**
- `SNOWFLAKE_HOST`, `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_DATABASE`
- `SNOWFLAKE_SCHEMA`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_PORT`
- `PAT` (Personal Access Token)

---

## 📋 SPCS Management Commands

### Service Status & Logs
```bash
# Status
snow sql -q "SELECT SYSTEM\$GET_SERVICE_STATUS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE');"

# Logs (last 100 lines)
snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE', '0', 'cortex-slack-bot', 100);"

# Show endpoints
snow sql -q "SHOW ENDPOINTS IN SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE;"
```

### Service Control
```bash
# Suspend (save costs)
snow sql -q "ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE SUSPEND;"

# Resume
snow sql -q "ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE RESUME;"
```

### Compute Pool
```bash
# Show pools
snow sql -q "SHOW COMPUTE POOLS;"

# Suspend pool
snow sql -q "ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL SUSPEND;"

# Resume pool
snow sql -q "ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL RESUME;"
```

---

## 🔑 Environment Variables

### Local Development (.env)
```bash
SLACK_BOT_TOKEN=xoxb-...          # From Slack app
SLACK_APP_TOKEN=xapp-...          # From Slack app
ACCOUNT=your-account              # Snowflake account
HOST=your-account.snowflakecomputing.com
DEMO_USER=your-username           # Snowflake user
DEMO_USER_ROLE=your-role          # Snowflake role
WAREHOUSE=your-warehouse          # Snowflake warehouse
AGENT_ENDPOINT=https://...        # Cortex Agent URL
PAT=your-token                    # Personal Access Token
DEFAULT_SPCS_WAREHOUSE=...        # Optional: default for SPCS
```

### SPCS Deployment (spcs-env.yaml)
**All above variables PLUS:**
```bash
SNOWFLAKE_HOST=your-account.snowflakecomputing.com
SNOWFLAKE_ACCOUNT=YOUR-ACCOUNT    # Uppercase
SNOWFLAKE_DATABASE=CORTEX_SLACK_BOT_DB
SNOWFLAKE_SCHEMA=APP_SCHEMA
SNOWFLAKE_WAREHOUSE=CORTEX_SLACK_BOT_WH
SNOWFLAKE_PORT=443
```

### Setting Env Vars for SPCS

**Option 1: Use spcs-env.yaml (Recommended)**
```bash
cp spcs-env-template.yaml spcs-env.yaml
# Edit with your credentials
./deploy.sh --connection your-connection
```

**Option 2: ALTER SERVICE**
```sql
ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE SET
  SPEC_INLINE = $$ 
spec:
  containers:
    - name: cortex-slack-bot
      env:
        SLACK_BOT_TOKEN: 'your-token'
        # ... other variables
$$;
```

---

## 🐛 Common Issues

### Bot not responding
```bash
# Check if running
./test-local-container.sh --logs  # Docker
# or
snow sql -q "SELECT SYSTEM\$GET_SERVICE_STATUS('...');"  # SPCS

# Verify credentials in .env or spcs-env.yaml
```

### Docker build fails
```bash
# Use correct platform
docker build --platform linux/amd64 -t cortex-slack-bot:latest .
```

### SPCS service won't start
```bash
# Resume compute pool
snow sql -q "ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL RESUME;"

# Check logs
snow sql -q "SELECT SYSTEM\$GET_SERVICE_LOGS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE', '0', 'cortex-slack-bot', 100);"
```

### Environment variables not updating
```bash
# Redeploy with new spec
./deploy.sh --update --skip-build
```

### Hostname resolution error
```
Error: Failed to resolve 'org-account_region.snowflakecomputing.com'
```
**Fix:** Use lowercase with hyphens (not underscores):
- Wrong: `ORG-ACCOUNT_REGION.snowflakecomputing.com`
- Right: `org-account-region.snowflakecomputing.com`

### Cortex Agent authentication error
```
Error: Programmatic access token is invalid
```
**Fix:** SPCS requires PAT in `spcs-env.yaml` for Cortex API calls.
OAuth tokens don't work for REST APIs. Check network policy allows PAT.

**For detailed troubleshooting:** See [README.md Troubleshooting](README.md#troubleshooting)

---

## 💰 Cost Management (SPCS)

```sql
-- Suspend when not in use
ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE SUSPEND;

-- Aggressive auto-suspend (5 minutes)
ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL SET AUTO_SUSPEND_SECS = 300;

-- Check usage
SHOW SERVICES;
SHOW COMPUTE POOLS;
```

**Estimated Cost**: ~$0.23/hour (CPU_X64_XS) when running

---

## 📚 Full Documentation

For complete documentation, see [README.md](README.md)

---

## 🔗 Quick Links

- **Main Docs**: [README.md](README.md)
- **SPCS Setup**: [spcs_setup.sql](spcs_setup.sql)
- **Service Spec**: [spec.yaml](spec.yaml)
- **Env Template**: [spcs-env-template.yaml](spcs-env-template.yaml)

---

**Need Help?** Check the [Troubleshooting section](README.md#troubleshooting) in README.md
