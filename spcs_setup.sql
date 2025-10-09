-- ==============================================================================
-- Snowflake Cortex Agents Slack Bot - SPCS Infrastructure Setup
-- ==============================================================================
-- This script sets up the complete infrastructure needed to run the Slack bot
-- in Snowpark Container Services (SPCS)
--
-- Reference: https://github.com/sfc-gh-jkang/cortex-cost-app-spcs
-- ==============================================================================

-- ==============================================================================
-- PREREQUISITES
-- ==============================================================================
-- 1. You must have ACCOUNTADMIN role for initial setup
-- 2. SPCS must be enabled in your Snowflake account
-- 3. Docker installed locally for building images
-- 4. Snowflake CLI installed (pip install snowflake-cli-labs)
-- 
-- Note: This script grants privileges to SNOWFLAKE_INTELLIGENCE_ADMIN role
--       which can then be used for deployment and ongoing management
-- ==============================================================================

-- Set role to ACCOUNTADMIN for setup
USE ROLE ACCOUNTADMIN;

-- ==============================================================================
-- STEP 1: CREATE DATABASE AND SCHEMAS
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS CORTEX_SLACK_BOT_DB
    COMMENT = 'Database for Cortex Agents Slack Bot running in SPCS';

USE DATABASE CORTEX_SLACK_BOT_DB;

-- Schema for Docker images
CREATE SCHEMA IF NOT EXISTS IMAGE_SCHEMA
    COMMENT = 'Schema for Docker image repository';

-- Schema for SPCS service and application objects
CREATE SCHEMA IF NOT EXISTS APP_SCHEMA
    COMMENT = 'Schema for SPCS service and related objects';

-- Verify database and schemas
SHOW DATABASES LIKE 'CORTEX_SLACK_BOT_DB';
SHOW SCHEMAS IN DATABASE CORTEX_SLACK_BOT_DB;

-- ==============================================================================
-- STEP 2: CREATE IMAGE REPOSITORY
-- ==============================================================================

USE SCHEMA CORTEX_SLACK_BOT_DB.IMAGE_SCHEMA;

CREATE IMAGE REPOSITORY IF NOT EXISTS IMAGE_REPO
    COMMENT = 'Repository for Cortex Slack Bot Docker images';

-- Show repository URL (IMPORTANT: Save this URL for docker login)
SHOW IMAGE REPOSITORIES IN SCHEMA IMAGE_SCHEMA;

-- Get the repository URL in a more readable format
SELECT 
    "name" AS repository_name,
    "repository_url" AS repository_url,
    "created_on"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ==============================================================================
-- STEP 3: CREATE COMPUTE POOL
-- ==============================================================================

-- Create compute pool for running the service
-- Instance types: CPU_X64_XS (smallest), CPU_X64_S, CPU_X64_M, CPU_X64_L
CREATE COMPUTE POOL IF NOT EXISTS CORTEX_SLACK_BOT_POOL
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = CPU_X64_XS
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 3600  -- Suspend after 1 hour of inactivity
    COMMENT = 'Compute pool for Cortex Slack Bot service';

-- Verify compute pool creation
SHOW COMPUTE POOLS LIKE 'CORTEX_SLACK_BOT_POOL';

-- Check compute pool status and details
SELECT 
    "name",
    "state",
    "instance_family",
    "min_nodes",
    "max_nodes",
    "num_services",
    "num_jobs",
    "auto_suspend_secs",
    "created_on"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ==============================================================================
-- STEP 4: CREATE NETWORK RULES FOR EXTERNAL ACCESS
-- ==============================================================================

USE SCHEMA CORTEX_SLACK_BOT_DB.APP_SCHEMA;

-- Network rule for Slack API access
CREATE OR REPLACE NETWORK RULE slack_api_network_rule
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'slack.com:443',
        'api.slack.com:443', 
        'hooks.slack.com:443',
        'files.slack.com:443',
        'wss-primary.slack.com:443',
        'wss-backup.slack.com:443'
    )
    COMMENT = 'Network rule for Slack API and Socket Mode connections';

-- Network rule for Snowflake Cortex endpoints
CREATE OR REPLACE NETWORK RULE snowflake_cortex_network_rule
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('*.snowflakecomputing.com:443')
    COMMENT = 'Network rule for Snowflake Cortex Agent API access';

-- Show network rules
SHOW NETWORK RULES IN SCHEMA APP_SCHEMA;

