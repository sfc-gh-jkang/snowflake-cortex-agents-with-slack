# Snowflake Cortex Agent Automation Scripts 🤖

This directory contains SQL scripts for setting up automated agent workflows in Snowflake Intelligence. These scripts enable your Cortex Agent to conduct scheduled analysis and send results via email or Slack.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Setup Order](#setup-order)
- [Scripts](#scripts)
- [Architecture](#architecture)
- [Usage Examples](#usage-examples)
- [Monitoring and Management](#monitoring-and-management)
- [Troubleshooting](#troubleshooting)

## Overview

These scripts provide a complete automation framework for Snowflake Cortex Agents:

1. **Communication Tools**: Email and Slack notification capabilities
2. **Agent Execution**: Programmatic agent invocation via stored procedures
3. **Result Management**: Queue system for storing and tracking analysis results
4. **Scheduled Tasks**: Automated agent runs with configurable schedules
5. **Notification Dispatch**: Automatic delivery of results to Slack/email

⚠️ **Important**: After running these scripts, you must register the stored procedures as **custom tools** in your Cortex Agent configuration. See [Register Custom Tools](#4️⃣-register-custom-tools-with-your-agent) and the [official Snowflake documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage) for details.

## Features

✅ **Email Integration**
- Send emails directly from Snowflake Intelligence
- Pre-approved recipient validation for security
- Plain text and HTML email support
- Instant success/failure feedback

✅ **Slack Integration**
- Direct Slack channel messaging via webhooks
- Rich text formatting with Markdown support
- Multi-line message handling
- Emoji and formatting support

✅ **Agent Scheduling**
- Schedule agent runs with CRON expressions
- Store analysis results in queued tables
- Automatic retry and error handling
- Task-based execution with warehouse management

✅ **Result Queue System**
- Store agent results for later dispatch
- Track notification status (PENDING, SENT, FAILED)
- Separate analysis execution from notification delivery
- Support for detailed results and summaries

## Prerequisites

Before running these scripts, ensure you have:

1. **Snowflake Account** with Cortex enabled
2. **Cortex Agent** already created and configured (see main README.md)
   - **Important**: After running the scripts, you must register the stored procedures as custom tools in your agent configuration (see [Register Custom Tools](#4️⃣-register-custom-tools-with-your-agent))
3. **Role**: `SNOWFLAKE_INTELLIGENCE_ADMIN_RL` with appropriate privileges
4. **Database**: `SNOWFLAKE_INTELLIGENCE`
5. **Schema**: `SNOWFLAKE_INTELLIGENCE.TOOLS`
6. **Warehouse**: Active warehouse for agent execution (e.g., `SNOWFLAKE_INTELLIGENCE_WH`)

### For Email Tool
- List of allowed email recipients
- `ACCOUNTADMIN` role for notification integration setup

### For Slack Tool
- Slack webhook URL (from Slack App configuration)
- Slack webhook secret token
- `ACCOUNTADMIN` role for notification integration setup

## Setup Order

⚠️ **IMPORTANT**: Follow this order for successful setup:

### 1️⃣ Email Tool Setup (Optional but Recommended First)

```bash
Execute: agent_email_tool.sql
Time: ~5 minutes
```

**What it does:**
- Creates `SNOWFLAKE_INTELLIGENCE_EMAIL` notification integration
- Creates `SEND_EMAIL` stored procedure
- Sets up allowed recipient list

**Configuration needed:**
- Update `ALLOWED_RECIPIENTS` with your email addresses (line 55-59)

### 2️⃣ Slack Tool Setup (Required for scheduled notifications)

```bash
Execute: agent_slack_tool.sql
Time: ~5 minutes
```

**What it does:**
- Creates Slack webhook secret
- Creates `slack_webhook_integration` notification integration
- Creates `SEND_SLACK_NOTIFICATION` stored procedure

**Configuration needed:**
- Update `SECRET_STRING` with your Slack webhook URL path (line 5)
- Format: `'T12345678/B12345678/abc123def456'` (the path after `https://hooks.slack.com/services/`)

### 3️⃣ Agent Scheduling Setup

```bash
Execute: setup_agent_schedule.sql
Time: ~10 minutes
```

**What it does:**
- Creates `call_cortex_agent_proc` stored procedure
- Creates `AGENT_RESULTS_QUEUE` table
- Creates `STORE_AGENT_RESULTS` procedure
- Creates view `PENDING_SLACK_NOTIFICATIONS`
- Creates `MARK_SLACK_SENT` procedure
- Creates scheduled task `DAILY_SUPPORT_ANALYSIS`
- Creates notification task `SEND_SLACK_NOTIFICATIONS`

**Configuration needed:**
- Update agent name in API endpoint (line 36): `SLACK_SUPPORT_AI` → your agent name
- Update analysis query (line 192-199, 208-229) with your use case
- Update CRON schedule (line 204, 247) to match your needs

### 4️⃣ Register Custom Tools with Your Agent

**⚠️ IMPORTANT**: After creating the stored procedures above, you must register them as **custom tools** in your Cortex Agent configuration.

**What to register:**
- `SEND_EMAIL(recipient_email, subject, body)` - Email notification tool
- `SEND_SLACK_NOTIFICATION(slack_notification)` - Slack messaging tool
- `STORE_AGENT_RESULTS(analysis_type, title, summary, detailed_results, task_name)` - Result storage tool

**How to register custom tools:**

You can add custom tools via Snowsight UI or REST API. See the [official Snowflake documentation on configuring Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage) for detailed instructions.

#### Method 1: Snowsight UI

1. Navigate to **AI & ML** → **Agents**
2. Select your agent and click **Edit**
3. Select **Tools**
4. Find **Custom tools** and click **+ Add**
5. For each tool:
   - **Name**: Enter a descriptive name (e.g., "Email Tool", "Slack Tool", "Store Results")
   - **Description**: Describe what the tool does and when to use it
   - **Stored procedure**: Select the procedure from the dropdown
   - **Warehouse**: Select the warehouse for execution
6. Click **Add** for each tool
7. Click **Save**

#### Method 2: REST API

```bash
# Add SEND_EMAIL as a custom tool
curl -X PUT "$SNOWFLAKE_ACCOUNT_BASE_URL/api/v2/databases/<database>/schemas/<schema>/agents/<agent-name>" \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: Bearer $PAT" \
--data '{
  "tools": [
    {
      "type": "function",
      "name": "send_email_tool",
      "description": "Sends an email to pre-approved recipients. Use this when the user asks to send analysis results via email.",
      "function": {
        "database": "SNOWFLAKE_INTELLIGENCE",
        "schema": "TOOLS",
        "function_name": "SEND_EMAIL",
        "function_signature": "(VARCHAR, VARCHAR, VARCHAR)"
      },
      "warehouse": "SNOWFLAKE_INTELLIGENCE_WH"
    }
  ]
}'

# Add SEND_SLACK_NOTIFICATION as a custom tool
curl -X PUT "$SNOWFLAKE_ACCOUNT_BASE_URL/api/v2/databases/<database>/schemas/<schema>/agents/<agent-name>" \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: Bearer $PAT" \
--data '{
  "tools": [
    {
      "type": "function",
      "name": "slack_notification_tool",
      "description": "Sends a formatted message to a Slack channel. Use this when the user asks to send results to Slack.",
      "function": {
        "database": "SNOWFLAKE_INTELLIGENCE",
        "schema": "TOOLS",
        "function_name": "SEND_SLACK_NOTIFICATION",
        "function_signature": "(VARCHAR)"
      },
      "warehouse": "SNOWFLAKE_INTELLIGENCE_WH"
    }
  ]
}'

# Add STORE_AGENT_RESULTS as a custom tool
curl -X PUT "$SNOWFLAKE_ACCOUNT_BASE_URL/api/v2/databases/<database>/schemas/<schema>/agents/<agent-name>" \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header "Authorization: Bearer $PAT" \
--data '{
  "tools": [
    {
      "type": "function",
      "name": "store_results_tool",
      "description": "Stores analysis results in a queue for later delivery. Use this when generating scheduled reports.",
      "function": {
        "database": "SNOWFLAKE_INTELLIGENCE",
        "schema": "TOOLS",
        "function_name": "STORE_AGENT_RESULTS",
        "function_signature": "(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR)"
      },
      "warehouse": "SNOWFLAKE_INTELLIGENCE_WH"
    }
  ]
}'
```

#### Tool Descriptions (for Agent Instructions)

When registering the tools, use these descriptions to help the agent understand when to use each tool:

**SEND_EMAIL**:
```
Sends an email to pre-approved recipients with a subject and body. 
Use this tool when users request email delivery of analysis results.
Parameters: recipient_email, subject, body
Example: "Send the quarterly report to john@example.com"
```

**SEND_SLACK_NOTIFICATION**:
```
Sends a formatted message to a Slack channel via webhook.
Use this tool when users request Slack delivery of analysis results.
Supports markdown formatting and emojis.
Parameters: slack_notification (the message text)
Example: "Post this analysis to our team Slack channel"
```

**STORE_AGENT_RESULTS**:
```
Stores analysis results in a queue for scheduled delivery.
Use this tool for batch processing or when results should be sent later.
Parameters: analysis_type, title, summary, detailed_results, task_name
Example: For scheduled tasks that store results for later notification
```

**Testing the custom tools:**

After registration, test each tool in the Snowsight agent playground:

```text
"Send an email to your-email@example.com with subject 'Test' and body 'This is a test email'"

"Send a Slack notification with the message 'Hello from Snowflake Agent!'"

"Store analysis results with type 'Test Analysis', title 'Test Report', summary 'This is a test', detailed results 'Full data here', and task name 'MANUAL_TEST'"
```

**Reference**: [Snowflake Documentation - Configure and interact with Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage)

## Scripts

### 1. `agent_email_tool.sql`

**Purpose**: Sets up email sending capability for Snowflake Intelligence agents.

**Key Components:**

- **Notification Integration**: `SNOWFLAKE_INTELLIGENCE_EMAIL`
  - Type: EMAIL
  - Manages allowed recipients
  - Handles email delivery

- **Stored Procedure**: `SEND_EMAIL(recipient_email, subject, body)`
  - Sends emails to pre-approved recipients
  - Returns JSON response with status
  - Includes error handling

**Usage Example:**

```sql
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    'your-email@example.com',
    'Analysis Complete',
    'Your customer segmentation analysis has completed successfully.'
);
```

**Sections:**
- `[SECTION_1_SCHEMAS]`: Database and schema creation
- `[SECTION_2_INTEGRATION]`: Email notification integration setup
- `[SECTION_3_PROCEDURE]`: Main stored procedure definition
- `[SECTION_4_MANAGEMENT]`: Managing allowed recipients
- `[SECTION_5_EXAMPLES]`: Usage examples and test calls

### 2. `agent_slack_tool.sql`

**Purpose**: Enables Slack messaging for agent notifications.

**Key Components:**

- **Secret**: `my_slack_webhook_secret`
  - Stores Slack webhook credentials
  - Type: GENERIC_STRING

- **Notification Integration**: `slack_webhook_integration`
  - Type: WEBHOOK
  - Connects to Slack API
  - Handles webhook authentication

- **Stored Procedure**: `SEND_SLACK_NOTIFICATION(slack_notification)`
  - Sends formatted messages to Slack
  - Handles newline escaping
  - Returns JSON response with status

**Usage Example:**

```sql
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_SLACK_NOTIFICATION(
    '🔔 *Daily Report*\n\nAnalysis complete with key metrics.'
);
```

**Setup Steps:**
1. Get Slack webhook URL from your Slack app
2. Extract the path portion (after `https://hooks.slack.com/services/`)
3. Update `SECRET_STRING` with the path (format: `T12345/B12345/abc123def`)
4. Test the notification with the provided test query

### 3. `setup_agent_schedule.sql`

**Purpose**: Main orchestration script for scheduled agent runs and result delivery.

**Key Components:**

#### A. Agent Execution Procedure

```sql
call_cortex_agent_proc(query STRING)
```

- Calls Cortex Agent via REST API
- Uses `_snowflake.send_snow_api_request` for internal API calls
- Handles streaming responses
- Includes timeout management (5 minutes default)
- Fast response optimization

#### B. Results Queue System

**Table**: `AGENT_RESULTS_QUEUE`
- Stores analysis results with unique IDs
- Tracks notification status (PENDING, SENT, FAILED)
- Includes timestamps for tracking
- Supports both summary and detailed results

**Columns:**
- `result_id`: Unique identifier (auto-generated)
- `created_timestamp`: When result was created
- `analysis_type`: Category of analysis
- `title`: Short title for notification
- `summary`: Main content for notifications
- `detailed_results`: Full data (JSON or text)
- `status`: PENDING | SENT | FAILED
- `slack_sent_timestamp`: When notification was sent
- `task_name`: Which task created this result

#### C. Result Management Procedures

1. **STORE_AGENT_RESULTS**: Store analysis results
   ```sql
   STORE_AGENT_RESULTS(
       analysis_type VARCHAR,
       title VARCHAR, 
       summary VARCHAR,
       detailed_results VARCHAR,
       task_name VARCHAR
   )
   ```

2. **MARK_SLACK_SENT**: Update notification status
   ```sql
   MARK_SLACK_SENT(result_id VARCHAR)
   ```

#### D. Scheduled Tasks

1. **DAILY_SUPPORT_ANALYSIS**
   - Schedule: Daily at 9 AM EST (`CRON 0 9 * * * EST`)
   - Calls agent with analysis query
   - Stores results in queue
   - Warehouse: `SNOWFLAKE_INTELLIGENCE_WH`

2. **SEND_SLACK_NOTIFICATIONS**
   - Schedule: Every 15 minutes (`CRON */15 * * * * EST`)
   - Checks for pending notifications
   - Sends to Slack with formatted message
   - Updates status based on result
   - Warehouse: `SNOWFLAKE_INTELLIGENCE_WH`

**Workflow:**
```
┌─────────────────────────────────────────────────────────────┐
│ 1. Scheduled Task (DAILY_SUPPORT_ANALYSIS)                  │
│    Runs: Daily at 9 AM EST                                   │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Call Agent (call_cortex_agent_proc)                       │
│    Executes: Analysis query via Cortex Agent API             │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Store Results (AGENT_RESULTS_QUEUE)                       │
│    Status: PENDING                                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Notification Task (SEND_SLACK_NOTIFICATIONS)              │
│    Runs: Every 15 minutes                                     │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Send to Slack (SEND_SLACK_NOTIFICATION)                   │
│    Format: Emoji + Title + Summary + Timestamp               │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Update Status (MARK_SLACK_SENT)                           │
│    Status: SENT (success) or FAILED (error)                  │
└─────────────────────────────────────────────────────────────┘
```

## Architecture

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Snowflake Intelligence                       │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                      Scheduled Tasks                           │  │
│  │                                                                 │  │
│  │  ┌─────────────────────┐      ┌─────────────────────┐         │  │
│  │  │ DAILY_SUPPORT_      │      │ SEND_SLACK_         │         │  │
│  │  │ ANALYSIS            │      │ NOTIFICATIONS       │         │  │
│  │  │                     │      │                     │         │  │
│  │  │ CRON: 0 9 * * * EST│      │ CRON: */15 * * * *  │         │  │
│  │  └──────────┬──────────┘      └──────────┬──────────┘         │  │
│  │             │                             │                     │  │
│  └─────────────┼─────────────────────────────┼─────────────────────┘  │
│                │                             │                        │
│  ┌─────────────▼─────────────────────────────▼─────────────────────┐ │
│  │                      Stored Procedures                          │ │
│  │                                                                  │ │
│  │  ┌────────────────┐  ┌──────────────┐  ┌───────────────────┐  │ │
│  │  │ call_cortex_   │  │ STORE_AGENT_ │  │ SEND_SLACK_       │  │ │
│  │  │ agent_proc     │  │ RESULTS      │  │ NOTIFICATION      │  │ │
│  │  └───────┬────────┘  └──────┬───────┘  └─────────┬─────────┘  │ │
│  │          │                   │                     │            │ │
│  └──────────┼───────────────────┼─────────────────────┼────────────┘ │
│             │                   │                     │               │
│  ┌──────────▼───────────────────▼─────────────────────┼────────────┐ │
│  │                   AGENT_RESULTS_QUEUE              │            │ │
│  │                                                     │            │ │
│  │  result_id | analysis_type | title | summary      │            │ │
│  │  status    | created_timestamp | task_name        │            │ │
│  └─────────────────────────────────────────────────────┼────────────┘ │
│                                                        │               │
│  ┌──────────────────────────────────────────────────┐ │               │
│  │            External Integrations                  │ │               │
│  │                                                   │ │               │
│  │  ┌──────────────────┐  ┌────────────────────┐   │ │               │
│  │  │ slack_webhook_   │  │ SNOWFLAKE_         │   │ │               │
│  │  │ integration      │  │ INTELLIGENCE_EMAIL │   │ │               │
│  │  └────────┬─────────┘  └────────┬───────────┘   │ │               │
│  │           │                      │               │ │               │
│  └───────────┼──────────────────────┼───────────────┘ │               │
│              │                      │                  │               │
└──────────────┼──────────────────────┼──────────────────┘               │
               │                      │                                  │
               ▼                      ▼                                  │
     ┌─────────────────┐    ┌────────────────┐                         │
     │  Slack Channel  │    │  Email Inbox   │                         │
     └─────────────────┘    └────────────────┘                         │
                                                                         │
     ┌───────────────────────────────────────────────────┐             │
     │          Cortex Agent (via REST API)              │             │
     │                                                    │             │
     │  - Analyzes data using semantic models            │◄────────────┘
     │  - Generates SQL and visualizations               │
     │  - Searches documents via Cortex Search           │
     └───────────────────────────────────────────────────┘
```

### Data Flow

1. **Schedule Trigger** → Task executes on schedule (CRON)
2. **Agent Call** → Stored procedure calls Cortex Agent API
3. **Result Storage** → Analysis results stored in queue table
4. **Notification Check** → Separate task polls for pending results
5. **Delivery** → Slack/Email notification sent
6. **Status Update** → Result marked as SENT or FAILED

## Usage Examples

### Example 1: Manual Agent Test

Test the agent execution before scheduling:

```sql
-- Test agent call
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.call_cortex_agent_proc(
    'Show me a breakdown of support tickets by service type. DO NOT CREATE A CHART.'
);
```

### Example 2: Store Analysis Result

Manually store a result for testing the notification system:

```sql
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.STORE_AGENT_RESULTS(
    'Support Ticket Analysis',
    'Customer Support Tickets by Service Type',
    'Cellular: 1,234 tickets (65%)\nBusiness Internet: 678 tickets (35%)',
    '{"cellular": 1234, "business_internet": 678}',
    'MANUAL_TEST'
);
```

### Example 3: Execute Task Manually

Run scheduled task on-demand:

```sql
-- Execute analysis task
EXECUTE TASK DAILY_SUPPORT_ANALYSIS;

-- Check results
SELECT * FROM SNOWFLAKE_INTELLIGENCE.TOOLS.AGENT_RESULTS_QUEUE
ORDER BY created_timestamp DESC
LIMIT 5;

-- Execute notification task
EXECUTE TASK SEND_SLACK_NOTIFICATIONS;
```

### Example 4: View Pending Notifications

```sql
-- View all pending notifications
SELECT * FROM SNOWFLAKE_INTELLIGENCE.TOOLS.PENDING_SLACK_NOTIFICATIONS;

-- Count pending by analysis type
SELECT 
    analysis_type,
    COUNT(*) as pending_count
FROM AGENT_RESULTS_QUEUE 
WHERE status = 'PENDING'
GROUP BY analysis_type;
```

### Example 5: Customize Schedule

```sql
-- Change to every Monday at 8 AM
ALTER TASK DAILY_SUPPORT_ANALYSIS 
SET SCHEDULE = 'USING CRON 0 8 * * MON EST';

-- Change notification check to every 5 minutes
ALTER TASK SEND_SLACK_NOTIFICATIONS
SET SCHEDULE = 'USING CRON */5 * * * * EST';
```

### Example 6: Send Formatted Slack Message

```sql
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_SLACK_NOTIFICATION(
    '🔔 *Daily Support Report*

📊 **Summary:** 
Total tickets: 1,912
Cellular: 1,234 (65%)
Business Internet: 678 (35%)

⏰ **Generated:** ' || CURRENT_TIMESTAMP()::STRING
);
```

## Monitoring and Management

### Check Task Status

```sql
-- View all tasks
SHOW TASKS IN SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;

-- Check specific task status
DESCRIBE TASK DAILY_SUPPORT_ANALYSIS;
DESCRIBE TASK SEND_SLACK_NOTIFICATIONS;

-- View task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'DAILY_SUPPORT_ANALYSIS',
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;
```

### Monitor Queue

```sql
-- Check queue statistics
SELECT 
    status,
    COUNT(*) as count,
    MIN(created_timestamp) as oldest,
    MAX(created_timestamp) as newest
FROM AGENT_RESULTS_QUEUE
GROUP BY status;

-- Find failed notifications
SELECT * 
FROM AGENT_RESULTS_QUEUE 
WHERE status = 'FAILED'
ORDER BY created_timestamp DESC;

-- Average time to send notifications
SELECT 
    AVG(DATEDIFF('second', created_timestamp, slack_sent_timestamp)) as avg_seconds
FROM AGENT_RESULTS_QUEUE
WHERE status = 'SENT';
```

### Task Management

```sql
-- Suspend tasks
ALTER TASK SEND_SLACK_NOTIFICATIONS SUSPEND;
ALTER TASK DAILY_SUPPORT_ANALYSIS SUSPEND;

-- Resume tasks
ALTER TASK DAILY_SUPPORT_ANALYSIS RESUME;
ALTER TASK SEND_SLACK_NOTIFICATIONS RESUME;

-- Change warehouse
ALTER TASK DAILY_SUPPORT_ANALYSIS 
SET WAREHOUSE = 'LARGER_WAREHOUSE';
```

### Debug Logging

```sql
-- View debug logs (if TASK_DEBUG_LOG table exists)
SELECT * 
FROM TASK_DEBUG_LOG 
ORDER BY log_timestamp DESC 
LIMIT 100;

-- Clear old logs
DELETE FROM TASK_DEBUG_LOG 
WHERE log_timestamp < DATEADD('day', -30, CURRENT_TIMESTAMP());
```

## Troubleshooting

### Issue: Agent API Returns Error

**Symptoms:**
- `call_cortex_agent_proc` returns error status
- "Timeout or error" messages

**Solutions:**
```sql
-- 1. Verify agent name is correct
-- Check line 36 in setup_agent_schedule.sql
-- API_ENDPOINT should match your agent name

-- 2. Test Cortex Agent directly in Snowsight
-- Navigate to AI & ML → Agents → Your Agent → Test

-- 3. Check role permissions
SHOW GRANTS TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;

-- 4. Verify warehouse is active
SHOW WAREHOUSES LIKE 'SNOWFLAKE_INTELLIGENCE_WH';
```

### Issue: Slack Notifications Not Sending

**Symptoms:**
- Results stay in PENDING status
- No Slack messages received

**Solutions:**
```sql
-- 1. Test Slack integration directly
CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
    SNOWFLAKE.NOTIFICATION.TEXT_PLAIN(
        SNOWFLAKE.NOTIFICATION.SANITIZE_WEBHOOK_CONTENT('Test message')
    ),
    SNOWFLAKE.NOTIFICATION.INTEGRATION('slack_webhook_integration')
);

-- 2. Check notification task is running
SHOW TASKS LIKE 'SEND_SLACK_NOTIFICATIONS';
-- State should be 'started'

-- 3. Check task history for errors
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'SEND_SLACK_NOTIFICATIONS'
))
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;

-- 4. Verify webhook secret is correct
DESCRIBE SECRET my_slack_webhook_secret;

-- 5. Test SEND_SLACK_NOTIFICATION procedure
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_SLACK_NOTIFICATION(
    'Test notification'
);
```

### Issue: Tasks Not Running on Schedule

**Symptoms:**
- Tasks exist but don't execute
- No results in queue

**Solutions:**
```sql
-- 1. Check task state (must be 'started')
SHOW TASKS IN SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;

-- 2. Resume tasks if suspended
ALTER TASK DAILY_SUPPORT_ANALYSIS RESUME;
ALTER TASK SEND_SLACK_NOTIFICATIONS RESUME;

-- 3. Check warehouse is available
ALTER WAREHOUSE SNOWFLAKE_INTELLIGENCE_WH RESUME IF SUSPENDED;

-- 4. Verify schedule format
-- Use: 'USING CRON 0 9 * * * EST' (correct)
-- Not: 'CRON 0 9 * * *' (missing USING)

-- 5. Check for dependency issues
DESCRIBE TASK DAILY_SUPPORT_ANALYSIS;
-- Should have no PREDECESSOR (root task)
```

### Issue: Email/Slack Not Allowed

**Symptoms:**
- "Recipient not in allowed list" error (email)
- "Invalid webhook" error (Slack)

**Solutions:**
```sql
-- For email issues:
-- 1. Check allowed recipients
DESCRIBE INTEGRATION SNOWFLAKE_INTELLIGENCE_EMAIL;

-- 2. Add new recipients (must include existing ones)
ALTER NOTIFICATION INTEGRATION SNOWFLAKE_INTELLIGENCE_EMAIL 
SET ALLOWED_RECIPIENTS = (
    'existing@example.com',
    'new@example.com'
);

-- For Slack issues:
-- 1. Regenerate webhook URL in Slack
-- 2. Update secret
CREATE OR REPLACE SECRET my_slack_webhook_secret
    TYPE = GENERIC_STRING
    SECRET_STRING = 'T12345/B12345/new_secret';

-- 3. Recreate integration
-- Re-run lines 10-21 of agent_slack_tool.sql
```

### Issue: Queue Filling Up

**Symptoms:**
- Many PENDING results not being sent
- Results getting old

**Solutions:**
```sql
-- 1. Check notification task frequency
-- Increase frequency if needed
ALTER TASK SEND_SLACK_NOTIFICATIONS
SET SCHEDULE = 'USING CRON */5 * * * * EST';  -- Every 5 min

-- 2. Manually process pending
EXECUTE TASK SEND_SLACK_NOTIFICATIONS;

-- 3. Clean up old failed results
UPDATE AGENT_RESULTS_QUEUE 
SET status = 'CANCELLED'
WHERE status = 'FAILED' 
AND created_timestamp < DATEADD('day', -7, CURRENT_TIMESTAMP());

-- 4. Archive old results
CREATE TABLE AGENT_RESULTS_ARCHIVE AS
SELECT * FROM AGENT_RESULTS_QUEUE
WHERE created_timestamp < DATEADD('day', -30, CURRENT_TIMESTAMP());

DELETE FROM AGENT_RESULTS_QUEUE
WHERE created_timestamp < DATEADD('day', -30, CURRENT_TIMESTAMP());
```

### Issue: Performance/Cost Concerns

**Symptoms:**
- High warehouse costs
- Slow task execution

**Solutions:**
```sql
-- 1. Monitor warehouse usage
SELECT 
    WAREHOUSE_NAME,
    AVG(AVG_RUNNING) as avg_running_queries,
    SUM(CREDITS_USED) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
AND WAREHOUSE_NAME = 'SNOWFLAKE_INTELLIGENCE_WH'
GROUP BY WAREHOUSE_NAME;

-- 2. Reduce task frequency if needed
ALTER TASK SEND_SLACK_NOTIFICATIONS
SET SCHEDULE = 'USING CRON */30 * * * * EST';  -- Every 30 min

-- 3. Use smaller warehouse
ALTER TASK DAILY_SUPPORT_ANALYSIS
SET WAREHOUSE = 'XSMALL_WH';

-- 4. Set aggressive auto-suspend
ALTER WAREHOUSE SNOWFLAKE_INTELLIGENCE_WH 
SET AUTO_SUSPEND = 60;  -- 1 minute
```

## Advanced Customization

### Custom Analysis Types

Add new analysis workflows by modifying the agent query:

```sql
-- Example: Weekly sales analysis
CREATE OR REPLACE TASK WEEKLY_SALES_ANALYSIS
    WAREHOUSE = 'SNOWFLAKE_INTELLIGENCE_WH'
    SCHEDULE = 'USING CRON 0 8 * * MON EST'  -- Mondays at 8 AM
AS
BEGIN
    CALL SNOWFLAKE_INTELLIGENCE.TOOLS.call_cortex_agent_proc(
        'Analyze last week sales performance by region. 
         Include top products and growth metrics.'
    );
    
    INSERT INTO AGENT_RESULTS_QUEUE (
        analysis_type, title, summary, detailed_results, task_name
    )
    SELECT 
        'Weekly Sales Analysis',
        'Sales Performance - Week Ending ' || TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD'),
        response_text,
        response_text,
        'WEEKLY_SALES_ANALYSIS'
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
END;

ALTER TASK WEEKLY_SALES_ANALYSIS RESUME;
```

### Email Integration

Modify to send email instead of Slack:

```sql
-- Create email notification task
CREATE OR REPLACE TASK SEND_EMAIL_NOTIFICATIONS
    WAREHOUSE = 'SNOWFLAKE_INTELLIGENCE_WH'
    SCHEDULE = 'USING CRON */30 * * * * EST'
AS
BEGIN
    DECLARE
        notification_result STRING;
        current_record_id STRING;
        current_title STRING;
        current_summary STRING;
    BEGIN
        SELECT 
            result_id, 
            title,
            summary
        INTO 
            :current_record_id, 
            :current_title,
            :current_summary
        FROM PENDING_SLACK_NOTIFICATIONS 
        LIMIT 1;
        
        IF (current_record_id IS NOT NULL) THEN
            CALL SEND_EMAIL(
                'your-email@example.com',
                :current_title,
                :current_summary
            ) INTO :notification_result;
            
            UPDATE AGENT_RESULTS_QUEUE 
            SET 
                status = 'SENT',
                slack_sent_timestamp = CURRENT_TIMESTAMP()
            WHERE result_id = :current_record_id;
        END IF;
    END;
END;

ALTER TASK SEND_EMAIL_NOTIFICATIONS RESUME;
```

### Multi-Channel Notifications

Send to both Slack and email:

```sql
CREATE OR REPLACE PROCEDURE SEND_MULTI_CHANNEL_NOTIFICATION(
    result_id VARCHAR
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    DECLARE
        title STRING;
        summary STRING;
        slack_result STRING;
        email_result STRING;
    BEGIN
        -- Get result details
        SELECT r.title, r.summary
        INTO :title, :summary
        FROM AGENT_RESULTS_QUEUE r
        WHERE r.result_id = :result_id;
        
        -- Send to Slack
        CALL SEND_SLACK_NOTIFICATION(
            '🔔 *' || :title || '*\n\n' || :summary
        ) INTO :slack_result;
        
        -- Send to Email
        CALL SEND_EMAIL(
            'your-email@example.com',
            :title,
            :summary
        ) INTO :email_result;
        
        -- Update status
        UPDATE AGENT_RESULTS_QUEUE
        SET 
            status = 'SENT',
            slack_sent_timestamp = CURRENT_TIMESTAMP()
        WHERE result_id = :result_id;
        
        RETURN 'SUCCESS';
    END;
END;
$$;
```

## Best Practices

1. **Test Before Scheduling**
   - Always test agent calls manually first
   - Verify Slack/email integrations work
   - Run tasks with `EXECUTE TASK` before scheduling

2. **Monitor Regularly**
   - Check task history weekly
   - Monitor queue depth
   - Review failed notifications

3. **Security**
   - Keep webhook secrets secure
   - Limit allowed email recipients
   - Use role-based access control
   - Don't commit secrets to git

4. **Cost Management**
   - Use appropriate warehouse sizes
   - Set reasonable task frequencies
   - Implement auto-suspend on warehouses
   - Archive old results

5. **Error Handling**
   - Monitor FAILED status results
   - Set up alerts for task failures
   - Implement retry logic if needed
   - Keep debug logs for troubleshooting

## Related Documentation

- **Main README**: `../README.md` - Overall project setup and Slack bot
- **Cortex Agents**: [Snowflake Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- **Task Scheduling**: [Snowflake Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro)
- **Notification Integrations**: [Email](https://docs.snowflake.com/en/user-guide/notifications/email) | [Webhook](https://docs.snowflake.com/en/user-guide/notifications/webhook)

## Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Snowflake task history for error messages
3. Test components individually (agent → queue → notification)
4. Open an issue in the project repository

---

**Last Updated**: November 7, 2025
**Snowflake Version**: Compatible with Cortex-enabled accounts
**Required Role**: `SNOWFLAKE_INTELLIGENCE_ADMIN_RL` or equivalent

