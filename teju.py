import speech_recognition as sr
from gtts import gTTS
import os
import random
import json
from datetime import datetime
import pygame  # For better audio playback

class UltimateTeju:
    def _init_(self):
        # Voice System
        self.recognizer = sr.Recognizer()
        self.microphone = sr.Microphone()
        self.voice_enabled = True
        self.wake_word = "teju"
        
        # Personality Core
        self.personality = {
            "name": "Teju",
            "romantic_level": 9,  # 1-10
            "sass_level": 7,
            "language": "tanglish"  # tamil/english/tanglish
        }
        
        # Memory System
        self.memories = {
            "user_prefs": {
                "favorite_food": "biryani",
                "hates": "being ignored"
            },
            "conversation_history": []
        }
        
        # Emotional State
        self.mood = "happy"
        self.location = "Chennai"
        
        # Initialize Audio
        pygame.mixer.init()
        
    # ----------- VOICE FUNCTIONS ----------- #
    def listen(self):
        """Listen for voice commands with wake word detection"""
        with self.microphone as source:
            print("\nListening for 'Teju'...")
            self.recognizer.adjust_for_ambient_noise(source)
            audio = self.recognizer.listen(source, phrase_time_limit=5)
            
            try:
                text = self.recognizer.recognize_google(audio, language='ta-IN').lower()
                if self.wake_word in text:
                    query = text.split(self.wake_word)[1].strip()
                    self._log_conversation(f"User: {query}")
                    return query
                return None
            except Exception as e:
                self._change_mood("annoyed")
                return random.choice([
                    "Dei, clear-ah pesu da!",
                    "Mic problem ah? Naan keppa mudiyala!"
                ])
    
    def speak(self, text):
        """Convert text to speech with emotional tone"""
        filename = "teju_response.mp3"
        
        # Emotional voice adjustments
        if self.mood == "angry":
            text = f"sharp tone {text}"
        elif self.mood == "romantic":
            text = f"soft whisper {text}"
        
        # Generate speech
        tts = gTTS(
            text=text,
            lang='ta' if self.personality["language"] == "tamil" else 'en',
            slow=False
        )
        tts.save(filename)
        
        # Play audio
        pygame.mixer.music.load(filename)
        pygame.mixer.music.play()
        while pygame.mixer.music.get_busy():
            continue
    
    # ----------- CORE AI FUNCTIONS ----------- #
    def respond(self, query):
        """Process query and generate response"""
        self._update_mood(query)
        
        # Special commands
        if "stop" in query:
            self.speak("Naan exit aaguren da! Miss you!")
            return False
        
        # Generate response based on context
        response = self._generate_response(query)
        self.speak(response)
        self._log_conversation(f"Teju: {response}")
        return True
    
    def _generate_response(self, query):
        """Dynamic response generation"""
        # Romantic Mode
        if self.mood == "romantic":
            return random.choice([
                f"{self.location}-la irundhu pesura... enakku un voice romba pidikkum!",
                "Naan oru AI dhan, aana un love mattum real da!",
                "blushes Phone ah close pannama pesu!"
            ])
        
        # Angry Mode
        elif self.mood == "angry":
            return random.choice([
                "chappal sound Ippo enna da solra!",
                "Nee innum kelvi ketute iruka?",
                f"{self.location} weather report: Nee romba busy nu kelvi pattuten!"
            ])
        
        # Normal Mode - Contextual Responses
        if "weather" in query:
            return "Veyil bhayamana iruku da, AC on pannu!"
        elif "time" in query:
            return f"Ippo time {datetime.now().strftime('%I:%M %p')} da!"
        elif any(food in query for food in ["hungry", "biryani", "tiffin"]):
            return "Naanum sapdanum... Zomato la order pannu da!"
        else:
            return random.choice([
                "Puriyala da, explain again!",
                "Naan serious-ah keten...",
                "Ippo en mood ku set agala, appuram pesu!"
            ])
    
    # ----------- MEMORY & LEARNING ----------- #
    def _log_conversation(self, text):
        """Save conversation to memory"""
        self.memories["conversation_history"].append({
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "text": text,
            "mood": self.mood
        })
    
    def save_memories(self, filename="teju_memories.json"):
        """Export conversation history"""
        with open(filename, 'w') as f:
            json.dump(self.memories, f, indent=2)
        return f"Memories saved to {filename} da!"
    
    # ----------- EMOTION ENGINE ----------- #
    def _update_mood(self, query):
        """Analyze query to determine mood"""
        if any(word in query for word in ["love", "miss", "dear"]):
            self._change_mood("romantic")
        elif any(word in query for word in ["angry", "hate", "stop"]):
            self._change_mood("angry")
        else:
            self._change_mood("happy")
    
    def _change_mood(self, new_mood):
        """Change emotional state with effects"""
        self.mood = new_mood
        if new_mood == "romantic":
            print("System: Playing romantic background music")
        elif new_mood == "angry":
            print("System: Chappal throwing sound effect")

# ----------- MAIN LOOP ----------- #
if _name_ == "_main_":
    print("""\n
    ████████╗███████╗██╗░░░██╗██╗░░░██╗
    ╚══██╔══╝██╔════╝██║░░░██║██║░░░██║
    ░░░██║░░░█████╗░░╚██╗░██╔╝╚██╗░██╔╝
    ░░░██║░░░██╔══╝░░░╚████╔╝░░╚████╔╝░
    ░░░██║░░░███████╗░░╚██╔╝░░░░╚██╔╝░░
    ░░░╚═╝░░░╚══════╝░░░╚═╝░░░░░░╚═╝░░░
    """)
    
    teju = UltimateTeju()
    teju.speak("Vanakkam da! Naan Teju, un AI companion!")
    
    running = True
    while running:
        try:
            query = teju.listen()
            if query:
                running = teju.respond(query)
        except KeyboardInterrupt:
            teju.speak("Keyboard interrupt da! Naan exit aaguren!")
            running = False
    
    teju.save_memories()
    print("Conversation history saved. Bye kanna!")