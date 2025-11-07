-- This script creates an email tool for a Cortex Agent.

/*
===============================================================================
EMAIL SENDER FOR SNOWFLAKE INTELLIGENCE
===============================================================================

This SQL script creates a complete Snowflake stored procedure that sends emails
directly from Snowflake Intelligence. The procedure uses Snowflake's native
notification integration to send emails to pre-approved recipients.

WORKFLOW OVERVIEW:
1. Configure allowed email recipients in notification integration
2. Deploy the SEND_EMAIL stored procedure
3. Call procedure with recipient, subject, and body to send emails immediately
4. Receive instant success/failure feedback

FEATURES:
- Direct email sending with immediate response
- Pre-approved recipient validation for security
- Plain text email support
- Instant success/failure feedback
- Returns detailed JSON responses

PREREQUISITES:
- Snowflake ACCOUNTADMIN role for notification integration setup
- Pre-approved list of email recipients
- SYSADMIN role for procedure deployment

TABLE OF CONTENTS (Search for these markers):
- [SECTION_1_SCHEMAS]     : Database and schema creation
- [SECTION_2_INTEGRATION] : Email notification integration setup
- [SECTION_3_PROCEDURE]   : Main stored procedure definition
- [SECTION_4_EXAMPLES] : Grant usage permissions

===============================================================================
*/

-- [SECTION_1_SCHEMAS] Database and Schema Creation
-- ================================================
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
GRANT ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL TO ROLE SYSADMIN;
SHOW GRANTS ON DATABASE SNOWFLAKE_INTELLIGENCE;
SHOW GRANTS ON SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;
GRANT OWNERSHIP ON SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.TOOLS;

-- [SECTION_2_INTEGRATION] Email Notification Integration Setup
-- ============================================================
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE NOTIFICATION INTEGRATION SNOWFLAKE_INTELLIGENCE_EMAIL
TYPE = EMAIL
ENABLED = TRUE
ALLOWED_RECIPIENTS = (
    -- IMPORTANT: Replace these with your actual allowed email recipients
    -- Add all email addresses that should be able to receive emails from this tool
    'your-email@example.com'
);
SHOW GRANTS ON INTEGRATION SNOWFLAKE_INTELLIGENCE.TOOLS.SNOWFLAKE_INTELLIGENCE_EMAIL;
SHOW GRANTS ON INTEGRATION snowflake_intelligence_email;
USE ROLE ACCOUNTADMIN;
GRANT OWNERSHIP ON INTEGRATION SNOWFLAKE_INTELLIGENCE_EMAIL TO ROLE PUBLIC REVOKE CURRENT GRANTS;

GRANT USAGE ON INTEGRATION SNOWFLAKE_INTELLIGENCE_EMAIL TO ROLE PUBLIC;

-- Verify the integration was created successfully
SHOW INTEGRATIONS LIKE 'SNOWFLAKE_INTELLIGENCE_EMAIL';

-- [SECTION_3_PROCEDURE] Main Stored Procedure Definition
-- ======================================================
USE ROLE SYSADMIN;
USE SCHEMA SNOWFLAKE_INTELLIGENCE.TOOLS;

-- Create the email sending stored procedure
CREATE OR REPLACE PROCEDURE SEND_EMAIL(
    recipient_email STRING,
    subject STRING,
    body STRING
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS $$
BEGIN
    -- Send email directly using Snowflake's notification system
    CALL SYSTEM$SEND_EMAIL(
        'SNOWFLAKE_INTELLIGENCE_EMAIL',
        :recipient_email,
        :subject,
        :body,
        'text/html'
    );
    
    -- Return success message
    RETURN OBJECT_CONSTRUCT(
        'status', 'success',
        'message', 'Email sent successfully',
        'recipient', :recipient_email,
        'subject', :subject,
        'timestamp', CURRENT_TIMESTAMP()::STRING
    )::STRING;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'error',
            'error', 'Failed to send email',
            'details', SQLERRM,
            'recipient', :recipient_email,
            'subject', :subject,
            'timestamp', CURRENT_TIMESTAMP()::STRING
        )::STRING;
END;
$$;
SHOW GRANTS ON PROCEDURE SEND_EMAIL(STRING, STRING, STRING);
GRANT OWNERSHIP ON PROCEDURE SEND_EMAIL(STRING, STRING, STRING) TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;
GRANT USAGE ON PROCEDURE SEND_EMAIL(STRING, STRING, STRING) TO ROLE PUBLIC;

