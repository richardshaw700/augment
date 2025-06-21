#!/usr/bin/env python3
"""
Quick test script for Ollama connection
"""
import requests
import json

def test_ollama():
    try:
        # Test basic connection
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        print(f"Connection test: {response.status_code}")
        if response.status_code == 200:
            models = response.json()
            print(f"Available models: {models}")
        
        # Test generation
        print("\nTesting generation...")
        gen_response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "phi3:mini",
                "prompt": "Hello! Please respond with a simple JSON: {\"action\": \"test\", \"message\": \"working\"}",
                "stream": False
            },
            timeout=30
        )
        
        print(f"Generation status: {gen_response.status_code}")
        if gen_response.status_code == 200:
            result = gen_response.json()
            print(f"Response: {result.get('response', 'No response')}")
        else:
            print(f"Error: {gen_response.text}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_ollama() 