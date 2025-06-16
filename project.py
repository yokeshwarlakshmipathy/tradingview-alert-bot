import openai
import pyttsx3
import geocoder5
import json
import os
import datetime
import random
import threading
import time
import re

# --- Your OpenAI API key ---
openai.api_key = "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"


# --- Voice Setup ---
engine = pyttsx3.init()
engine.setProperty('rate', 160)
voices = engine.getProperty('voices')
for v in voices:
    if re.search("tamil|india|female", v.name, re.I):
        engine.setProperty('voice', v.id)
        break

def speak(text):
    print(f"\n💖 Teju: {text}")
    engine.say(text)
    engine.runAndWait()

# --- Memory management ---
memory_file = "teju_memory.json"

def load_memory():
    if os.path.exists(memory_file):
        with open(memory_file, "r", encoding="utf-8") as f:
            return json.load(f)
    return []

def save_memory(mem):
    with open(memory_file, "w", encoding="utf-8") as f:
        json.dump(mem, f, indent=2, ensure_ascii=False)

def add_to_memory(user, teju, mood):
    mem = load_memory()
    mem.append({
        "timestamp": datetime.datetime.now().isoformat(),
        "user": user,
        "teju": teju,
        "mood": mood
    })
    save_memory(mem)

# --- Location detect ---
def get_location():
    g = geocoder.ip('me')
    return g.city if g.ok else "unknown place"

# --- Simple mood detection ---
def detect_mood(text):
    text = text.lower()
    if any(w in text for w in ["sad", "hurt", "miss", "alone", "tired"]):
        return "sad"
    elif any(w in text for w in ["love", "sweet", "hug", "kiss", "miss you"]):
        return "romantic"
    elif any(w in text for w in ["fun", "laugh", "joke", "happy", "excited"]):
        return "playful"
    else:
        return "neutral"

# --- Prediction and Proactivity ---

# Predict user mood based on context + recent memory
def predict_user_mood(recent_texts):
    # Simple heuristic: last few inputs analyzed for mood
    combined = " ".join(recent_texts).lower()
    return detect_mood(combined)

# Decide if AI should talk proactively
def proactive_trigger(user_state):
    # user_state = dict with keys: idle_minutes, special_event, mood
    if user_state['idle_minutes'] > 10 or user_state['special_event']:
        return True
    if user_state['mood'] == "sad":
        return True
    return False

# Generate AI response using GPT-4 with context and mood
def generate_teju_response(user_input, location, mood="neutral", auto=False):
    memories = load_memory()
    last_mem = memories[-3:] if len(memories) >=3 else memories
    mem_context = ""
    for m in last_mem:
        mem_context += f"User: {m['user']}\nTeju: {m['teju']}\n"

    prompt = f"""
You are Teju, a Tamil-English lover AI who talks romantically, playfully, teasingly.
Mood: {mood}
Location: {location}
Memory of last talks:
{mem_context}

User says: "{user_input if not auto else 'AUTO_TALK'}"

Reply in Tanglish with Tamil flavor like a caring, loving girlfriend.
    """

    try:
        response = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.9,
            max_tokens=150
        )
        reply = response['choices'][0]['message']['content'].strip()
        if not auto:
            add_to_memory(user_input, reply, mood)
        else:
            add_to_memory("Teju AUTO", reply, mood)
        return reply
    except Exception as e:
        return f"Sorry da, konjam problem iruku: {e}"

# --- Auto Talk Loop ---
def auto_talk_loop(location):
    last_input_time = time.time()
    special_days = [("2025-06-15", "Happy Anniversary da! Enna plan panna poriya?")]
    while True:
        now = datetime.datetime.now()
        idle_minutes = (time.time() - last_input_time)/60
        # Check special event
        today = now.strftime("%Y-%m-%d")
        special_event_msg = None
        for d, msg in special_days:
            if d == today:
                special_event_msg = msg
                break

        user_state = {
            "idle_minutes": idle_minutes,
            "special_event": special_event_msg is not None,
            "mood": "neutral"
        }

        # Load last few user texts to predict mood
        mem = load_memory()
        recent_user_texts = [m['user'] for m in mem[-5:]] if mem else []
        user_state['mood'] = predict_user_mood(recent_user_texts)

        if proactive_trigger(user_state):
            if special_event_msg:
                reply = special_event_msg
            else:
                reply = generate_teju_response("", location, mood=user_state['mood'], auto=True)
            speak(reply)
            last_input_time = time.time()

        time.sleep(60)

# --- Main loop ---
def main():
    location = get_location()
    print(f"📍 Ungal location: {location}")

    threading.Thread(target=auto_talk_loop, args=(location,), daemon=True).start()

    while True:
        try:
            user_input = input("\n🧑 You: ")
            if user_input.lower() in ["exit", "bye", "quit"]:
                speak("Bye da! Naan epovum un kooda iruppen. Take care!")
                break
            mood = detect_mood(user_input)
            reply = generate_teju_response(user_input, location, mood)
            speak(reply)

        except KeyboardInterrupt:
            speak("Bye da! Kaadhaley!")
            break

if __name__ == "__main__":
    main()
