# medo-delirio-api

This is the server counterpart to the [Medo e Delírio iOS/iPadOS/macOS app](https://github.com/rafaelclaycon/MedoDelirioBrasilia).

🌟 Star this repo! ↗️

## Features

1. Store user push notification tokens.
1. Send push notifications.
1. Collect anonymized client device model names.
1. Collect anonymized active user data.
1. Store anonymized content sharing statistics sent to the server (opt-out available on the app).
1. Provide top 10 most shared content rankings to the client app (in 2 different flavors - all time and between two dates).
1. Provide total user base count for the curious developer.
1. Store anonymized user-consented usage statistics (Folder data for now).
1. Provide on/off switches (*flags*) for controlling app-side content.
1. Collect usage metrics from certain screens (AuthorDetailView).

## How to run this project

To build and run this project, you'll need:

- A Mac running macOS 12 Monterey or newer;
- Xcode 13.4+;
- admin privileges on the Mac's user account to run and bind the server to the 8080 port.

That's it.

## 🚧 Known glaring shortcoming 🚧

This project does not use random access tokens or any other client-server communication security measure. This is a small project coded by just me (a mostly front-end person) and no personal life-threatening information is sent back and forth.

That said, if you want to help make this better, you're more than welcome to do so by opening a pull request (let's see some code!).

## About this repo

Rafael C. Schmitt – [@mitt_rafael@toot.wales](https://toot.wales/@mitt_rafael)

Distributed under the MIT license. See ``LICENSE`` for more information.
