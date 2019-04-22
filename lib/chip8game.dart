import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'core.dart';

class Chip8Game extends Game {
  // Emulating the CPU/Game logic goes in Core
  Core core;
  // UI variables
  Size screenSize;
  Color background;
  Color foreground;
  Color highlight;
  Paint forePaint;
  Paint backPaint;
  Paint highlightPaint;
  Paint screenPaint;
  TextPainter pausedTextPainter;
  Offset pausedOffset;
  double margin = 10.0;
  List<_GameButton> gameButtonMapping;
  // Internal size updates...
  var aspectRatio;
  int height;
  int width;
  var slackVertical;
  var slackHorizontal;
  var unitHorizontalSize;
  var unitVerticalSize;
  var halfHorizontalSlack;
  var halfVerticalSlack;
  var bgRect;
  var screenRect;
  var totalButtonRectHeight;
  var individualButtonSize;
  var buttonCenterMargin;

  Chip8Game({this.background, this.foreground, this.highlight, this.core}) {
    forePaint = new Paint()
      ..color = foreground
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    backPaint = new Paint()
      ..color = background
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    highlightPaint = new Paint()
      ..color = highlight
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    screenPaint = new Paint()..color = Color(0xff000000);
    TextSpan span = new TextSpan(
        text: "PAUSED",
        style: new TextStyle(fontFamily: "PressStart2P", color: Color.fromARGB(255, 255, 255, 255)));
    pausedTextPainter = new TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    pausedTextPainter.layout();
    aspectRatio = core.width / core.height;
  }

  init() async {
    await Flame.audio.load("beep.mp3");
    bool playing = false;
    // TODO: Loop doesn't seem to be working properly here for Flame Audio.
    core.playChip8Sound = () {
      if (!playing) {
        playing = true;
        Flame.audio.play("beep.mp3");
      }
    };
    core.stopChip8Sound = () {
      if (playing) {
        playing = false;
      }
    };
  }

  void onTapDown(TapDownDetails e) {
    gameButtonMapping.forEach((btn) {
      if (btn.backgroundRect.contains(e.globalPosition)) {
        debugPrint("Clicked button down: ${btn.val}");
        core.keyDownEvent(btn.val);
        btn.highlighted = true;
      }
    });

    if (screenRect.contains(e.globalPosition)) {
      core.setPause(!core.paused);
    }
  }

  void onTapUp(TapUpDetails e) {
    gameButtonMapping.forEach((btn) {
      if (btn.backgroundRect.contains(e.globalPosition)) {
        debugPrint("Clicked button up: ${btn.val}");
        core.keyUpEvent(btn.val);
        btn.highlighted = false;
      }
    });
  }

  @override
  void render(Canvas canvas) {
    // Fill background
    canvas.drawRect(bgRect, screenPaint);
    // Fill screen
    canvas.drawRect(screenRect, backPaint);

    if (!core.paused) {
      // Render Screen
      for (int i = 0; i < core.width; i++) {
        for (int j = 0; j < core.height; j++) {
          var bufferVal = core.buffer[i + (j * core.width)];
          if (bufferVal > 0) {
            canvas.drawRect(
                Rect.fromLTWH(
                    unitHorizontalSize * i + halfHorizontalSlack,
                    unitVerticalSize * j + halfVerticalSlack,
                    unitHorizontalSize,
                    unitVerticalSize),
                forePaint);
          }
        }
      }
    } else {
      pausedTextPainter.paint(canvas, pausedOffset);
    }

    gameButtonMapping.asMap().forEach((index, btn) {
      canvas.drawRect(btn.backgroundRect,
          btn.highlighted ? btn.highlightPaint : btn.backPaint);
      btn.textPainter.paint(canvas, btn.textOffset);
    });
  }

  void loadGame(ByteData game) {
    core.setPause(true);
    core.resetState();
    core.loadProgram(game);
  }

  @override
  void update(double t) {
    if (core != null && !core.isPaused()) {
      for (int i = 0; i < Core.CYCLES_PER_TICK; i++) {
        core.emulateCycle();
      }
      core.procTimers();
    }
  }

  void resize(Size size) {
    screenSize = size;
    totalButtonRectHeight = screenSize.height / 3;
    height = (screenSize.height - margin - totalButtonRectHeight).toInt();
    width = (screenSize.width - margin).toInt();
    slackVertical = margin;
    slackHorizontal = margin;
    var isHeightGreater = height > width;
    if (isHeightGreater) {
      height = (screenSize.width * (1 / aspectRatio)).toInt();
      slackVertical = screenSize.height - height - totalButtonRectHeight;
    } else {
      throw Exception("Horizontal layouts are not supported!");
    }

    unitHorizontalSize = width / core.width;
    unitVerticalSize = height / core.height;
    debugPrint("Horizontal Size: $unitHorizontalSize");
    debugPrint("Vertical Size: $unitVerticalSize");
    halfHorizontalSlack = slackHorizontal / 2;
    halfVerticalSlack = slackVertical / 2;

    bgRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    screenRect = Rect.fromLTWH(halfHorizontalSlack, halfVerticalSlack,
        width.toDouble(), height.toDouble());

    // Determine button sizing (assume width > 1/3 height)
    individualButtonSize = (totalButtonRectHeight - (5 * margin)) / 4;
    buttonCenterMargin = (width - totalButtonRectHeight) / 2;

    pausedOffset = Offset(
        screenRect.center.dx - pausedTextPainter.size.width / 2,
        screenRect.center.dy - pausedTextPainter.size.height / 2);

    mapGameButtons();
    super.resize(size);
  }

  void mapGameButtons() {
    gameButtonMapping = new List(core.keys.length);
    core.keys.asMap().forEach((index, str) {
      var i = index ~/ 4; // Row
      var j = index % 4; // Column

      TextSpan span = new TextSpan(
          text: str,
          style: new TextStyle(fontFamily: "PressStart2P", color: Color.fromARGB(255, 255, 255, 255)));
      TextPainter tp = new TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr);
      tp.layout();

      var backgroundRect = Rect.fromLTWH(
          buttonCenterMargin +
              (j * individualButtonSize) +
              (j * margin) +
              margin,
          halfVerticalSlack +
              height +
              (i * individualButtonSize) +
              (i * margin) +
              margin,
          individualButtonSize,
          individualButtonSize);
      var textOffset = Offset(backgroundRect.center.dx - tp.size.width / 2,
          backgroundRect.center.dy - tp.size.height / 2);

      gameButtonMapping[index] = new _GameButton(
          val: str,
          textPainter: tp,
          backgroundRect: backgroundRect,
          textOffset: textOffset,
          backPaint: backPaint,
          highlightPaint: highlightPaint);
    });
  }
}

class _GameButton {
  String val;
  TextPainter textPainter;
  Rect backgroundRect;
  Offset textOffset;
  Paint backPaint;
  Paint highlightPaint;

  bool highlighted;

  _GameButton(
      {this.val,
      this.textPainter,
      this.backgroundRect,
      this.textOffset,
      this.backPaint,
      this.highlightPaint}) {
    highlighted = false;
  }
}
