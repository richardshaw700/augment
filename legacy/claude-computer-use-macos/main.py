import asyncio
import os
import sys
import json
import base64
import time
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

from computer_use_demo.loop import sampling_loop, APIProvider
from computer_use_demo.tools import ToolResult
from anthropic.types.beta import BetaMessage, BetaMessageParam
from anthropic import APIResponse


async def main():
    # Cost optimization settings
    COST_OPTIMIZATION_MODE = os.getenv("COST_OPTIMIZATION", "medium").lower()
    
    cost_settings = {
        "low": {
            "max_tokens": 4096,
            "recent_images": 10,
            "description": "Maximum quality, highest cost"
        },
        "medium": {
            "max_tokens": 2048,
            "recent_images": 3,
            "description": "Balanced quality and cost"
        },
        "high": {
            "max_tokens": 1024,
            "recent_images": 2,
            "description": "Minimal cost, basic functionality"
        }
    }
    
    current_settings = cost_settings.get(COST_OPTIMIZATION_MODE, cost_settings["medium"])
    timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    print(f"[{timestamp}] Cost optimization: {COST_OPTIMIZATION_MODE} ({current_settings['description']})")

    # Set up your Anthropic API key and model
    api_key = os.getenv("ANTHROPIC_API_KEY", "YOUR_API_KEY_HERE")
    if api_key == "YOUR_API_KEY_HERE":
        raise ValueError(
            "Please first set your API key in the ANTHROPIC_API_KEY environment variable"
        )
    provider = APIProvider.ANTHROPIC

    # Check if the instruction is provided via command line arguments
    if len(sys.argv) > 1:
        instruction = " ".join(sys.argv[1:])
    else:
        instruction = "Save an image of a cat to the desktop."

    timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    print(
        f"[{timestamp}] Starting Claude 'Computer Use'.\nPress ctrl+c to stop.\nInstructions provided: '{instruction}'"
    )

    # Set up the initial messages
    messages: list[BetaMessageParam] = [
        {
            "role": "user",
            "content": instruction,
        }
    ]

    # Define callbacks (you can customize these)
    def output_callback(content_block):
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        if isinstance(content_block, dict) and content_block.get("type") == "text":
            print(f"[{timestamp}] Assistant:", content_block.get("text"))
            sys.stdout.flush()  # Force immediate output
        elif isinstance(content_block, dict) and content_block.get("type") == "tool_use":
            tool_name = content_block.get("name", "unknown")
            tool_input = content_block.get("input", {})
            print(f"[{timestamp}] ### Performing action: {tool_name} with {tool_input}")
            sys.stdout.flush()  # Force immediate output

    def tool_output_callback(result: ToolResult, tool_use_id: str):
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        if result.output:
            print(f"[{timestamp}] > Tool Output [{tool_use_id}]:", result.output)
            sys.stdout.flush()  # Force immediate output
        if result.error:
            print(f"[{timestamp}] !!! Tool Error [{tool_use_id}]:", result.error)
            sys.stdout.flush()  # Force immediate output
        if result.base64_image:
            # Save the image to a file if needed
            os.makedirs("screenshots", exist_ok=True)
            image_data = result.base64_image
            with open(f"screenshots/screenshot_{tool_use_id}.png", "wb") as f:
                f.write(base64.b64decode(image_data))
            print(f"[{timestamp}] Took screenshot screenshot_{tool_use_id}.png")
            sys.stdout.flush()  # Force immediate output

    def api_response_callback(response: APIResponse[BetaMessage]):
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(
            f"\n[{timestamp}] ---------------\n[{timestamp}] API Response:\n",
            json.dumps(json.loads(response.text)["content"], indent=4),  # type: ignore
            "\n",
        )
        sys.stdout.flush()  # Force immediate output

    # Run the sampling loop
    messages = await sampling_loop(
        model="claude-3-5-sonnet-20241022",
        provider=provider,
        system_prompt_suffix="",
        messages=messages,
        output_callback=output_callback,
        tool_output_callback=tool_output_callback,
        api_response_callback=api_response_callback,
        api_key=api_key,
        only_n_most_recent_images=current_settings["recent_images"],
        max_tokens=current_settings["max_tokens"],
    )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as e:
        print(f"Encountered Error:\n{e}")
