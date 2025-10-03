-- Web Scrape Function Setup for Cortex Agents
-- This enables the agent to scrape and analyze web content in real-time
-- Based on: https://github.com/NickAkincilar/Snowflake_AI_DEMO/blob/main/sql_scripts/demo_setup.sql

USE ROLE ACCOUNTADMIN;

-- Create network rule to allow external web access
CREATE OR REPLACE NETWORK RULE allow_all_rule
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('0.0.0.0:443', '0.0.0.0:80');

-- Create external access integration for web scraping
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION allow_all_integration
  ALLOWED_NETWORK_RULES = (allow_all_rule)
  ENABLED = TRUE;

-- Grant usage to snowflake_intelligence_admin role
GRANT USAGE ON INTEGRATION allow_all_integration TO ROLE snowflake_intelligence_admin;

USE ROLE snowflake_intelligence_admin;
USE DATABASE dash_agent_slack;
USE SCHEMA data;

-- Create the web_scrape function
CREATE OR REPLACE FUNCTION web_scrape(url VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = 3.9
HANDLER = 'scrape_url'
EXTERNAL_ACCESS_INTEGRATIONS = (allow_all_integration)
PACKAGES = ('requests', 'beautifulsoup4', 'lxml')
AS
$$
import requests
from bs4 import BeautifulSoup

def scrape_url(url):
    """
    Scrapes a web page and returns its text content.
    
    Args:
        url (str): The URL to scrape
        
    Returns:
        str: Cleaned text content from the webpage
    """
    try:
        # Set headers to mimic a browser request
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        # Make the request with timeout
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        # Parse the HTML content
        soup = BeautifulSoup(response.content, 'lxml')
        
        # Remove script and style elements
        for script in soup(['script', 'style', 'header', 'footer', 'nav']):
            script.decompose()
        
        # Get text content
        text = soup.get_text(separator=' ', strip=True)
        
        # Clean up whitespace
        lines = (line.strip() for line in text.splitlines())
        chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
        text = ' '.join(chunk for chunk in chunks if chunk)
        
        # Limit response size to prevent issues
        max_length = 10000
        if len(text) > max_length:
            text = text[:max_length] + "... (truncated)"
        
        return text
        
    except requests.exceptions.Timeout:
        return f"Error: Request timed out while accessing {url}"
    except requests.exceptions.RequestException as e:
        return f"Error: Failed to scrape {url}. Details: {str(e)}"
    except Exception as e:
        return f"Error: An unexpected error occurred. Details: {str(e)}"
$$;

-- Test the function (optional)
-- SELECT web_scrape('https://www.example.com');

-- Grant execute permission to the agent
GRANT USAGE ON FUNCTION web_scrape(VARCHAR) TO ROLE snowflake_intelligence_admin;

SELECT 'Web scrape function created successfully! You can now add this as a tool to your Cortex Agent.' AS status;

