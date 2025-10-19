#!/bin/bash

echo "🚀 Telegram/OpenRouter Bot Setup Script"

# -----------------------------
# Check for sudo
# -----------------------------
if ! command -v sudo &> /dev/null
then
    echo "⚠️ sudo not found. Please install sudo first."
    exit 1
fi

# -----------------------------
# Check for systemd
# -----------------------------
if ! command -v systemctl &> /dev/null
then
    echo "⚠️ systemd not found. This script requires systemd to create a service."
    exit 1
fi

# -----------------------------
# Check for Python3
# -----------------------------
if ! command -v python3 &> /dev/null
then
    echo "⚠️ Python3 not found. Installing..."
    sudo apt update
    sudo apt install -y python3 python3-venv python3-pip
else
    echo "✅ Python3 found."
fi

# -----------------------------
# Ask for tokens
# -----------------------------
read -p "Enter your TELEGRAM_BOT_TOKEN: " TELEGRAM_TOKEN
read -p "Enter your OPENROUTER_API_KEY: " OPENROUTER_API_KEY

# -----------------------------
# Create project directory
# -----------------------------
PROJECT_DIR="$HOME/telegram_bot"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit
mkdir -p user_histories

# -----------------------------
# Create config.json
# -----------------------------
cat > config.json <<EOL
{
  "TELEGRAM_TOKEN": "$TELEGRAM_TOKEN",
  "OPENROUTER_API_KEY": "$OPENROUTER_API_KEY"
}
EOL
echo "✅ Created config.json with your tokens."

# -----------------------------
# Create bot.py
# -----------------------------
cat > bot.py <<'EOL'
import aiohttp
import asyncio
import os
import json
from aiogram import Bot, Dispatcher, types, F
from aiogram.types import InlineKeyboardButton, ReplyKeyboardMarkup, KeyboardButton
from aiogram.utils.keyboard import InlineKeyboardBuilder

with open("config.json", "r", encoding="utf-8") as f:
    config = json.load(f)

TELEGRAM_TOKEN = config["TELEGRAM_TOKEN"]
OPENROUTER_API_KEY = config["OPENROUTER_API_KEY"]

FREE_MODELS = {
    "Mistral 7B": "mistralai/mistral-7b-instruct:free",
    "Gemma 3 12B": "google/gemma-3-12b-it:free",
    "DeepSeek R1": "deepseek/deepseek-r1:free",
    "Qwen 2.5 32B": "qwen/qwen2.5-vl-32b-instruct:free",
}

user_model = {}
last_inline_msg = {}

HISTORY_DIR = "user_histories"
os.makedirs(HISTORY_DIR, exist_ok=True)

bot = Bot(token=TELEGRAM_TOKEN)
dp = Dispatcher()

def get_user_file(user_id):
    return os.path.join(HISTORY_DIR, f"{user_id}.json")

def load_history(user_id):
    file = get_user_file(user_id)
    if os.path.exists(file):
        with open(file, "r", encoding="utf-8") as f:
            return json.load(f)
    return []

def save_history(user_id, history):
    file = get_user_file(user_id)
    with open(file, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=2)

def get_inline_menu(selected_model=None):
    builder = InlineKeyboardBuilder()
    for name, model_id in FREE_MODELS.items():
        label = f"✅ {name}" if model_id == selected_model else name
        builder.button(text=label, callback_data=f"model:{model_id}")
    builder.adjust(2)
    return builder.as_markup()

def get_reply_keyboard():
    kb = [
        [KeyboardButton("Mistral 7B"), KeyboardButton("Gemma 3 12B")],
        [KeyboardButton("DeepSeek R1"), KeyboardButton("Qwen 2.5 32B")],
        [KeyboardButton("/clear")]
    ]
    return ReplyKeyboardMarkup(keyboard=kb, resize_keyboard=True)

@dp.message(F.text == "/start")
async def start(message: types.Message):
    user_id = message.from_user.id
    current_model = user_model.get(user_id)
    inline_msg = await message.answer("👋 Choose a model (inline menu):", reply_markup=get_inline_menu(current_model))
    last_inline_msg[user_id] = inline_msg.message_id
    await message.answer("👇 Or choose a model from the keyboard below:", reply_markup=get_reply_keyboard())