-- ==============================================================================
-- STEP 5: CREATE EXTERNAL ACCESS INTEGRATION
-- ==============================================================================

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION slack_external_access_integration
    ALLOWED_NETWORK_RULES = (slack_api_network_rule, snowflake_cortex_network_rule)
    ENABLED = TRUE
    COMMENT = 'External access for Slack Bot to communicate with Slack and Snowflake APIs';

-- Verify external access integration
SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'slack_external_access_integration';

DESC EXTERNAL ACCESS INTEGRATION slack_external_access_integration;

-- ==============================================================================
-- STEP 6: CREATE STAGE FOR SERVICE SPECIFICATIONS
-- ==============================================================================

USE SCHEMA CORTEX_SLACK_BOT_DB.APP_SCHEMA;

CREATE STAGE IF NOT EXISTS APP_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Stage for SPCS service specifications and configuration files';

-- Verify stage creation
SHOW STAGES LIKE 'APP_STAGE' IN SCHEMA APP_SCHEMA;

DESC STAGE APP_STAGE;

-- ==============================================================================
-- STEP 7: CREATE WAREHOUSE (Optional but Recommended)
-- ==============================================================================

-- Create a small warehouse for service management queries
-- You can skip this if you have an existing warehouse
CREATE WAREHOUSE IF NOT EXISTS CORTEX_SLACK_BOT_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Slack Bot service management';

-- Show warehouse
SHOW WAREHOUSES LIKE 'CORTEX_SLACK_BOT_WH';

-- ==============================================================================
-- STEP 8: GRANT PERMISSIONS TO SNOWFLAKE_INTELLIGENCE_ADMIN ROLE
-- ==============================================================================

-- Grant privileges to SNOWFLAKE_INTELLIGENCE_ADMIN role for deployment and management
-- This allows the role to deploy and manage the service without ACCOUNTADMIN

SET my_role = 'SNOWFLAKE_INTELLIGENCE_ADMIN';

-- Database and schema privileges
GRANT USAGE ON DATABASE CORTEX_SLACK_BOT_DB TO ROLE IDENTIFIER($my_role);
GRANT USAGE ON SCHEMA CORTEX_SLACK_BOT_DB.IMAGE_SCHEMA TO ROLE IDENTIFIER($my_role);
GRANT USAGE ON SCHEMA CORTEX_SLACK_BOT_DB.APP_SCHEMA TO ROLE IDENTIFIER($my_role);

-- Image repository privileges
GRANT READ ON IMAGE REPOSITORY CORTEX_SLACK_BOT_DB.IMAGE_SCHEMA.IMAGE_REPO TO ROLE IDENTIFIER($my_role);
GRANT WRITE ON IMAGE REPOSITORY CORTEX_SLACK_BOT_DB.IMAGE_SCHEMA.IMAGE_REPO TO ROLE IDENTIFIER($my_role);

-- Compute pool privileges
GRANT USAGE ON COMPUTE POOL CORTEX_SLACK_BOT_POOL TO ROLE IDENTIFIER($my_role);
GRANT MONITOR ON COMPUTE POOL CORTEX_SLACK_BOT_POOL TO ROLE IDENTIFIER($my_role);
GRANT OPERATE ON COMPUTE POOL CORTEX_SLACK_BOT_POOL TO ROLE IDENTIFIER($my_role);

-- Stage privileges
GRANT READ ON STAGE CORTEX_SLACK_BOT_DB.APP_SCHEMA.APP_STAGE TO ROLE IDENTIFIER($my_role);
GRANT WRITE ON STAGE CORTEX_SLACK_BOT_DB.APP_SCHEMA.APP_STAGE TO ROLE IDENTIFIER($my_role);

-- Warehouse privileges (optional)
GRANT USAGE ON WAREHOUSE CORTEX_SLACK_BOT_WH TO ROLE IDENTIFIER($my_role);
GRANT OPERATE ON WAREHOUSE CORTEX_SLACK_BOT_WH TO ROLE IDENTIFIER($my_role);

-- External access integration privileges
GRANT USAGE ON INTEGRATION slack_external_access_integration TO ROLE IDENTIFIER($my_role);

-- Cortex Agent access privileges
-- IMPORTANT: Grant access to your Cortex Agent database and schema
GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE IDENTIFIER($my_role);
GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE IDENTIFIER($my_role);

