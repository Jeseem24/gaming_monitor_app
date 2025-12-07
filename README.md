# 🎮 Gaming Monitor App (Flutter)

A mobile app that tracks which games are played on the device and how long they are played.  
The app sends this usage data to our backend, which generates a **gaming report** and a **digital twin** (user profile).

---

## 🚀 What This App Does 

1. Detects when a game is opened or closed.  
2. Calculates how long the game was played.  
3. Stores the event temporarily in **local SQLite** (offline mode).  
4. Sends the data to the backend when the internet is available.  
5. Fetches the user’s updated report from the backend.  
6. Displays total today usage, weekly usage, night usage, and status (Healthy / Moderate / Excessive).

---

## 🧩 How the System Works 
### **App Role (Frontend)**
- Tracks game activity.  
- Saves data locally.  
- Syncs with backend every 30 seconds.  
- Shows dashboard data to the user.

### **Backend Role**
- Saves data in PostgreSQL database.  
- Calculates daily + weekly usage and other values.  
- Returns reports when the app asks.

---

## 🔌 Backend Endpoints 

All requests include header:

X-API-KEY: secret

| Purpose | Endpoint | Method |
|--------|----------|--------|
| Health check | /health | GET |
| Send game session | /events | POST |
| Get report | /reports/{user_id} | GET |
| Get full digital twin | /digital-twin/{user_id} | GET |
| Update thresholds | /digital-twin/{user_id}/threshold | POST |

---

## 👥 For Teammates
If backend shows User Not Found, it means no data has been sent yet.

Once the app syncs its first event, backend will create the user.

SQLite is only for temporary unsynced events.

Real stored data is in the PostgreSQL backend database.

