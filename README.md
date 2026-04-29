# 🎮 Gaming Monitor – Child App

![Flutter](https://img.shields.io/badge/Flutter-Framework-blue?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Backend-orange?logo=firebase)
![Dart](https://img.shields.io/badge/Language-Dart-blue?logo=dart)

---

## 📱 Overview

**Gaming Monitor – Child App** is a Flutter-based mobile application that functions as the data collection component of a larger monitoring system.

It tracks device usage and reports activity data to the backend, enabling monitoring and analysis through a separate parent application.

---

## ✨ Features

* **Activity Monitoring**
  Tracks device usage and user interactions

* **Automated Reporting**
  Periodically syncs activity data with the backend

* **Firebase Integration**
  Enables real-time and scalable data handling

* **Efficient Background Execution**
  Runs seamlessly with minimal impact on performance

---

## 🛠️ Tech Stack

* **Flutter** – Cross-platform UI framework
* **Dart** – Programming language
* **Firebase** – Backend services (Realtime Database / Firestore, Authentication)

---

## 🧩 System Architecture

This project is part of a modular system where each component is handled independently:

* **Child Application (this repo)** – Collects and sends activity data
* **Parent Application** – Displays monitoring insights
* **Backend Services** – Handles data storage and communication
* **Usage Analysis Module** – Evaluates activity patterns and usage behavior

---

## 👨‍💻 My Contribution

This project was developed as a modular team-based system, where each member owned a core component.

I was fully responsible for the **Child Application**, which serves as the primary data collection layer of the system.

My responsibilities included:

* Architecting and developing the **entire Child App**
* Implementing **device activity tracking logic**
* Integrating Firebase for **real-time data communication**
* Managing background processes for continuous monitoring
* Ensuring reliable data transmission across the system

The Child App is a **critical part of the architecture**, as all monitoring and analysis depend on the data it provides.

---

## 🤝 Acknowledgements

Built collaboratively as a team project.

---

## 📌 Notes

* This repository contains only the **Child-side application**
* Designed to work alongside the corresponding Parent App
