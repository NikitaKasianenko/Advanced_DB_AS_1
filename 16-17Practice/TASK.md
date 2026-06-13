# 16-17 Practice: Redis
## 2 points

## Scenario

You are building a **real-time chat application** where Redis is used to manage user sessions, deliver messages instantly, and provide fast recovery after server restarts.

---

## Task 1 – User Sessions with TTL

Implement session management using Redis.

* Create session keys for at least **three users** (e.g., `session:user:1`, `session:user:2`, `session:user:3`).
* Store any session information (e.g., username or login timestamp).
* Set a **TTL of 60 seconds** for each session.
* Verify that the sessions automatically expire after the TTL.

**Goal:** Demonstrate how Redis can be used to store temporary user sessions.

---

## Task 2 – Real-Time Chat with Publish/Subscribe

Implement a chat room called `chat_room`.

* Open one Redis client and subscribe to the channel.
* Open another Redis client and publish at least **three chat messages**.
* Verify that all subscribed clients receive the messages instantly.

**Goal:** Demonstrate how Redis Pub/Sub enables real-time communication.

---

## Task 3 – Persistence Demonstration

Simulate a server restart and verify data recovery.

* Store an important application key (e.g., `app:config` or `system:version`).
* Restart the Redis server or Docker container.
* Check whether the key still exists after the restart.
* Briefly explain which persistence mechanism (RDB or AOF) preserved the data.

**Goal:** Demonstrate how Redis persistence protects important data from server failures.

---
