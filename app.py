"""
Snowflake Cortex Agents Slack Bot

A Slack bot powered by Snowflake Cortex Agents that provides intelligent responses
using natural language processing and real-time data analysis.

Author: John Kang <john.kang@snowflake.com>
License: Apache-2.0
"""

from typing import Any
import os
import re
import logging
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
import snowflake.connector
from snowflake.core import Root
from dotenv import load_dotenv
import snowflake.connector 
from snowflake.snowpark.session import Session
import cortex_chat

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

load_dotenv()

ACCOUNT = os.getenv("ACCOUNT")
HOST = os.getenv("HOST")
USER = os.getenv("DEMO_USER")
ROLE = os.getenv("DEMO_USER_ROLE")
WAREHOUSE = os.getenv("WAREHOUSE")
SLACK_APP_TOKEN = os.getenv("SLACK_APP_TOKEN")
SLACK_BOT_TOKEN = os.getenv("SLACK_BOT_TOKEN")
AGENT_ENDPOINT = os.getenv("AGENT_ENDPOINT")
PAT = os.getenv("PAT")

# Default warehouse for SPCS deployment (fallback if WAREHOUSE not set)
DEFAULT_SPCS_WAREHOUSE = os.getenv("DEFAULT_SPCS_WAREHOUSE", "CORTEX_SLACK_BOT_WH")

DEBUG = False  # Set to True for detailed logging during development

# Initializes app
app = App(token=SLACK_BOT_TOKEN)
messages = []

@app.message("hello")
def message_hello(message, say):
    build = """
Not a developer was stirring, all deep in the fight.
The code was deployed in the pipelines with care,
In hopes that the features would soon be there.

And execs, so eager to see the results,
Were prepping their speeches, avoiding the gulps.
When, what to my wondering eyes should appear,
But a slide-deck update, with a demo so clear!

And we shouted out to developers,
Let's launch this build live and avoid any crash!
The demos they created, the videos they made,
Were polished and ready, the hype never delayed.
            """

    say(build)
    say(
        text = "Let's BUILD",
        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f":snowflake: Let's BUILD!",
                }
            },
        ]                
    )

# Global storage for planning steps data
planning_steps_data = {}

@app.event("app_mention")
def handle_app_mention(event, say, client, body):
    """Handle direct mentions of the bot."""
    handle_message_event(event, say, client, body)

@app.message(re.compile(".*"))
def handle_direct_message(message, say, client, body):
    """Handle direct messages to the bot."""
    # Only respond to direct messages (not in channels unless mentioned)
    if message.get('channel_type') == 'im':
        handle_message_event(message, say, client, body)

def handle_message_event(event, say, client, body):
    """Main handler for processing user messages with Cortex Agent."""
    try:
        user_message = event.get('text', '').strip()
        if not user_message:
            return
        
        # Remove bot mention if present
        user_message = re.sub(r'<@\w+>', '', user_message).strip()
        
        if not user_message:
            say("👋 Hi! Ask me any question about your data and I'll help you analyze it using Snowflake Cortex.")
            return
        
        # Initialize Cortex chat if not available
        global CORTEX_APP
        if not CORTEX_APP:
            say("❌ Cortex Agent not initialized. Please check your configuration.")
            return
        
        # Set up Slack communication for real-time updates
        CORTEX_APP.set_slack_say_function(say)
        CORTEX_APP.set_slack_app(app, event.get('channel'))
        
        say(
            text="🚀 Starting Cortex Agent...",
            blocks=[
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": ":snowflake: *Snowflake Cortex Agent* is processing your request...\n_You'll see real-time updates as the agent works!_",
                    }
                },
                {
                    "type": "divider"
                },
            ]
        )
        
        # Get response with real-time streaming
        response = CORTEX_APP.chat(user_message)
        
        # Display final response
        display_agent_response(response, say)
        
    except Exception as e:
        error_info = f"{type(e).__name__} at line {e.__traceback__.tb_lineno} of {__file__}: {e}"
        logger.error(f"Error in handle_message_event: {error_info}")
        say(f"❌ Sorry, there was an error processing your message: {str(e)}")

