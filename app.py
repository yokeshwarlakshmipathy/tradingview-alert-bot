from flask import Flask, request
import requests

app = Flask(__name__)

# Paste your bot token and chat ID here
BOT_TOKEN = '7620715723:AAHPKKefuh8pw205sAEkS8mVbSo2oWEjAsA'
CHAT_ID = '836055412'

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    symbol = data.get('symbol')
    price = data.get('price')
    signal = data.get('type')

    if symbol and price and signal:
        message = f"📢 {signal} Alert\n📊 {symbol}\n💰 Price: {price}"
        send_telegram(message)
        return {"status": "success"}, 200
    else:
        return {"error": "Missing data"}, 400

def send_telegram(text):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {"chat_id": CHAT_ID, "text": text}
    requests.post(url, data=payload)

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)

