-- This script sets up a schedule for a Cortex Agent to run at a specific time.
-- ONLY do this after setting up the slack tool! Follow steps in the agent_slack_tool.sql file to ensure the slack tool is working correctly.

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;
USE SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;
-- Quickstart based: https://www.snowflake.com/en/developers/guides/getting-started-with-microsoft-copilot-studio-and-cortex-agents/#0
-- Code for API: https://github.com/sfc-gh-jkang/snowflake-cortex-agents-with-slack/blob/master/app.py
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;
GRANT OWNERSHIP ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.call_cortex_agent_proc(STRING) TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL; 

CREATE OR REPLACE PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.call_cortex_agent_proc(query STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.13'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'call_sales_intelligence_agent_proc'
EXECUTE AS CALLER
AS $$
import json
import _snowflake
import logging

logger = logging.getLogger("mylog")

def call_sales_intelligence_agent_proc(session, query: str):
    logger.info(f"Logging with attributes in SP, query = {query}")
    logger.info(f"Logging session info, session = {session}")
    result_json = session.sql("SELECT CURRENT_USER()").collect()
    current_user = result_json[0][0]
    result_role_json = session.sql("SELECT CURRENT_ROLE()").collect()
    current_role = result_role_json[0][0]
    result_wh_json = session.sql("SELECT CURRENT_WAREHOUSE()").collect()
    current_wh = result_wh_json[0][0]
    logger.info(f"current user is: {current_user}, current role is: {current_role}, warehouse is: {current_wh}")
    
    API_ENDPOINT = "/api/v2/databases/SNOWFLAKE_INTELLIGENCE/schemas/agents/agents/SLACK_SUPPORT_AI:run"
    API_TIMEOUT = 300000  # this can be adjusted - 5 minutes = 5min*60s/min*1000ms/s
    
    # Force very quick response
    speed_query = f"Quick answer: {query}"

    payload = {
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": speed_query
                    }
                ]
            }
        ]
    }

    try:
        resp = _snowflake.send_snow_api_request(
            "POST", API_ENDPOINT, {}, {}, payload, None, API_TIMEOUT
        )
        logger.info(f"API Response = {resp}")
        logger.info(f"API status = {resp['status']}")


        if resp["status"] != 200:
            return f"Error: {resp['status']}"

        response_content = json.loads(resp["content"])
        
        # Super fast processing - take first text found
        for event in response_content:
            event_type = event.get("event")
            
            if event_type == "response.text":
                logger.info(f'API response text = {event.get("data", {}).get("text", "")}')
                return event.get("data", {}).get("text", "")
            elif event_type == "response.text.delta":
                text = event.get("data", {}).get("delta", {}).get("text", "")
                if text:
                    return text  # Return immediately on first text chunk
        
        return "No response within time limit"

    except Exception as e:
        logger.error("Logging an error from Python handler: ")
        logger.error(f"error is: {e}")
        return f"Timeout or error: {str(e)}"