@app.action("show_planning_details")
def handle_planning_details_toggle(ack, body, say):
    """Handle planning details show/hide toggle."""
    ack()
    
    try:
        # Get the current button value to determine action
        action_value = body["actions"][0]["value"]
        message_ts = body["message"]["ts"]
        channel_id = body["channel"]["id"]
        
        # Get timeline or fallback to separate arrays
        try:
            timeline = getattr(CORTEX_APP, 'timeline', [])
            # Fallback to separate arrays if timeline not available
            if not timeline:
                steps = getattr(CORTEX_APP, 'planning_steps', [])
                thinking_steps = getattr(CORTEX_APP, 'thinking_steps', [])
            else:
                steps = []
                thinking_steps = []
        except:
            timeline = []
            steps = planning_steps_data.get('steps', [])
            thinking_steps = []
        
        if action_value == "show":
            # Show detailed planning steps with verification and SQL info
            blocks = [
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*🤔 Thinking...* ✅ *Completed!*"
                    }
                }
            ]
            
            # Add planning steps and thinking content in chronological order
            combined_steps = []
            
            if timeline:
                # Use chronological timeline for proper ordering
                for event in timeline:
                    if event['type'] == 'status':
                        combined_steps.append(f" {event['content']}")
                    elif event['type'] == 'thinking':
                        combined_steps.append(f" {event['content']}")
            else:
                # Fallback to separate arrays (old behavior)
                # Add status steps
                if steps:
                    for step in steps:
                        combined_steps.append(f" {step}")
                
                # Add thinking steps without truncation for full content display
                if thinking_steps:
                    for thinking in thinking_steps:
                        # Don't truncate thinking content - users want to see complete thoughts
                        combined_steps.append(f" {thinking}")
            
            if combined_steps:
                # Build the text but ensure it doesn't exceed Slack's 3000 character limit
                header = "*Thinking Steps:*\n"
                max_content_length = 2950 - len(header)  # Leave room for header and safety margin
                
                steps_text = ""
                truncated = False
                
                for i, step in enumerate(combined_steps):
                    step_line = f"• {step}\n"
                    if len(steps_text) + len(step_line) <= max_content_length:
                        steps_text += step_line
                    else:
                        truncated = True
                        break
                
                # Remove trailing newline
                steps_text = steps_text.rstrip('\n')
                
                # Add truncation notice if needed
                if truncated:
                    remaining_count = len(combined_steps) - i
                    steps_text += f"\n\n_... and {remaining_count} more items (truncated for display)_"
                
                blocks.append({
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"{header}{steps_text}"
                    }
                })
            
            # Add SQL information with actual queries and verification status
            try:
                sql_queries = getattr(CORTEX_APP, 'sql_queries', [])
                verified_query_used = getattr(CORTEX_APP, 'verified_query_used', False)
                
                if sql_queries:
                    num_queries = len(sql_queries)
                    blocks.extend([
                        {"type": "divider"},
                        {
                            "type": "section",
                            "text": {
                                "type": "mrkdwn",
                                "text": f"*💾 SQL Queries:*\nCortex Analyst used {num_queries} SQL {'query' if num_queries == 1 else 'queries'}"
                            }
                        }
                    ])
                    
                    # Add each SQL query with its code and verification status
                    for i, sql_query in enumerate(sql_queries, 1):
                        # Determine if this query is verified (assume first/only query is verified if verified_query_used is True)
                        is_verified = verified_query_used and (i == 1 or num_queries == 1)
                        
                        # Create query header with verification status
                        query_header = f"*💾 SQL Query {i}:*"
                        if is_verified:
                            query_header += " :verified: Answer accuracy verified by agent owner"
                        
                        # Truncate SQL if too long for Slack
                        if len(sql_query) > 2800:
                            displayed_sql = sql_query[:2800] + "...\n-- (SQL truncated for display)"
                        else:
                            displayed_sql = sql_query
                        
                        blocks.extend([
                            {
                                "type": "section",
                                "text": {
                                    "type": "mrkdwn",
                                    "text": query_header
                                }
                            },
                            {
                                "type": "section",
                                "text": {
                                    "type": "mrkdwn",
                                    "text": f"```sql\n{displayed_sql}\n```"
                                }
                            }
                        ])
                        
                        # Add separator between queries (except for the last one)
                        if i < len(sql_queries):
                            blocks.append({"type": "divider"})
                    
                    # Add context after all queries
                    blocks.append({
                        "type": "context",
                        "elements": [
                            {
                                "type": "mrkdwn",
                                "text": "ℹ️ All SQL queries were already executed by Cortex during analysis. Results are included in the response above."
                            }
                        ]
                    })
            except:
                pass  # Skip SQL if not available
            
            # Add hide button
            blocks.append({
                "type": "actions",
                "elements": [
                    {
                        "type": "button",
                        "text": {
                            "type": "plain_text",
                            "text": "🔽 Hide Details"
                        },
                        "action_id": "show_planning_details",
                        "value": "hide"
                    }
                ]
            })
        else:  # action_value == "hide"
            # Hide detailed planning steps (show summary)
            if timeline:
                step_count = len(timeline)
            else:
                step_count = (len(steps) if steps else 0) + (len(thinking_steps) if thinking_steps else 0)
            
            # Check what additional info is available
            additional_info = []
            try:
                has_verification = getattr(CORTEX_APP, 'verification_info', {}) or getattr(CORTEX_APP, 'verified_query_used', False)
                sql_queries = getattr(CORTEX_APP, 'sql_queries', [])
                
                if has_verification and sql_queries:
                    # Combine verification and SQL info
                    query_count = len(sql_queries)
                    additional_info.append(f":verified: answer accuracy verified by agent owner for {query_count} SQL {'query' if query_count == 1 else 'queries'}")
                elif has_verification:
                    # Only verification info
                    additional_info.append(":verified: answer accuracy verified by agent owner")
                elif sql_queries:
                    # Only SQL queries
                    query_count = len(sql_queries)
                    additional_info.append(f"{query_count} SQL {'query' if query_count == 1 else 'queries'}")
            except:
                pass
            
            summary_text = f"_Finished {step_count} steps"
            if additional_info:
                summary_text += f" • Includes {' and '.join(additional_info)}"
            summary_text += "_"
            
            blocks = [
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"*🤔 Thinking...* ✅ *Completed!*\n\n{summary_text}"
                    }
                },
                {
                    "type": "actions",
                    "elements": [
                        {
                            "type": "button",
                            "text": {
                                "type": "plain_text",
                                "text": "📋 Show Details"
                            },
                            "action_id": "show_planning_details",
                            "value": "show"
                        }
                    ]
                }
            ]
        
        # Update the message
        app.client.chat_update(
            channel=channel_id,
            ts=message_ts,
            text="🤔 Planning details",
            blocks=blocks
        )
        
    except Exception as e:
        logger.error(f"Error handling planning details toggle: {e}")
        # Fallback message
        say(f"❌ Error toggling planning details: {e}")

