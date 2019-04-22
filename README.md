# wafer

A simple chip8 implementation in flutter. Mainly made to experiment with Flutter/Dart/Flame and emulation.
Currently has a simple menu and supports executing a small subset of games.

## Issue List

List of things that could be improved:

- Improve flickering
- Fix lines show between cells drawn
- Recognize multiple taps at one time
    - Might be limited by the fact I'm using a TapGestureDetector. There is also a weird issue where buttons don't get untapped. Like either onTapUp either doesn't fire or gives me a different location than the tapDown.
- Improve UI
    - Allow going back to menu from game and improve the look & feel.
- Optimizations
    - Might be somewhat limited by the Flame game engine, since I don't know a way to not redraw every loop.
- Improve sound issues
- Add/test more games
- Add custom icon
- Implement SCHIP48