-- Grant access to the DASH_AGENT_SLACK.DATA database and schema as well! Some of the cortex search services need this!
GRANT USAGE ON CORTEX SEARCH SERVICE DASH_AGENT_SLACK.DATA.VEHICLES_INFO TO ROLE PUBLIC;

GRANT USAGE ON DATABASE DASH_AGENT_SLACK TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA DASH_AGENT_SLACK.DATA TO ROLE PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA DASH_AGENT_SLACK.DATA TO ROLE PUBLIC;
GRANT READ ON STAGE DASH_AGENT_SLACK.DATA.SEMANTIC_MODELS TO ROLE PUBLIC;
-- If you need to grant access to specific agents, uncomment and modify:
-- GRANT USAGE ON CORTEX AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.<your_agent_name> TO ROLE IDENTIFIER($my_role);

-- Service management privileges (grant after service is created)
-- Uncomment these after the service is created to allow role to manage it
-- GRANT USAGE ON SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE TO ROLE IDENTIFIER($my_role);
-- GRANT MONITOR ON SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE TO ROLE IDENTIFIER($my_role);
-- GRANT OPERATE ON SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE TO ROLE IDENTIFIER($my_role);

-- FOR VERY PERMISSIVE SETUPS to get this working grant these 

-- ==============================================================================
-- STEP 9: VALIDATION QUERIES
-- ==============================================================================

-- Run these queries to verify your setup is complete

-- Check database exists
SELECT 'Database' AS object_type, COUNT(*) AS count 
FROM INFORMATION_SCHEMA.DATABASES 
WHERE DATABASE_NAME = 'CORTEX_SLACK_BOT_DB';

-- Check image repository exists
SHOW IMAGE REPOSITORIES IN SCHEMA CORTEX_SLACK_BOT_DB.IMAGE_SCHEMA;
SELECT 'Image Repository' AS object_type, COUNT(*) AS count
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" = 'IMAGE_REPO';

-- Check compute pool exists
SHOW COMPUTE POOLS LIKE 'CORTEX_SLACK_BOT_POOL';
SELECT 'Compute Pool' AS object_type, COUNT(*) AS count
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" = 'CORTEX_SLACK_BOT_POOL';

-- Check stage exists
SHOW STAGES IN SCHEMA CORTEX_SLACK_BOT_DB.APP_SCHEMA;
SELECT 'Stage' AS object_type, COUNT(*) AS count
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" = 'APP_STAGE';

-- Show compute pool status
SHOW COMPUTE POOLS LIKE 'CORTEX_SLACK_BOT_POOL';
SELECT 
    "name" AS pool_name,
    "state" AS pool_state,
    "instance_family",
    "auto_suspend_secs" / 60 AS auto_suspend_minutes
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ==============================================================================
-- DEPLOYMENT INSTRUCTIONS
-- ==============================================================================

/*
NEXT STEPS FOR DEPLOYMENT:

1. SAVE REPOSITORY URL
   - Copy the repository_url from Step 2 output
   - Format: <orgname>-<account>.registry.snowflakecomputing.com/cortex_slack_bot_db/image_schema/image_repo

2. CONFIGURE ENVIRONMENT VARIABLES
   - Copy template: cp spcs-env-template.yaml spcs-env.yaml
   - Edit spcs-env.yaml with your Slack and Snowflake credentials
   - Use SNOWFLAKE_INTELLIGENCE_ADMIN role (or another role with granted privileges)
   - See QUICKSTART.md for details

3. DEPLOY USING SCRIPT
   - Run: ./deploy.sh --connection your-connection-name
   - Make sure your connection uses SNOWFLAKE_INTELLIGENCE_ADMIN role (or another role with privileges)
   - This will:
     a) Build Docker image for linux/amd64
     b) Push image to Snowflake registry
     c) Upload service specification
     d) Create SPCS service
     e) Display service status and logs

4. VERIFY DEPLOYMENT
   - Check service status:
     SELECT SYSTEM$GET_SERVICE_STATUS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE');
   
   - View logs:
     SELECT SYSTEM$GET_SERVICE_LOGS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE', '0', 'cortex-slack-bot', 100);
   
   - Show endpoints:
     SHOW ENDPOINTS IN SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE;

5. TEST THE BOT
   - Send a message to your Slack bot
   - Verify response in Slack
   - Check service logs for any errors
*/