@app.event("message")
def handle_message_events(ack, body, say):
    try:
        ack()
        # print(f"🔍 Body: {body}")
        
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
        
        # If no text found, skip
        if not prompt or not prompt.strip():
            return
        
        # Set the slack say function and app for real-time updates
        CORTEX_APP.set_slack_say_function(say)
        CORTEX_APP.set_slack_app(app, event.get('channel'))
        
        say(
            text="🚀 Starting Cortex Agent...",
            blocks=[
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": ":snowflake: *Snowflake Cortex Agent* is processing your request...\n_You'll see real-time updates as the agent works!_",
                    }
                },
                {
                    "type": "divider"
                },
            ]
        )        

        # Get response with real-time streaming
        response = ask_agent(prompt, say)
        
        # Display final response with data execution
        display_agent_response(response, say)
        
    except Exception as e:
        error_info = f"{type(e).__name__} at line {e.__traceback__.tb_lineno} of {__file__}: {e}"
        logger.error(f"Error in message handler: {error_info}")
        say(
            text="❌ Request failed",
            blocks=[
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"❌ *Request Failed*\n```{error_info}```"
                    }
                }
            ]
        )

def smart_truncate(text, max_length=300, suffix="..."):
    """Smart truncation that preserves word and sentence boundaries."""
    if len(text) <= max_length:
        return text
        
    # First try to truncate at sentence boundary
    sentences = text.split('. ')
    if len(sentences) > 1:
        truncated = ""
        for sentence in sentences:
            test_text = truncated + sentence + ". "
            if len(test_text) + len(suffix) <= max_length:
                truncated = test_text
            else:
                break
        if truncated.strip():
            return truncated.strip() + suffix
    
    # If no good sentence boundary, truncate at word boundary
    words = text.split()
    truncated = ""
    for word in words:
        test_text = truncated + word + " "
        if len(test_text) + len(suffix) <= max_length:
            truncated = test_text
        else:
            break
    
    return truncated.strip() + suffix if truncated.strip() else text[:max_length-len(suffix)] + suffix

