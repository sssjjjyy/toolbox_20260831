import openai
import sys
import json
import os

openai.api_key = 'sk-VyM1T9gExamKIbWQ1bC3Cf4aA28040E181F9Ad94C86aC5D7'
openai.base_url = "https://free.v36.cm/v1/"

class ChatHistory:
    def __init__(self):
        self.messages = []
    
    def add_message(self, role, content):
        self.messages.append({"role": role, "content": content})
    
    def clear(self):
        self.messages = []
    
    def get_messages(self):
        return self.messages

# 创建全局历史记录对象
chat_history = ChatHistory()

def ask_chatgpt(prompt):
    """Send a query to ChatGPT and get a response using the new API."""
    try:
        # 获取 API 密钥
        openai.api_key = 'sk-VyM1T9gExamKIbWQ1bC3Cf4aA28040E181F9Ad94C86aC5D7'
        openai.base_url = "https://free.v36.cm/v1/"

        # 添加用户消息到历史记录
        chat_history.add_message("user", prompt)
        
        # 添加系统消息（可选）
        if not chat_history.messages:
            chat_history.add_message("system", 
                "You are a helpful assistant. Please provide direct answers without including previous examples unless specifically asked.")
        

        # 调用 ChatGPT 接口
        response = openai.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "user", "content": prompt}
            ],
            temperature=0.7
        )

        # 保存助手的回复到历史记录
        assistant_response = response.choices[0].message.content
        chat_history.add_message("assistant", assistant_response)
        
        # 返回响应内容
        return assistant_response
    
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        return f"Error: {str(e)}"
    
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python chatgpt_api.py \"your question here\"", file=sys.stderr)
        sys.exit(1)

    prompt = sys.argv[1]    
    response = ask_chatgpt(prompt)
    print(response) 