# medo-delirio-api

This is the server counterpart to the [Medo e Delírio iOS/iPadOS/macOS app](https://github.com/rafaelclaycon/MedoDelirioBrasilia).

🌟 Star this repo! ↗️

🐙 [Sponsor me](https://github.com/sponsors/rafaelclaycon) so I can keep making cool stuff!

Prefer to do it in Reais? [Here you go](https://apoia.se/app-medo-delirio-ios).

## Features

1. Serve sound files for a custom-built sync system built on 100% Apple-native technologies.
1. Store user push notification tokens.
1. Send push notifications.
1. Collect anonymized client device model names.
1. Collect anonymized active user data.
1. Store anonymized content sharing statistics sent to the server (opt-out available on the app).
1. Provide top 10 most shared content rankings to the client app (in 2 different flavors - all time and between two dates).
1. Provide total user base count for the curious developer.
1. Store anonymized usage metrics.
1. Provide on/off switches (*flags*) for controlling app-side content.

## How to run this project

To build and run this project, you'll need:

- A Mac running macOS 13.5 Ventura or later;
- Xcode 15.2 or later;
- admin privileges on the Mac's user account to run and bind the server to the 8080 port.

That's it.

## Curious about how this runs?

This is an API built for the [Medo e Delírio iOS app](https://github.com/rafaelclaycon/MedoDelirioBrasilia) written in 100% Swift that relies on the [Vapor framework](https://vapor.codes) to work. It runs on a Linux VM (Ubuntu to be specific) that costs me just 5 Dollars a month and serves an average of 6,000 unique users, sync system and all. Neat, right?

## 🚧 Known glaring shortcoming 🚧

This project does not use random access tokens or any other client-server communication security measure. This is a small project coded by just me (a mostly front-end person) and no personal life-threatening information is sent back and forth. I do plan on adding HTTPS support in the near future.

That said, if you want to help make this better, you're more than welcome to do so by opening a pull request (let's see some code!).

## About this repo

Rafael C. Schmitt – [@mitt_rafael@toot.wales](https://toot.wales/@mitt_rafael)

Distributed under the MIT license. See ``LICENSE`` for more information.