def ask_agent(prompt, say):
    """Enhanced agent interaction with real-time streaming."""
    resp = CORTEX_APP.chat(prompt)
    return resp

def format_text_for_slack(text):
    """Convert markdown formatting to Slack's mrkdwn format."""
    if not text:
        return text
    
    try:
        # Convert **bold** to *bold* for Slack
        import re
        
        # Replace **text** with *text* (bold)
        text = re.sub(r'\*\*(.*?)\*\*', r'*\1*', text)
        
        # Replace __text__ with *text* (alternative bold syntax)
        text = re.sub(r'__(.*?)__', r'*\1*', text)
        
        # Replace *text* with _text_ (italics) - but only single asterisks
        # This is tricky because we don't want to mess with our bold conversion
        # So we'll handle this carefully by looking for single asterisks not preceded/followed by another asterisk
        text = re.sub(r'(?<!\*)\*(?!\*)([^*]+?)(?<!\*)\*(?!\*)', r'_\1_', text)
        
        return text
        
    except Exception as e:
        logger.error(f"Error formatting text: {e}")
        return text

def format_dataframe_for_slack(df):
    """Format DataFrame for better display in Slack with proper alignment."""
    try:
        # Limit the display for very large datasets
        display_df = df.head(20) if len(df) > 20 else df
        
        # Create a more readable format
        if len(df) > 20:
            table_str = display_df.to_string(index=False, max_colwidth=30)
            table_str += f"\n\n... and {len(df) - 20} more rows"
        else:
            table_str = display_df.to_string(index=False, max_colwidth=30)
        
        return table_str
    
    except Exception as e:
        logger.error(f"Error formatting DataFrame: {e}")
        return "Error formatting data for display"

def display_agent_response(content, say):
    """Enhanced response display with SQL execution and improved formatting."""
    try:
        
        # Display the final agent response text
        if content.get('text'):
            formatted_text = format_text_for_slack(content['text'])
            say(
                text="🎯 Final Response",
                    blocks=[
                        {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*🎯 Snowflake Cortex Agent Response:*\n{formatted_text}"
                        }
                    }
                ]
            )
        
        # Store verification and SQL info for planning section (moved from main display)
        if content.get('verification_info') or content.get('verified_query_used'):
            CORTEX_APP.verification_info = content.get('verification_info', {})
            CORTEX_APP.verified_query_used = content.get('verified_query_used', False)
        
        if content.get('sql_queries'):
            CORTEX_APP.sql_queries = content['sql_queries']
        
        # Display citations if present
        if content.get('citations') and content['citations']:
            formatted_citations = format_text_for_slack(content['citations'])
            say(
                text="📚 Citations",
                blocks=[
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*📚 Citations:*\n_{formatted_citations}_"
                        }
                    }
                ]
            )
        
        # Display suggestions if present
        if content.get('suggestions'):
            # Format each suggestion individually 
            formatted_suggestions = [format_text_for_slack(suggestion) for suggestion in content['suggestions'][:3]]
            suggestions_text = "\n".join(f"• {suggestion}" for suggestion in formatted_suggestions)
            say(
                text="💡 Suggestions",
                blocks=[
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*💡 Follow-up Suggestions:*\n{suggestions_text}"
                        }
                    }
                ]
            )
            
    except Exception as e:
        error_info = f"{type(e).__name__} at line {e.__traceback__.tb_lineno} of {__file__}: {e}"
        logger.error(f"Error in display_agent_response: {error_info}")
        say(
            text="❌ Display error",
            blocks=[{
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"❌ *Error displaying response*\n```{error_info}```"
                }
            }]
        )

def is_running_in_spcs():
    """
    Detect if running in Snowpark Container Services.
    
    When running in SPCS, Snowflake automatically provides an OAuth token
    at /snowflake/session/token that can be used for authentication.
    """
    import os.path
    return os.path.exists('/snowflake/session/token')


def get_oauth_token():
    """Get the OAuth token for the Snowpark Session."""
    with open('/snowflake/session/token', 'r') as f:
        return f.read()

