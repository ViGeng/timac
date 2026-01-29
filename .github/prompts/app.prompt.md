---
agent: agent
---

This is an app that tracks time spent on each app to have an overview of how time has been distributed.

## Design

- should be simple, apple native style
- UI should be simple, concise, and clean

## Functionality

- working as an menu bar app with a simple icon (can use a apple built in time related icon)
- can be a login item to start tracking time when user login
- when click the menu bar icon, it shows a menu with
  - main UI window: showing time spent on each apps as a list sorting from the most used app on the top
  - "Start/Pause" button to start or pause the tracking(should show current status)
  - exit button to quit the app

## Implementations

- This app tracks the frontend app that the user is working on
- the records may include (app, front_begin, front_end), then here comes another record for another app when switching to another app
- the records store should be well designed for easier querying and statistics