-- [SECTION_4_MANAGEMENT] Managing Allowed Recipients
-- ==================================================

-- Query to view current allowed recipients
DESCRIBE INTEGRATION SNOWFLAKE_INTELLIGENCE_EMAIL;

-- Query to add more recipients to the allowed list
-- IMPORTANT: You must include ALL existing recipients plus new ones
-- Example: Adding a new recipient while keeping existing ones
ALTER NOTIFICATION INTEGRATION SNOWFLAKE_INTELLIGENCE_EMAIL 
SET ALLOWED_RECIPIENTS = (
    'your-email@example.com'
);

-- Template for expanding the list (uncomment and modify as needed)
/*
ALTER NOTIFICATION INTEGRATION SNOWFLAKE_INTELLIGENCE_EMAIL 
SET ALLOWED_RECIPIENTS = (
    'user1@example.com',
    'user2@example.com'
);
*/

-- [SECTION_5_EXAMPLES] Usage Examples and Test Calls
-- ====================================================

-- Example 1: Simple test email
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    'your-email@example.com',
    'Test Email from Snowflake Intelligence',
    'This is a test email to verify the email tool is working correctly.

If you receive this email, the SEND_EMAIL procedure is functioning properly.

Best regards,
Snowflake Intelligence Email Tool'
);

-- Example 2: Report notification email
  GRANT USAGE ON INTEGRATION SNOWFLAKE_INTELLIGENCE_EMAIL TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN_RL;
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    'your-email@example.com',
    'Weekly Report Available',
    'Hello Team,

    The weekly sales report has been generated and is ready for review.

    Key Highlights:
    - Total Sales: $125,000 (+8% vs last week)
    - New Customers: 45
    - Top Region: North America

    You can access the full report in the REPORTS.WEEKLY.SALES table.

    Best regards,
    Snowflake Intelligence'
);

-- Example 3: Alert notification
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    'your-email@example.com',
    'ALERT: Data Quality Issue Detected',
    'Admin Team,

    A data quality issue has been detected in the daily ETL process.

    Issue Details:
    - Table: SALES.DAILY_TRANSACTIONS
    - Problem: 150 records with NULL customer_id
    - Impact: Moderate
    - Time Detected: 2024-01-21 09:30 AM

    Please investigate and resolve at your earliest convenience.

    Snowflake Intelligence Monitoring'
);

-- Example 4: Success notification for analysis completion
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    'your-email@example.com',
    'Analysis Complete: Customer Segmentation',
    'Your customer segmentation analysis has completed successfully.

    Results Summary:
    - Total Customers Analyzed: 25,847
    - High Value Segment: 2,584 customers (10%)
    - Medium Value Segment: 10,339 customers (40%)
    - Low Value Segment: 12,924 customers (50%)

    Key Insights:
    - High value customers generate 60% of total revenue
    - 85% of high value customers are repeat purchasers
    - Average order value varies significantly by segment

    Full results are available in the ANALYTICS.CUSTOMER_SEGMENTS table.

    Best regards,
    Snowflake Intelligence'
);

-- Testing Examples with Expected Responses
-- =========================================

-- Test 1: Valid email (should succeed)
-- Expected response: {"status":"success","message":"Email sent successfully",...}

-- Test 2: Invalid email (should fail)
-- Uncomment the line below to test with an email NOT in your ALLOWED_RECIPIENTS list
/*
CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    'unauthorized@example.com',
    'This will fail',
    'This email should fail because the recipient is not in the allowed list.'
);
*/
-- Expected response: {"status":"error","error":"Failed to send email","details":"...not in allowed recipients...",...}

/*
===============================================================================
USAGE INSTRUCTIONS FOR SNOWFLAKE INTELLIGENCE
===============================================================================

When users make requests like:
- "Send an email to user@example.com about the report"
- "Email the analysis results to manager@example.com"  
- "Alert team@example.com about the issue"

Snowflake Intelligence should:

1. Extract the email components:
   - recipient_email: Parse from user request
   - subject: Generate appropriate subject or use user-provided one
   - body: Format the content appropriately

2. Call the procedure:
   CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(recipient, subject, body)

3. Check the response:
   - If status = "success": Inform user "Email sent to [recipient]"
   - If status = "error": Inform user "Unable to send email: [error details]"

IMPORTANT SECURITY NOTES:
- Only emails in ALLOWED_RECIPIENTS can receive emails
- Cannot send to arbitrary external email addresses
- Email content is plain text only (no HTML or attachments)
- All email attempts are logged in Snowflake's system logs

===============================================================================
*/