-- ==============================================================================
-- SERVICE MANAGEMENT COMMANDS
-- ==============================================================================

-- These commands are for managing the service after deployment

-- Check service status
-- SELECT SYSTEM$GET_SERVICE_STATUS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE');

-- Get service logs (last 100 lines)
-- SELECT SYSTEM$GET_SERVICE_LOGS('CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE', '0', 'cortex-slack-bot', 100);

-- Show service details
-- SHOW SERVICES IN SCHEMA CORTEX_SLACK_BOT_DB.APP_SCHEMA;

-- Show service endpoints
-- SHOW ENDPOINTS IN SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE;

-- Suspend service (to save costs when not in use)
-- ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE SUSPEND;

-- Resume service
-- ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE RESUME;

-- Update service with new image or spec
-- ALTER SERVICE CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE
--   FROM @CORTEX_SLACK_BOT_DB.APP_SCHEMA.APP_STAGE
--   SPEC = 'spcs-env.yaml';

-- Drop service (if you need to recreate it)
-- DROP SERVICE IF EXISTS CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE;

-- ==============================================================================
-- COMPUTE POOL MANAGEMENT
-- ==============================================================================

-- Show compute pool status
-- SHOW COMPUTE POOLS LIKE 'CORTEX_SLACK_BOT_POOL';

-- Suspend compute pool manually
-- ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL SUSPEND;

-- Resume compute pool
-- ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL RESUME;

-- Modify auto-suspend time (in seconds)
-- ALTER COMPUTE POOL CORTEX_SLACK_BOT_POOL SET AUTO_SUSPEND_SECS = 300;  -- 5 minutes

-- ==============================================================================
-- TROUBLESHOOTING QUERIES
-- ==============================================================================

-- Check if compute pool is active
-- SELECT "state" FROM (SHOW COMPUTE POOLS LIKE 'CORTEX_SLACK_BOT_POOL');

-- List all images in repository
-- SHOW IMAGES IN IMAGE REPOSITORY CORTEX_SLACK_BOT_DB.IMAGE_SCHEMA.IMAGE_REPO;

-- Check stage contents
-- LIST @CORTEX_SLACK_BOT_DB.APP_SCHEMA.APP_STAGE;

-- View network rules
-- SHOW NETWORK RULES IN SCHEMA CORTEX_SLACK_BOT_DB.APP_SCHEMA;

-- Check external access integrations
-- SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'slack_external_access_integration';

-- ==============================================================================
-- CLEANUP (USE WITH CAUTION)
-- ==============================================================================

-- Uncomment and run these commands only if you want to completely remove everything

/*
-- Drop service first
DROP SERVICE IF EXISTS CORTEX_SLACK_BOT_DB.APP_SCHEMA.CORTEX_SLACK_BOT_SERVICE;

-- Drop compute pool (will fail if service is still using it)
DROP COMPUTE POOL IF EXISTS CORTEX_SLACK_BOT_POOL;

-- Drop external access integration
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS slack_external_access_integration;

-- Drop network rules
DROP NETWORK RULE IF EXISTS CORTEX_SLACK_BOT_DB.APP_SCHEMA.slack_api_network_rule;
DROP NETWORK RULE IF EXISTS CORTEX_SLACK_BOT_DB.APP_SCHEMA.snowflake_cortex_network_rule;

-- Drop warehouse (optional)
DROP WAREHOUSE IF EXISTS CORTEX_SLACK_BOT_WH;

-- Drop database (this will drop everything)
DROP DATABASE IF EXISTS CORTEX_SLACK_BOT_DB;
*/

-- ==============================================================================
-- SETUP COMPLETE! 
-- ==============================================================================
-- 
-- Your SPCS infrastructure is now ready for deployment.
-- Privileges have been granted to SNOWFLAKE_INTELLIGENCE_ADMIN role.
-- 
-- Quick Start:
--   1. Copy repository URL from Step 2 output
--   2. Configure environment variables: cp spcs-env-template.yaml spcs-env.yaml
--   3. Ensure your Snowflake CLI connection uses SNOWFLAKE_INTELLIGENCE_ADMIN role
--   4. Deploy: ./deploy.sh --connection your-connection-name
--   5. Verify: Check service logs and test in Slack
--
-- For detailed instructions, see:
--   - README.md (Complete documentation)
--   - QUICKSTART.md (Quick command reference)
-- ==============================================================================