import asyncio
import os
import edge_tts

PHRASES = {
    "hi": {
        "voice": "hi-IN-SwaraNeural",
        "rate": "+0%",  # Natural, authentic Indian Hindi speed and cadence
        "clips": {
            "greeting": "नमस्ते! आप आज कैसा महसूस कर रहे हैं?",
            "calm_anxiety": "शांत हो जाइए, गहरी सांस लीजिए, सब ठीक है।",
            "open_memory": "कार्ड मैच शुरू कर रही हूँ, कार्ड्स मिलाइए!",
            "open_card_match": "कार्ड मैच शुरू कर रही हूँ, कार्ड्स मिलाइए!",
            "open_object_finder": "ऑब्जेक्ट फाइंडर शुरू कर रही हूँ, तस्वीरें याद रखिए!",
            "open_recall": "ऑब्जेक्ट फाइंडर शुरू कर रही हूँ, तस्वीरें याद रखिए!",
            "open_face_recall": "फेस रिकॉल शुरू कर रही हूँ, परिवार को पहचानिए!",
            "open_pattern": "पैटर्न पाथ शुरू कर रही हूँ, रास्ता याद रखिए!",
            # 4 Game Starting Screen Instructions (Covering all 3 steps clearly)
            "intro_card_match": "कार्ड मैच खेलने का तरीका: बोर्ड पर पत्ते उल्टे रखे जाएंगे। प्रतीकों को देखने के लिए किन्हीं दो पत्तों पर टैप करें। जीतने के लिए सभी समान जोड़ों को मिलाएं!",
            "intro_memory_match": "कार्ड मैच खेलने का तरीका: बोर्ड पर पत्ते उल्टे रखे जाएंगे। प्रतीकों को देखने के लिए किन्हीं दो पत्तों पर टैप करें। जीतने के लिए सभी समान जोड़ों को मिलाएं!",
            "intro_object_finder": "ऑब्जेक्ट फाइंडर खेलने का तरीका: स्क्रीन पर चित्र कार्ड दिखेंगे। इन्हें ध्यान से याद कर लीजिए, फिर मैं तैयार हूँ दबाएं। याद किए गए सभी सही चित्रों को चुनिए!",
            "intro_memory_recall": "ऑब्जेक्ट फाइंडर खेलने का तरीका: स्क्रीन पर चित्र कार्ड दिखेंगे। इन्हें ध्यान से याद कर लीजिए, फिर मैं तैयार हूँ दबाएं। याद किए गए सभी सही चित्रों को चुनिए!",
            "intro_pattern_path": "पैटर्न पाथ खेलने का तरीका: रास्ते में चमकते पत्थरों को ध्यान से देखें। पत्थरों के क्रम को अच्छी तरह याद रखें। उसी क्रम में पत्थरों पर टैप करके रास्ता पूरा करें!",
            "intro_face_recall": "फेस रिकॉल खेलने का तरीका: स्क्रीन पर दिखाए गए नाम और रिश्ते को सुनें। परिवार की तस्वीरों को ध्यान से देखें। पूछे गए सदस्य की तस्वीर पर टैप करें!",
            # In-game action prompts
            "face_find": "परिवार और दोस्तों की तस्वीरें देखिए और सही सदस्य को पहचानिए।",
            "face_win": "बहुत बढ़िया, आपने परिवार के सभी सदस्यों को सही पहचान लिया!",
            "pattern_watch": "पैटर्न को ध्यान से देखिए।",
            "pattern_win": "बहुत बढ़िया, आपने पूरा पैटर्न बिल्कुल सही याद रखा!",
            "match_find": "सभी मैचिंग कार्ड्स ढूंढिए!",
            "match_win": "शाबाश, आपने सभी कार्ड्स सही मिला दिए!",
            "recall_images": "वस्तुओं को ध्यान से याद रखिए।",
            "select_images": "देखी गई वस्तुओं को चुनिए।",
            "how_are_you": "मैं बिल्कुल ठीक हूँ! आप बताइए, आज चाय पी ली?",
            "talk_joke": "डॉक्टर ने कहा- आपका दिमाग बहुत तेज है, बस इस्तेमाल भी कीजिए! हाहा, चलिए खेलें!",
            "talk_tea": "अरे वाह, कड़क चाय! चलिए, अब एक खेल हो जाए?",
            "talk_bored": "अरे बोर मत होइए, मैं हूँ ना! चलिए एक गेम खेलते हैं!",
            "talk_praise": "अरे वाह, आप बहुत प्यारे हैं! हमेशा मुस्कुराते रहिए!",
            "ready": "बहुत बढ़िया, चलिए शुरू करते हैं!",
        }
    },
    "en": {
        "voice": "en-IN-NeerjaNeural",
        "rate": "+0%",  # Natural, authentic Indian English accent
        "clips": {
            "greeting": "Hello! How are you feeling today?",
            "calm_anxiety": "Take a gentle deep breath, everything will be fine.",
            "open_memory": "Starting Card Match, let's find the pairs!",
            "open_card_match": "Starting Card Match, let's find the pairs!",
            "open_object_finder": "Starting Object Finder, memorize the objects!",
            "open_recall": "Starting Object Finder, memorize the objects!",
            "open_face_recall": "Starting Face Recall, let's recognize your family!",
            "open_pattern": "Starting Pattern Path, remember the tiles!",
            # 4 Game Starting Screen Instructions (Covering all 3 steps clearly)
            "intro_card_match": "How to play Card Match: Cards are placed face down on the board. Tap two cards to flip and reveal their symbols. Match all identical pairs to finish!",
            "intro_memory_match": "How to play Card Match: Cards are placed face down on the board. Tap two cards to flip and reveal their symbols. Match all identical pairs to finish!",
            "intro_object_finder": "How to play Object Finder: Illustration cards will appear on screen. Take your time to memorize them, then tap I'm Ready. Select all the correct images you memorized!",
            "intro_memory_recall": "How to play Object Finder: Illustration cards will appear on screen. Take your time to memorize them, then tap I'm Ready. Select all the correct images you memorized!",
            "intro_pattern_path": "How to play Pattern Path: Watch the stones light up along the path. Remember the sequence carefully. Tap the stepping stones in the same order!",
            "intro_face_recall": "How to play Face Recall: Listen to the name and relation shown on screen. Look carefully at the family photos displayed. Tap the photo of the requested person to earn points!",
            # In-game action prompts
            "face_find": "Look at the photos and tap your family member.",
            "face_win": "Wonderful, you recognized all your family members correctly!",
            "pattern_watch": "Watch the pattern closely.",
            "pattern_win": "Excellent, you remembered the entire pattern correctly!",
            "match_find": "Find all the matching pairs!",
            "match_win": "Great job, you matched all the pairs!",
            "recall_images": "Memorize these images.",
            "select_images": "Select the images you saw.",
            "how_are_you": "I'm doing great! Did you have your tea today?",
            "talk_joke": "Why did the computer sneeze? It caught a virus! Haha, let's play!",
            "talk_tea": "Hot tea sounds lovely! Shall we play a quick game?",
            "talk_bored": "Don't be bored, I'm right here! Let's play a fun game!",
            "talk_praise": "Aww, you're wonderful! Keep smiling always!",
            "ready": "Awesome, let's get started!",
        }
    },
    "bn": {
        "voice": "bn-IN-TanishaaNeural",
        "rate": "+0%",
        "clips": {
            "greeting": "নমস্কার! আপনি আজ কেমন আছেন?",
            "calm_anxiety": "শান্ত হন, গভীর শ্বাস নিন, সব ঠিক আছে।",
            "open_memory": "কার্ড ম্যাচ শুরু করছি, জোড়া মেলান!",
            "open_card_match": "কার্ড ম্যাচ শুরু করছি, জোড়া মেলান!",
            "open_object_finder": "অবজেক্ট ফাইন্ডার শুরু করছি, ছবি মনে রাখুন!",
            "open_recall": "অবজেক্ট ফাইন্ডার শুরু করছি, ছবি মনে রাখুন!",
            "open_face_recall": "ফেস রিকল শুরু করছি, পরিবারকে চিনুন!",
            "open_pattern": "প্যাটার্ন পাথ শুরু করছি, পথ মনে রাখুন!",
            # 4 Game Starting Screen Instructions (Covering all 3 steps clearly)
            "intro_card_match": "কার্ড ম্যাচ খেলার নিয়ম: বোর্ডে কার্ডগুলি উল্টো করে রাখা হবে। প্রতীক দেখতে দুটি কার্ডে ট্যাপ করুন। শেষ করতে সমস্ত জোড়া মিলিয়ে দিন!",
            "intro_memory_match": "কার্ড ম্যাচ খেলার নিয়ম: বোর্ডে কার্ডগুলি উল্টো করে রাখা হবে। প্রতীক দেখতে দুটি কার্ডে ট্যাপ করুন। শেষ করতে সমস্ত জোড়া মিলিয়ে দিন!",
            "intro_object_finder": "অবজেক্ট ফাইন্ডার খেলার নিয়ম: স্ক্রিনে ছবি কার্ড দেখতে পাবেন। মন দিয়ে সেগুলি মনে রাখুন, তারপর তৈরি বোতাম টিপুন। মনে রাখা সব সঠিক ছবি নির্বাচন করুন!",
            "intro_memory_recall": "অবজেক্ট ফাইন্ডার খেলার নিয়ম: স্ক্রিনে ছবি কার্ড দেখতে পাবেন। মন দিয়ে সেগুলি মনে রাখুন, তারপর তৈরি বোতাম টিপুন। মনে রাখা সব সঠিক ছবি নির্বাচন করুন!",
            "intro_pattern_path": "প্যাটার্ন পাথ খেলার নিয়ম: পাথরের আলো জ্বলা মনোযোগ দিয়ে দেখুন। ক্রমটি মনে রাখুন এবং একই ক্রমে ট্যাপ করে পথ সম্পূর্ণ করুন!",
            "intro_face_recall": "ফেস রিকল খেলার নিয়ম: স্ক্রিনে নাম ও সম্পর্ক শুনুন। পরিবারের ছবিগুলি মনোযোগ দিয়ে দেখুন। সঠিক ব্যক্তির ছবিতে ট্যাপ করুন!",
            # In-game action prompts
            "face_find": "ছবিগুলি দেখুন এবং আপনার পরিবারের সদস্যকে বেছে নিন।",
            "face_win": "চমৎকার, আপনি পরিবারের সমস্ত সদস্যদের সঠিকভাবে চিনতে পেরেছেন!",
            "pattern_watch": "প্যাটার্নটি মনোযোগ দিয়ে দেখুন।",
            "pattern_win": "অসাধারণ, আপনি পুরো প্যাটার্নটি সঠিকভাবে মনে রেখেছেন!",
            "match_find": "সমস্ত ম্যাচিং কার্ড খুঁজে বের করুন!",
            "match_win": "দারুণ, আপনি সমস্ত জোড়া সঠিকভাবে মিলিয়েছেন!",
            "recall_images": "ছবিগুলি মনোযোগ দিয়ে মনে রাখুন।",
            "select_images": "আপনি যে ছবিগুলি দেখেছিলেন সেগুলি নির্বাচন করুন।",
            "how_are_you": "আমি খুব ভালো আছি! আজ চা খাওয়া হলো?",
            "talk_joke": "ডাক্তার বললেন- আপনার মাথা খুব ভালো, মাঝেমধ্যে ব্যবহার করবেন! হা হা, চলুন খেলি!",
            "talk_tea": "গরম চা আর মিষ্টি গল্প! চলুন এবার একটা খেলা হোক?",
            "talk_bored": "বোর হবেন না, আমি তো আছি! চলুন খেলা যাক!",
            "talk_praise": "আপনি খুব মিষ্টি মানুষ! সবসময় হাসিমুখে থাকুন!",
            "ready": "দারুণ, চলুন শুরু করা যাক!",
        }
    },
    "as": {
        "voice": "bn-IN-TanishaaNeural",
        "rate": "+0%",
        "clips": {
            "greeting": "নমস্কাৰ! আপুনি আজি কেনে অনুভৱ কৰিছে?",
            "calm_anxiety": "শান্ত হওক, দীঘল উশাহ লওক, সকলো ঠিক আছে।",
            "open_memory": "কাৰ্ড মেচ আৰম্ভ কৰিছোঁ, কাৰ্ডবোৰ মেলাওক!",
            "open_card_match": "কাৰ্ড মেচ আৰম্ভ কৰিছোঁ, কাৰ্ডবোৰ মেলাওক!",
            "open_object_finder": "অবজেক্ট ফাইণ্ডাৰ আৰম্ভ কৰিছোঁ, মনত ৰাখক!",
            "open_recall": "অবজেক্ট ফাইণ্ডাৰ আৰম্ভ কৰিছোঁ, মনত ৰাখক!",
            "open_face_recall": "ফেচ ৰিকল আৰম্ভ কৰিছোঁ, চিনি পাওক!",
            "open_pattern": "পেটাৰ্ন পাথ আৰম্ভ কৰিছোঁ, পথ মনত ৰাখক!",
            # 4 Game Starting Screen Instructions (Covering all 3 steps clearly)
            "intro_card_match": "কাৰ্ড মেচ খেলৰ নিয়ম: ব'ৰ্ডত কাৰ্ডবোৰ ওলোটাকৈ ৰখা হ'ব। প্ৰতীক চাবলৈ দুখন কাৰ্ডত টেপ কৰক। শেষ কৰিবলৈ সকলো যোৰ মিলাই দিয়ক!",
            "intro_memory_match": "কাৰ্ড মেচ খেলৰ নিয়ম: ব'ৰ্ডত কাৰ্ডবোৰ ওলোটাকৈ ৰখা হ'ব। প্ৰতীক চাবলৈ দুখন কাৰ্ডত টেপ কৰক। শেষ কৰিবলৈ সকলো যোৰ মিলাই দিয়ক!",
            "intro_object_finder": "অবজেক্ট ফাইণ্ডাৰ খেলৰ নিয়ম: স্ক্ৰীনত ছবি কাৰ্ড দেখা পাব। মনোযোগেৰে মনত ৰাখক, তাৰ পিছত মই সাজু টিপক। মনত ৰখা সকলো সঠিক ছবি বাছক!",
            "intro_memory_recall": "অবজেক্ট ফাইণ্ডাৰ খেলৰ নিয়ম: স্ক্ৰীনত ছবি কাৰ্ড দেখা পাব। মনোযোগেৰে মনত ৰাখক, তাৰ পিছত মই সাজু টিপক। মনত ৰখা সকলো সঠিক ছবি বাছক!",
            "intro_pattern_path": "পেটাৰ্ন পাথ খেলৰ নিয়ম: শিলৰ পোহৰ মনোযোগেৰে চাওক। ক্ৰমটো মনত ৰাখক আৰু একে ক্ৰমত টেপ কৰি পথ সম্পূৰ্ণ কৰক!",
            "intro_face_recall": "ফেচ ৰিকল খেলৰ নিয়ম: স্ক্ৰীনত নাম আৰু সম্পৰ্ক শুনক। পৰিয়ালৰ ছবিবোৰ মনোযোগেৰে চাওক। সঠিক ব্যক্তিৰ ছবিত টেপ কৰক!",
            # In-game action prompts
            "face_find": "ছবিবোৰ চাওক আৰু পৰিয়ালৰ সদস্যক বাছক।",
            "face_win": "অসাধাৰণ, আপুনি পৰিয়ালৰ সকলো সদস্যক সঠিকভাৱে চিনি পালে!",
            "pattern_watch": "পেটাৰ্নটো মনোযোগেৰে চাওক।",
            "pattern_win": "অসাধাৰণ, আপুনি গোটেই পেটাৰ্নটো সঠিকভাৱে মনত ৰাখিলে!",
            "match_find": "সকলো মিলা কাৰ্ড বিচাৰি উলিয়াওক!",
            "match_win": "অতি সুন্দৰ, আপুনি সকলো কাৰ্ড সঠিকভাৱে মিলাই দিলে!",
            "recall_images": "ছবিবোৰ মনোযোগেৰে মনত ৰাখক।",
            "select_images": "দেখা পোৱা ছবিবোৰ বাছক।",
            "how_are_you": "মই বঢ়িয়া আছোঁ! আজি চাহ খালে নে?",
            "talk_joke": "ডাক্তৰে ক'লে- আপোনাৰ মগজু বৰ চোকা, ব্যৱহাৰো কৰিব! হাহা, আহক খেলোঁ!",
            "talk_tea": "গৰম চাহ আৰু শুৱলা কথা! আহক এটা খেল খেলোঁ?",
            "talk_bored": "আমনি নাপাব, মই আছোঁ নহয়! আহক খেলোঁ!",
            "talk_praise": "আপুনি বৰ মৰমলগা মানুহ! সদায় এনেকৈয়ে হাঁহি থাকিব!",
            "ready": "বৰ ভাল, আহক আৰম্ভ কৰোঁ!",
        }
    },
    "mni": {
        "voice": "bn-IN-TanishaaNeural",
        "rate": "+0%",
        "clips": {
            "greeting": "খুরুমজরি! অদোম ঙসি করম্না তৌরি?",
            "calm_anxiety": "ৱাখল ৱাগনু, লুহৌবা লোউ, লোইনা ফগনি।",
            "open_memory": "কার্দ ম্যাচ হৌরে, চান্নহল্লু!",
            "open_card_match": "কার্দ ম্যাচ হৌরে, চান্নহল্লু!",
            "open_object_finder": "অবজেক্ট ফাইন্ডার হৌরে, নিংশিংউ!",
            "open_recall": "অবজেক্ট ফাইন্ডার হৌরে, নিংশিংউ!",
            "open_face_recall": "ফেস রিকল হৌরে, খঙদোকউ!",
            "open_pattern": "প্যাটার্ন পাথ হৌরে, লম্বী নিংশিংউ!",
            # 4 Game Starting Screen Instructions (Covering all 3 steps clearly)
            "intro_card_match": "কার্দ ম্যাচ শান্নবগী নিয়ম: বোর্দতা কার্দশিং অদু খুপতুনা থমগনি। শক্তম য়েংনবা কার্দ অনিদা থম্বীয়ু। লোইশিন্নবা কার্দ পুম্নমক চপ চানা চান্নহল্লু!",
            "intro_memory_match": "কার্দ ম্যাচ শান্নবগী নিয়ম: বোর্দতা কার্দশিং অদু খুপতুনা থমগনি। শক্তম য়েংনবা কার্দ অনিদা থম্বীয়ু। লোইশিন্নবা কার্দ পুম্নমক চপ চানা চান্নহল্লু!",
            "intro_object_finder": "অবজেক্ট ফাইন্ডার শান্নবগী নিয়ম: স্ক্রিন্দা ফোতো কাৰ্দ উগনি। নীংথিনা নিংশিংউ, অদুগা ঐ শেম-শারে নম্বীয়ু। নিংশিংবা ফোতোশিং খনউ!",
            "intro_memory_recall": "অবজেক্ট ফাইন্ডার শান্নবগী নিয়ম: স্ক্রিন্দা ফোতো কাৰ্দ উগনি। নীংথিনা নিংশিংউ, অদুগা ঐ শেম-শারে নম্বীয়ু। নিংশিংবা ফোতোশিং খনউ!",
            "intro_pattern_path": "প্যাটার্ন পাথ শান্নবগী নিয়ম: নোংশাংশিংগী মঙাল নীংথিনা য়েংউ। মথং মনাও নীংথিনা নিংশিংউ অমসুং চপ মান্ননা থম্বীয়ু!",
            "intro_face_recall": "ফেস রিকল শান্নবগী নিয়ম: মমিং অমসুং মরী নীংথিনা তাবীয়ু। ইমুংগী ফোতোশিং নীংথিনা য়েংউ। চপ চাবা মীওই অদুগী ফোতোদা থম্বীয়ু!",
            # In-game action prompts
            "face_find": "ফোতোশিং য়েংউ অমসুং নহাক্কী ইমুংগী মীওই অদু খঙদোকউ।",
            "face_win": "য়াম্না ফরে, অদোম্না ইমুংগী মী পুম্নমক চপ চানা খঙদোকলে!",
            "pattern_watch": "প্যাটার্ন অসিবু নীংথিনা য়েংউ।",
            "pattern_win": "য়াম্না ফরে, অদোম্না প্যাটার্ন পুম্নমক চপ চানা নিংশিংলি!",
            "match_find": "মান্নবা কার্দ পুম্নমক থিদোকউ!",
            "match_win": "য়াম্না থাগৎচরি, অদোম্না কার্দ পুম্নমক চপ চানা চান্নহল্লে!",
            "recall_images": "মিৎয়েংশিং অসিবু নীংথিনা নিংশিংউ।",
            "select_images": "অদোম্না উখিবা মিৎয়েংশিং অদু খনউ।",
            "how_are_you": "ঐ য়াম্না ফরে! চাহ থকলব্রা?",
            "talk_joke": "ডাক্তরনা হায়রি- নহাক্কী ৱাখল য়াম্না ফৈ, শিজিন্নবিয়ু! হাহা, চৎসি শান্নসি!",
            "talk_tea": "অশেংবা চাহ অমসুং ৱারী! চৎসি অমা শান্নসি?",
            "talk_bored": "ৱাগনু, ঐ লৈরিবা নত্রো! চৎসি শান্নসি!",
            "talk_praise": "অদোম য়াম্না অফবা মীওইনি! মোমোনোকনা লৈবীয়ু!",
            "ready": "য়াম্না ফরে, চৎসি হৌসিগে!",
        }
    },
    "miz": {
        "voice": "en-IN-NeerjaNeural",
        "rate": "+0%",
        "clips": {
            "greeting": "Chibai! Engtin nge vawiin i awm?",
            "calm_anxiety": "Lungngai suh, thawk la vak la, a tha vek mai ang.",
            "open_memory": "Card Match kan tan e, a inmil zawng rawh!",
            "open_card_match": "Card Match kan tan e, a inmil zawng rawh!",
            "open_object_finder": "Object Finder kan tan e, vawng reng rawh!",
            "open_recall": "Object Finder kan tan e, vawng reng rawh!",
            "open_face_recall": "Face Recall kan tan e, hre reng rawh!",
            "open_pattern": "Pattern Path kan tan e, vawng reng rawh!",
            # 4 Game Starting Screen Instructions (Covering all 3 steps clearly)
            "intro_card_match": "Card Match khelh dan: Card-te chu a khup zawngin dah a ni ang. A lem en turin card pahnih hmet la, a inmil zawng zawng zawng chhuak rawh le!",
            "intro_memory_match": "Card Match khelh dan: Card-te chu a khup zawngin dah a ni ang. A lem en turin card pahnih hmet la, a inmil zawng zawng zawng chhuak rawh le!",
            "intro_object_finder": "Object Finder khelh dan: Screen ah lemte a lo lang ang. Ngun takin vawng reng la, Ka inpeih e tih hmet la, i hriatreng lemte kha thlang chhuak rawh le!",
            "intro_memory_recall": "Object Finder khelh dan: Screen ah lemte a lo lang ang. Ngun takin vawng reng la, Ka inpeih e tih hmet la, i hriatreng lemte kha thlang chhuak rawh le!",
            "intro_pattern_path": "Pattern Path khelh dan: Lung eng kha ngun takin en la, a inrem dan vawng reng la, a indawtin hmet rawh le!",
            "intro_face_recall": "Face Recall khelh dan: Screen a hming leh inlaichinna lo lang kha ngaihthlak rawh. Thlalak en la, an sawi tak kha thlang chhuak rawh le!",
            # In-game action prompts
            "face_find": "Thlalak en la, i chhungte thlang chhuak rawh.",
            "face_win": "A va ropui em, i chhungte zawng zawng i hre dik vek e!",
            "pattern_watch": "A kalphung kha ngun takin en rawh.",
            "pattern_win": "A va ropui em, a kalphung zawng zawng i hre dik vek e!",
            "match_find": "A inmil zawng zawng zawng chhuak rawh le!",
            "match_win": "I ti tha lutuk, a inmil zawng zawng i zawng chhuak vek e!",
            "recall_images": "Heng lemte hi ngun takin vawng reng rawh.",
            "select_images": "I lem hmuhte kha thlang chhuak rawh.",
            "how_are_you": "Ka tha lutuk e! Thingpui i in tawh em?",
            "talk_joke": "Doctor-in damlo hnenah, 'I thluak a tha lutuk, hmang ve thin rawh' a ti! Haha, khel ang le!",
            "talk_tea": "Thingpui sa tha tak! Game khel ang hmiang?",
            "talk_bored": "Ning suh, ka awm alawm! Game khel ang hmiang!",
            "talk_praise": "I va fel tak em! Hlim reng rawh aw!",
            "ready": "A tha lutuk, kan tan e!",
        }
    }
}

async def generate():
    base_dir = os.path.join(os.getcwd(), "assets", "audio", "voice")
    for lang, data in PHRASES.items():
        lang_dir = os.path.join(base_dir, lang)
        os.makedirs(lang_dir, exist_ok=True)
        voice = data["voice"]
        rate = data["rate"]
        print(f"\nGenerating {lang} audio clips using {voice} (rate: {rate})...", flush=True)
        for key, text in data["clips"].items():
            output_path = os.path.join(lang_dir, f"{key}.mp3")
            try:
                communicate = edge_tts.Communicate(text, voice, rate=rate)
                await communicate.save(output_path)
                size = os.path.getsize(output_path)
                print(f"  [OK] {lang}/{key}.mp3 ({size} bytes)", flush=True)
            except Exception as e:
                print(f"  [ERROR] {lang}/{key}.mp3: {e}", flush=True)
    print("\nAll game intro and in-game audio clips generated and overwritten successfully!", flush=True)

if __name__ == "__main__":
    asyncio.run(generate())
