# TimmyGram App

It is the iOS app that can consume the self-hosted TimmyGram Server by setting up by parent.

## How does it work?

- A parent sets up a timmygram-server and uploads videos
- When the app is started the parent has the option to connect the app to the server
  - Scan a QR-Code to add the device to the server
  - Enter manually server URL and PIN to connect to the server
  - Optionally set a device name, device description
  - Optionally set a device PIN to lock the settings
 
## What the app does

It connects to the timmygram-server and loads a `/feed` of short videos

A child can select a video and it plays in full-screen with swipe up and down gestures to skip to next or previous video respectively.

The child can like a video once per day

The child can select the video to be downloaded locally to the app storage, so it will be accessible for offline viewing in the app when there
is no internet connection.

## Why does this app exists?

The app was created since I didn't want to give my child access to social media platforms/networks, but I also didn't want him to miss the 
short videos experience. My goal was to allow myself to moderate the videos my son can watch.

## Contributing?

Contributions are very welcomed as long as they don't collide with the core idea - safe usage for kids, parent-moderated content.