@dp.callback_query(F.data.startswith("model:"))
async def inline_model_select(callback: types.CallbackQuery):
    model_id = callback.data.split("model:")[1]
    user_id = callback.from_user.id
    user_model[user_id] = model_id
    save_history(user_id, [])
    await callback.answer("Model selected ✅")
    msg_id = last_inline_msg.get(user_id)
    if msg_id:
        await bot.edit_message_reply_markup(chat_id=callback.message.chat.id, message_id=msg_id, reply_markup=get_inline_menu(selected_model=model_id))

@dp.message(F.text.in_(FREE_MODELS.keys()))
async def reply_model_select(message: types.Message):
    name = message.text
    model_id = FREE_MODELS[name]
    user_id = message.from_user.id
    user_model[user_id] = model_id
    save_history(user_id, [])
    msg_id = last_inline_msg.get(user_id)
    if msg_id:
        await bot.edit_message_reply_markup(chat_id=message.chat.id, message_id=msg_id, reply_markup=get_inline_menu(selected_model=model_id))
    await message.answer(f"✅ Selected model: {name}")

@dp.message(F.text == "/clear")
async def clear_context(message: types.Message):
    user_id = message.from_user.id
    save_history(user_id, [])
    await message.answer("🧹 Chat history cleared!")

@dp.message(F.text == "/help")
async def show_help(message: types.Message):
    help_text = """
📌 Bot commands:

/start - start bot with inline menu and keyboard
/help - show this help message
/clear - clear chat history
/menu - show inline menu again

Direct model selection:
/mistral - select Mistral 7B
/gemma - select Gemma 3 12B
/deepseek - select DeepSeek R1
/qwen - select Qwen 2.5 32B

Or use the reply keyboard below the input field.
"""
    await message.answer(help_text)

@dp.message(F.text == "/menu")
async def show_menu(message: types.Message):
    user_id = message.from_user.id
    current_model = user_model.get(user_id)
    inline_msg = await message.answer("Choose a model (inline menu):", reply_markup=get_inline_menu(current_model))
    last_inline_msg[user_id] = inline_msg.message_id

@dp.message(F.text == "/mistral")
async def select_mistral(message: types.Message):
    await select_model_command(message, "Mistral 7B")
@dp.message(F.text == "/gemma")
async def select_gemma(message: types.Message):
    await select_model_command(message, "Gemma 3 12B")
@dp.message(F.text == "/deepseek")
async def select_deepseek(message: types.Message):
    await select_model_command(message, "DeepSeek R1")
@dp.message(F.text == "/qwen")
async def select_qwen(message: types.Message):
    await select_model_command(message, "Qwen 2.5 32B")

async def select_model_command(message: types.Message, name: str):
    model_id = FREE_MODELS[name]
    user_id = message.from_user.id
    user_model[user_id] = model_id
    save_history(user_id, [])
    await message.answer(f"✅ Selected model: {name}")
    msg_id = last_inline_msg.get(user_id)
    if msg_id:
        await bot.edit_message_reply_markup(chat_id=message.chat.id, message_id=msg_id, reply_markup=get_inline_menu(selected_model=model_id))

@dp.message()
async def chat_with_model(message: types.Message):
    user_id = message.from_user.id
    model = user_model.get(user_id)
    if not model:
        await message.answer("⚠️ Choose a model first with /start")
        return
    await bot.send_chat_action(message.chat.id, "typing")
    history = load_history(user_id)
    history.append({"role": "user", "content": message.text})
    async with aiohttp.ClientSession() as session:
        async with session.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={"Authorization": f"Bearer {OPENROUTER_API_KEY}", "Content-Type": "application/json"},
            json={"model": model, "messages": history},
        ) as response:
            result = await response.json()
    try:
        reply = result["choices"][0]["message"]["content"]
    except:
        reply = "❌ Error getting response."
    await message.answer(reply)
    history.append({"role": "assistant", "content": reply})
    save_history(user_id, history)

async def main():
    print("🚀 Bot is running...")
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
EOL

echo "✅ Created bot.py"

# -----------------------------
# Create virtual environment and install dependencies
# -----------------------------
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install aiogram aiohttp
deactivate
echo "✅ Virtual environment created and dependencies installed."

# -----------------------------
# Setup systemd service
# -----------------------------
SERVICE_FILE="/etc/systemd/system/telegram_bot.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Telegram/OpenRouter Bot
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable telegram_bot.service
sudo systemctl start telegram_bot.service

echo "✅ Bot service created and started with systemd."
echo "🎉 Setup complete! Your bot should now be running."
