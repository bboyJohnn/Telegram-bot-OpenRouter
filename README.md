# 🚀 Telegram bot OpenRouter

A **Telegram chatbot** powered by **OpenRouter AI** that allows you to chat with multiple AI models directly in Telegram. Switch between free models like **Mistral**, **Gemma**, **DeepSeek**, and **Qwen** – or easily **add your own custom models** in the code!

---

## ✨ Features

- **Inline Menu & Reply Keyboard** – choose AI models easily while typing.
- **Persistent Conversation Memory** – each user's chat is saved in JSON files.
- **Typing Indicator** – feels like chatting with a real human.
- **Customizable Models** – edit `FREE_MODELS` in the code to add or change AI models.
- **Interactive Setup Script** – one command installs everything on Ubuntu.
- **Systemd Integration** – bot starts automatically with the system.

---

## ⚡ Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/telegram-bot-openrouter.git
cd telegram-openrouter-bot
```

2. Run the interactive setup script on Ubuntu:
```bash
./setup_bot.sh
```

3. Enter your `TELEGRAM_BOT_TOKEN` and `OPENROUTER_API_KEY`. The bot will be deployed and start automatically.

---

## 🛠 How to Add or Change Models

Open `bot.py` and locate the `FREE_MODELS` dictionary:

```python
FREE_MODELS = {
    "Mistral 7B": "mistralai/mistral-7b-instruct:free",
    "Gemma 3 12B": "google/gemma-3-12b-it:free",
    "DeepSeek R1": "deepseek/deepseek-r1:free",
    "Qwen 2.5 32B": "qwen/qwen2.5-vl-32b-instruct:free",
}
```

- **Add a new model:**
```python
"YourModelName": "your/model-id:tag"
```
- **Remove or rename existing models** as you like.

The bot will automatically show any new or modified models in both the **inline menu** and **reply keyboard**.

---

## 📝 Commands

- `/start` – start the bot and show menus
- `/help` – show available commands
- `/clear` – clear conversation history
- `/menu` – show inline menu again
- `/mistral`, `/gemma`, `/deepseek`, `/qwen` – directly select a model

---

## 💡 Notes

- Each user has a separate JSON history, so the bot **remembers previous messages**.
- You can extend the bot by adding new features or connecting more models.

---

## 🎨 Customization

You can **fully customize the bot** by editing `bot.py`:

- Change models in `FREE_MODELS` dictionary.
- Modify the reply keyboard or inline menu layout.
- Extend commands or add new AI interaction features.

Make it your own AI Telegram hub!
