-- This script sets up a tool for the Cortex Agent to send messages to a Slack channel.
-- The script creates a secret for the Slack webhook, creates a notification integration, and creates a stored procedure to send messages to Slack.
USE SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;
CREATE OR REPLACE SECRET my_slack_webhook_secret
    TYPE = GENERIC_STRING
    SECRET_STRING = 'Txxxxx/Bxxxxx/Sxxxx';
    -- ENSURE THE webhook secret first character starts with a T, also the next section must start with a B!
GRANT USAGE ON SECRET my_slack_webhook_secret TO ROLE PUBLIC;
GRANT USAGE ON SECRET my_slack_webhook_secret TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;

USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE NOTIFICATION INTEGRATION slack_webhook_integration
  TYPE=WEBHOOK
  ENABLED=TRUE
  WEBHOOK_URL='https://hooks.slack.com/services/SNOWFLAKE_WEBHOOK_SECRET'
  WEBHOOK_SECRET=SNOWFLAKE_INTELLIGENCE.TOOLS.my_slack_webhook_secret
  WEBHOOK_BODY_TEMPLATE='{"text": "SNOWFLAKE_WEBHOOK_MESSAGE"}'
  WEBHOOK_HEADERS=('Content-Type'='application/json');

SHOW GRANTS ON INTEGRATION slack_webhook_integration;
GRANT USAGE ON INTEGRATION slack_webhook_integration TO ROLE PUBLIC;
GRANT USAGE ON INTEGRATION slack_webhook_integration TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;

-- Multi-line test to ensure the slack webhook is working correctly.
-- Follow the instructions in the agent_slack_tool.sql file to ensure the slack webhook is working correctly.
CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
  SNOWFLAKE.NOTIFICATION.TEXT_PLAIN(
    SNOWFLAKE.NOTIFICATION.SANITIZE_WEBHOOK_CONTENT('Line 1\\nLine 2\\nLine 3')
  ),
  SNOWFLAKE.NOTIFICATION.INTEGRATION('slack_webhook_integration'));
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;
USE SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;

-- Create the slack notification sending stored procedure
CREATE OR REPLACE PROCEDURE SEND_SLACK_NOTIFICATION(
    slack_notification STRING
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS $$
BEGIN
    -- Escape newlines
    
    -- Send slack directly using Snowflake's notification system
    CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
        SNOWFLAKE.NOTIFICATION.TEXT_PLAIN(
            SNOWFLAKE.NOTIFICATION.SANITIZE_WEBHOOK_CONTENT(REPLACE(REPLACE(:slack_notification, '\r\n', '\\n'), '\n', '\\n'))
        ),
        SNOWFLAKE.NOTIFICATION.INTEGRATION('slack_webhook_integration')
    );
    
    -- Return success message
    RETURN OBJECT_CONSTRUCT(
        'status', 'success',
        'message', 'Slack Notification sent successfully',
        'slack_notification', :slack_notification,
        'timestamp', CURRENT_TIMESTAMP()::STRING
    )::STRING;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'error',
            'error', 'Failed to send slack notification',
            'details', SQLERRM,
            'slack_notification', :slack_notification,
            'timestamp', CURRENT_TIMESTAMP()::STRING
        )::STRING;
END;
$$;
SHOW GRANTS ON PROCEDURE SEND_SLACK_NOTIFICATION(STRING);
GRANT OWNERSHIP ON PROCEDURE SEND_SLACK_NOTIFICATION(STRING) TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;
GRANT USAGE ON PROCEDURE SEND_SLACK_NOTIFICATION(STRING) TO ROLE PUBLIC;
-- Example 1: Simple test slack
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_SLACK_NOTIFICATION(
    'This is a test notification to verify the slack tool is working correctly.

    If you receive this slack, the SEND_SLACK_NOTIFICATION procedure is functioning properly.

    Best regards,
    Snowflake Intelligence Slack Tool'
);