$$;
-- Test the call_cortex_agent_proc procedure to ensure it sends an email
-- ENSURE the email address is in the ALLOWED_RECIPIENTS list in the send_email procedure
-- Follow steps in the agent_email_tool.sql file to ensure the email is sent.
call SNOWFLAKE_INTELLIGENCE.TOOLS.call_cortex_agent_proc('Can you show me a breakdown of customer support tickets by service type cellular vs business internet? Send results to your-email@example.com');
-- 1. Create results storage table
USE SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;
CREATE OR REPLACE TABLE AGENT_RESULTS_QUEUE (
    result_id VARCHAR(50) DEFAULT CONCAT('AR_', TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISSFF3')),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    analysis_type VARCHAR(100),
    title VARCHAR(500),
    summary TEXT,
    detailed_results TEXT,
    status VARCHAR(20) DEFAULT 'PENDING',
    slack_sent_timestamp TIMESTAMP_NTZ,
    task_name VARCHAR(100),
    PRIMARY KEY (result_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES ON TABLE SNOWFLAKE_INTELLIGENCE.TOOLS.AGENT_RESULTS_QUEUE TO ROLE PUBLIC;
-- 2. SP for Agent to store results
DROP PROCEDURE STORE_AGENT_RESULTS(VARCHAR, VARCHAR, TEXT, TEXT, VARCHAR);
CREATE OR REPLACE PROCEDURE STORE_AGENT_RESULTS(
    ANALYSIS_TYPE VARCHAR,
    TITLE VARCHAR,
    SUMMARY VARCHAR,
    DETAILED_RESULTS VARCHAR DEFAULT NULL,
    TASK_NAME VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result_id = 'AR_' + new Date().toISOString().replace(/[-:T.]/g, '').substring(0, 17);
    
    var sql_command = `
        INSERT INTO AGENT_RESULTS_QUEUE (
            result_id,
            analysis_type,
            title,
            summary,
            detailed_results,
            task_name
        ) VALUES (
            '${result_id}',
            ?,
            ?,
            ?,
            ?,
            ?
        )`;
    
    var stmt = snowflake.createStatement({
        sqlText: sql_command,
        binds: [ANALYSIS_TYPE, TITLE, SUMMARY, DETAILED_RESULTS, TASK_NAME]
    });
    stmt.execute();
    
    return result_id;
$$;
GRANT USAGE ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.STORE_AGENT_RESULTS(VARCHAR, VARCHAR, TEXT, TEXT, VARCHAR) TO ROLE PUBLIC;


-- 3. View to retrieve pending results for slack
CREATE OR REPLACE VIEW PENDING_SLACK_NOTIFICATIONS AS
SELECT 
    result_id,
    created_timestamp,
    analysis_type,
    title,
    summary,
    detailed_results,
    task_name
FROM AGENT_RESULTS_QUEUE 
WHERE status = 'PENDING'
ORDER BY created_timestamp ASC;

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.PENDING_SLACK_NOTIFICATIONS TO ROLE PUBLIC;


-- 4. SP To mark results sent
CREATE OR REPLACE PROCEDURE MARK_SLACK_SENT(RESULT_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    UPDATE AGENT_RESULTS_QUEUE 
    SET 
        status = 'SENT',
        slack_sent_timestamp = CURRENT_TIMESTAMP()
    WHERE result_id = RESULT_ID;
    
    RETURN 'SUCCESS';
END;
$$;

GRANT USAGE ON PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.MARK_SLACK_SENT(VARCHAR) TO ROLE PUBLIC;

-- 5. Usage in agent/task example
-- Your Task calls the agent with modified instructions
-- Do this after setting up the tools as custom tools for the agent! Follow steps in the agent_slack_tool.sql file to ensure the slack tool is working correctly.
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.call_cortex_agent_proc(
    'Can you show me a breakdown of customer support tickets by service type cellular vs business internet? 
    DO NOT CREATE A CHART, only text.
     Instead of sending via email or Slack, please call STORE_AGENT_RESULTS procedure with:
     - ANALYSIS_TYPE: "Support Ticket Analysis"  
     - TITLE: "Customer Support Tickets by Service Type"
     - SUMMARY: Include key metrics and insights in Slack-ready format
     - DETAILED_RESULTS: JSON with the raw data
     - TASK_NAME: "DAILY_SUPPORT_ANALYSIS_TASK"'
);
-- 6. Schedule the task
CREATE OR REPLACE TASK DAILY_SUPPORT_ANALYSIS
    WAREHOUSE = 'SNOWFLAKE_INTELLIGENCE_WH'  
    SCHEDULE = 'USING CRON 0 9 * * * EST'
AS
BEGIN
    -- Call the stored procedure
    CALL SNOWFLAKE_INTELLIGENCE.TOOLS.call_cortex_agent_proc(
        'Analyze customer support tickets by service type cellular vs business internet. 
         Format results for Slack with emojis and key metrics.'
    );
    
    -- Capture the actual response using RESULT_SCAN
    INSERT INTO AGENT_RESULTS_QUEUE (
        analysis_type,
        title,
        summary,
        detailed_results,
        task_name
    )
    SELECT 
        'Support Ticket Analysis',
        'Daily Support Ticket Breakdown',
        response_text,
        response_text,
        'DAILY_SUPPORT_ANALYSIS_TASK'
    FROM (
        SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    ) AS results(response_text);  -- Alias the column from RESULT_SCAN
END;
ALTER TASK DAILY_SUPPORT_ANALYSIS RESUME;
EXECUTE TASK DAILY_SUPPORT_ANALYSIS;

-- 7. Schedule the task to send notifications to slack
-- First, let's create a simple log table to see what's happening
CREATE OR REPLACE TABLE TASK_DEBUG_LOG (
    log_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    step_name VARCHAR(100),
    record_id VARCHAR(50),
    message_content TEXT,
    procedure_result TEXT,
    parsed_status VARCHAR(50)
);

create or replace task SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_SLACK_NOTIFICATIONS
	warehouse=SNOWFLAKE_INTELLIGENCE_WH
	schedule='USING CRON */15 * * * * EST'
	as BEGIN
    DECLARE
        notification_result STRING;
        result_status STRING;
        current_record_id STRING;
        current_message STRING;
    BEGIN
        -- Get one record (same format that worked in Step 1)
        SELECT result_id, 
               CONCAT(
                   '🔔 *', title, '*\n\n',
                   '📊 **Summary:** ', summary, '\n\n',
                   -- '📋 **Details:** ', detailed_results, '\n\n', -- ignored because for now details and summary are the same
                   '⏰ **Generated:** ', created_timestamp::STRING
               )
        INTO :current_record_id, :current_message
        FROM PENDING_SLACK_NOTIFICATIONS 
        LIMIT 1;
        
        -- Only proceed if we found a record
        IF (current_record_id IS NOT NULL) THEN
            -- Send the notification
            CALL SEND_SLACK_NOTIFICATION(:current_message) INTO :notification_result;
            
            -- Parse the result
            SET result_status = PARSE_JSON(:notification_result):status::STRING;
            
            -- Update based on result
            IF (result_status = 'success') THEN
                UPDATE AGENT_RESULTS_QUEUE 
                SET 
                    status = 'SENT',
                    slack_sent_timestamp = CURRENT_TIMESTAMP()
                WHERE result_id = :current_record_id;
            ELSE
                UPDATE AGENT_RESULTS_QUEUE 
                SET status = 'FAILED'
                WHERE result_id = :current_record_id;
            END IF;
        END IF;
        
    EXCEPTION
        WHEN OTHER THEN
            UPDATE AGENT_RESULTS_QUEUE 
            SET status = 'FAILED'
            WHERE result_id = :current_record_id;
    END;
END;
ALTER TASK SEND_SLACK_NOTIFICATIONS RESUME;
EXECUTE TASK SEND_SLACK_NOTIFICATIONS;

-- OVERALL TEST
EXECUTE TASK DAILY_SUPPORT_ANALYSIS;
-- See results
SELECT * FROM SNOWFLAKE_INTELLIGENCE.TOOLS.PENDING_SLACK_NOTIFICATIONS;
-- Send notifications to slack
EXECUTE TASK SEND_SLACK_NOTIFICATIONS;
-- See results and make sure all results are sent to slack 
SELECT * FROM SNOWFLAKE_INTELLIGENCE.TOOLS.AGENT_RESULTS_QUEUE;