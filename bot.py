import aiohttp
import asyncio
import os
import json
from aiogram import Bot, Dispatcher, types, F
from aiogram.types import InlineKeyboardButton, ReplyKeyboardMarkup, KeyboardButton
from aiogram.utils.keyboard import InlineKeyboardBuilder

# -----------------------------
# Загрузка токенов из config.json
# -----------------------------
with open("config.json", "r", encoding="utf-8") as f:
    config = json.load(f)

TELEGRAM_TOKEN = config["TELEGRAM_TOKEN"]
OPENROUTER_API_KEY = config["OPENROUTER_API_KEY"]

# -----------------------------
# Бесплатные модели
# -----------------------------
FREE_MODELS = {
    "Mistral 7B": "mistralai/mistral-7b-instruct:free",
    "Gemma 3 12B": "google/gemma-3-12b-it:free",
    "DeepSeek R1": "deepseek/deepseek-r1:free",
    "Qwen 2.5 32B": "qwen/qwen2.5-vl-32b-instruct:free",
}

# -----------------------------
# Хранилище текущих моделей и последних inline-сообщений
# -----------------------------
user_model = {}
last_inline_msg = {}

# -----------------------------
# Папка для истории
# -----------------------------
HISTORY_DIR = "user_histories"
os.makedirs(HISTORY_DIR, exist_ok=True)

bot = Bot(token=TELEGRAM_TOKEN)
dp = Dispatcher()

# -----------------------------
# Функции работы с историей
# -----------------------------
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

# -----------------------------
# Inline-меню с подсветкой выбранной модели
# -----------------------------
def get_inline_menu(selected_model=None):
    builder = InlineKeyboardBuilder()
    for name, model_id in FREE_MODELS.items():
        label = f"✅ {name}" if model_id == selected_model else name
        builder.button(text=label, callback_data=f"model:{model_id}")
    builder.adjust(2)
    return builder.as_markup()

# -----------------------------
# Reply-клавиатура под полем ввода
# -----------------------------
def get_reply_keyboard():
    kb = [
        [KeyboardButton("Mistral 7B"), KeyboardButton("Gemma 3 12B")],
        [KeyboardButton("DeepSeek R1"), KeyboardButton("Qwen 2.5 32B")],
        [KeyboardButton("/clear")]
    ]
    return ReplyKeyboardMarkup(keyboard=kb, resize_keyboard=True)

# -----------------------------
# /start
# -----------------------------
@dp.message(F.text == "/start")
async def start(message: types.Message):
    user_id = message.from_user.id
    current_model = user_model.get(user_id)

    inline_msg = await message.answer(
        "👋 Выбери модель для общения (inline-меню):",
        reply_markup=get_inline_menu(current_model)
    )
    last_inline_msg[user_id] = inline_msg.message_id

    await message.answer(
        "👇 Или выбери модель через клавиатуру под полем ввода:",
        reply_markup=get_reply_keyboard()
    )

# -----------------------------
# Inline выбор модели
# -----------------------------
@dp.callback_query(F.data.startswith("model:"))
async def inline_model_select(callback: types.CallbackQuery):
    model_id = callback.data.split("model:")[1]
    user_id = callback.from_user.id
    user_model[user_id] = model_id
    save_history(user_id, [])  # очистка истории при смене модели

    await callback.answer("Модель выбрана ✅")

    msg_id = last_inline_msg.get(user_id)
    if msg_id:
        await bot.edit_message_reply_markup(
            chat_id=callback.message.chat.id,
            message_id=msg_id,
            reply_markup=get_inline_menu(selected_model=model_id)
        )

# -----------------------------
# Reply-клавиатура выбор модели
# -----------------------------
@dp.message(F.text.in_(FREE_MODELS.keys()))
async def reply_model_select(message: types.Message):
    name = message.text
    model_id = FREE_MODELS[name]
    user_id = message.from_user.id
    user_model[user_id] = model_id
    save_history(user_id, [])

    msg_id = last_inline_msg.get(user_id)
    if msg_id:
        await bot.edit_message_reply_markup(
            chat_id=message.chat.id,
            message_id=msg_id,
            reply_markup=get_inline_menu(selected_model=model_id)
        )

    await message.answer(f"✅ Выбрана модель: {name}")

# -----------------------------
# Очистка контекста
# -----------------------------
@dp.message(F.text == "/clear")
async def clear_context(message: types.Message):
    user_id = message.from_user.id
    save_history(user_id, [])
    await message.answer("🧹 Контекст диалога очищен!")

# -----------------------------
# /help - показать все команды
# -----------------------------
@dp.message(F.text == "/help")
async def show_help(message: types.Message):
    help_text = """
📌 Команды бота:

/start - стартовое сообщение с inline-меню и клавиатурой
/help - показать это сообщение
/clear - очистить историю переписки
/menu - показать inline-меню моделей заново

Также можно выбрать модель напрямую:
/mistral - выбрать Mistral 7B
/gemma - выбрать Gemma 3 12B
/deepseek - выбрать DeepSeek R1
/qwen - выбрать Qwen 2.5 32B

Или использовать кнопки reply-клавиатуры под полем ввода.
"""
    await message.answer(help_text)

# -----------------------------
# /menu - показать inline-меню заново
# -----------------------------
@dp.message(F.text == "/menu")
async def show_menu(message: types.Message):
    user_id = message.from_user.id
    current_model = user_model.get(user_id)
    inline_msg = await message.answer(
        "Выбери модель для общения (inline-меню):",
        reply_markup=get_inline_menu(current_model)
    )
    last_inline_msg[user_id] = inline_msg.message_id

# -----------------------------
# Команды для выбора модели напрямую
# -----------------------------
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

# -----------------------------
# Вспомогательная функция для команд выбора модели
# -----------------------------
async def select_model_command(message: types.Message, name: str):
    model_id = FREE_MODELS[name]
    user_id = message.from_user.id
    user_model[user_id] = model_id
    save_history(user_id, [])
    await message.answer(f"✅ Выбрана модель: {name}")

    # Обновляем inline-меню
    msg_id = last_inline_msg.get(user_id)
    if msg_id:
        await bot.edit_message_reply_markup(
            chat_id=message.chat.id,
            message_id=msg_id,
            reply_markup=get_inline_menu(selected_model=model_id)
        )

# -----------------------------
# Общение с моделью
# -----------------------------
@dp.message()
async def chat_with_model(message: types.Message):
    user_id = message.from_user.id
    model = user_model.get(user_id)
    if not model:
        await message.answer("⚠️ Сначала выбери модель через /start")
        return

    # Показываем статус "печатает..." пока формируется ответ
    await bot.send_chat_action(message.chat.id, "typing")

    # Загружаем историю пользователя
    history = load_history(user_id)
    history.append({"role": "user", "content": message.text})

    # Запрос к OpenRouter
    async with aiohttp.ClientSession() as session:
        async with session.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
            },
            json={"model": model, "messages": history},
        ) as response:
            result = await response.json()

    try:
        reply = result["choices"][0]["message"]["content"]
    except:
        reply = "❌ Ошибка при получении ответа."

    # Сразу отправляем ответ
    await message.answer(reply)

    # Сохраняем историю
    history.append({"role": "assistant", "content": reply})
    save_history(user_id, history)

# -----------------------------
# Запуск
# -----------------------------
async def main():
    print("🚀 Бот запущен и готов к работе!")
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