def get_snowflake_connection():
    """Create Snowflake connection using appropriate authentication method."""
    try:
        # Detect environment
        running_in_spcs = is_running_in_spcs()
        
        # Get account from host if not set
        account = ACCOUNT
        if not account:
            if HOST:
                account = HOST.split('.')[0]
                logger.info(f"Extracted account from host: {account}")
        
        if running_in_spcs:
            # Running in SPCS - use OAuth token with Session.builder
            logger.info("Running in SPCS - using OAuth token authentication with Session.builder")
            
            try:
                # Read OAuth token from the file provided by Snowflake
                oauth_token = get_oauth_token()

                logger.info("Creating Snowpark session with SPCS OAuth token")
                # Build connection parameters for SPCS
                # Reference: https://github.com/sfc-gh-jkang/cortex-cost-app-spcs/blob/main/snowflake/snowflake_utils.py
                # For SPCS OAuth: Need account but NOT host (host is derived from account)
                creds = {
                    'host': os.getenv('SNOWFLAKE_HOST'),
                    'port': os.getenv('SNOWFLAKE_PORT'),
                    'protocol': "https",
                    'account': os.getenv('SNOWFLAKE_ACCOUNT'),
                    'authenticator': "oauth",
                    'token': oauth_token,
                    'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE'),
                    'database': os.getenv('SNOWFLAKE_DATABASE'),
                    'schema': os.getenv('SNOWFLAKE_SCHEMA'),
                    'client_session_keep_alive': True
                }

                connection = snowflake.connector.connect(**creds)

                session = Session.builder.configs({"connection": connection}).create()
                logger.info("Successfully connected to Snowflake via SPCS token authentication")
                # Get the underlying connection from the session
                conn = session._conn._conn
                
                # Test connection and get current context
                result = session.sql("SELECT CURRENT_VERSION(), CURRENT_ROLE(), CURRENT_ACCOUNT(), CURRENT_WAREHOUSE()").collect()[0]
                
                logger.info(f"Snowflake version: {result[0]}")
                logger.info(f"Using role: {result[1]}")
                logger.info(f"Account: {result[2]}")
                logger.info(f"Warehouse: {result[3]}")
                return conn
                
            except Exception as oauth_error:
                logger.error(f"OAuth authentication failed: {oauth_error}")
                return None
        else:
            # Running locally - use PAT authentication
            logger.info("Running locally - using PAT authentication")
            
            try:
                conn = snowflake.connector.connect(
                    user=USER,
                    password=PAT,
                    account=account,
                    warehouse=WAREHOUSE,
                    role=ROLE
                )
                
                # Test connection
                cursor = conn.cursor()
                cursor.execute("SELECT CURRENT_VERSION()")
                result = cursor.fetchone()
                cursor.close()
                
                logger.info(f"PAT authentication successful! Snowflake version: {result[0]}")
                return conn
                
            except Exception as pat_error:
                logger.error(f"PAT authentication failed: {pat_error}")
                return None
                
    except Exception as e:
        logger.error(f"Failed to connect to Snowflake: {e}")
        return None

def init():
    """Initialize Snowflake connection and Cortex chat."""
    conn = get_snowflake_connection()

    # Determine authentication token for Cortex API calls
    # NOTE: SPCS OAuth tokens are ONLY for internal Snowflake connections (Snowpark Session)
    #       For Cortex Agent REST API calls, we must use PAT even when running in SPCS
    running_in_spcs = is_running_in_spcs()
    
    # if running_in_spcs:
    #     logger.info("Running in SPCS - Using oauth token for Cortex Agent API calls")
    # else:
    #     logger.info("Running locally - Using PAT for Cortex API calls")
    
    # if running_in_spcs:
    #     auth_token = get_oauth_token()
    #     use_oauth = True
    # else:
    #     auth_token = PAT
    #     use_oauth = False
    # Only use PAT for Cortex API calls
    auth_token = PAT
    use_oauth = False

    cortex_app = cortex_chat.CortexChat(
        AGENT_ENDPOINT, 
        auth_token,
        use_oauth=use_oauth
    )

    logger.info("Initialization complete")
    return conn, cortex_app

# Start app
if __name__ == "__main__":
    CONN, CORTEX_APP = init()
    if CONN:
        Root = Root(CONN)
        SocketModeHandler(app, SLACK_APP_TOKEN).start()
        