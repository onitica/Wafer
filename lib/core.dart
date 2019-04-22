import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

const MEMORY_BYTE_SIZE = 4096;
const STACK_SIZE = 16;
const REGISTER_NUM = 16;
const KEY_NOT_PRESSED_VAL = -1;
const KEY_PRESSED_VAL = 1;

// Implemented based on reference documentation here: http://devernay.free.fr/hacks/chip8/C8TECH10.HTM

class Core {
  static const DEFAULT_WIDTH = 64;
  static const DEFAULT_HEIGHT = 32;
  static const PROGRAM_START = 0x200;
  // Recommended amount of cycles per a tick.
  static const CYCLES_PER_TICK = 10;

  // Display variables
  int width;
  int height;
  Uint8List buffer;
  List<String> keys = [
    '1',
    '2',
    '3',
    'C',
    '4',
    '5',
    '6',
    'D',
    '7',
    '8',
    '9',
    'E',
    'A',
    '0',
    'B',
    'F'
  ];
  // Input variables
  bool waitingForKeyPress = false;
  bool paused = true;
  var keyStates = List.generate(16, (i) => KEY_NOT_PRESSED_VAL);
  // VM Variables
  Uint8List memory = new Uint8List(MEMORY_BYTE_SIZE);
  Uint16List stack = new Uint16List(STACK_SIZE);
  Uint8List registers = new Uint8List(REGISTER_NUM);
  int soundTimer = 0;
  int delayTimer = 0;
  int pc = PROGRAM_START; // Program counter
  int sp = 0; // Stack pointer
  int I = 0; // Index register
  int opcode = 0; // Current opcode
  Random rng = new Random();
  var fontSet = [
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0x90, 0xE0, 0xE0, 0xE0, 0x90, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
  ];
  // Callbacks for UI/Sound
  Function playChip8Sound;
  Function stopChip8Sound;
  // Compat flags
  bool shiftQuirk;
  bool loadQuirk;

  Core(width, height, shiftQuirk, loadQuirk) {
    this.width = width;
    this.height = height;
    this.shiftQuirk = shiftQuirk;
    this.loadQuirk = loadQuirk;
    buffer = Uint8List(width * height);
    for (var i = 0; i < fontSet.length; i++) {
      memory[i] = fontSet[i];
    }
  }

  void resetState() {
    memory.fillRange(PROGRAM_START, memory.length, 0);
    stack.fillRange(0, stack.length, 0);
    registers.fillRange(0, registers.length, 0);
    soundTimer = 0;
    delayTimer = 0;
    pc = 0x200;
    sp = 0;
    I = 0;
    opcode = 0;
  }

  void loadProgram(ByteData data) {
    resetState();
    debugPrint("Begin loading program.");
    for (int i = 0; i < data.lengthInBytes; i++) {
      memory[PROGRAM_START + i] = data.getUint8(i);
      /**
      if (i % 2 == 1) {
        debugPrint(
            "${(PROGRAM_START + (i - 1)).toRadixString(16)}: 0x${(memory[PROGRAM_START + i - 1] << 8 | memory[PROGRAM_START + i]).toRadixString(16)}");
      }*/
    }
    debugPrint("Done loading.");
  }

  void setPause(bool paused) {
    this.paused = paused;
    debugPrint("Game was ${paused ? "Paused" : "Resumed"}");
  }

  bool isPaused() {
    return paused;
  }

  void keyDownEvent(String key) {
    int pressed = keys.indexOf(key);
    if (waitingForKeyPress) {
      waitingForKeyPress = false;
      registers[getX()] = pressed;
    }

    keyStates[pressed] = KEY_PRESSED_VAL;
  }

  void keyUpEvent(String key) {
    int pressed = keys.indexOf(key);
    keyStates[pressed] = KEY_NOT_PRESSED_VAL;
  }

  void emulateCycle() {
    if (waitingForKeyPress || paused) {
      return;
    }

    fetchOpcode();
    debugPrint(
        "Executing instruction 0x${opcode.toRadixString(16)} at pc: 0x${(pc - 2).toRadixString(16)}");

    runOpCode();
  }

  void procTimers() {
    if (delayTimer > 0) {
      delayTimer--;
    }

    if (soundTimer > 0) {
      soundTimer--;
      if (soundTimer > 0) {
        playChip8Sound();
      } else {
        stopChip8Sound();
      }
    }
  }

  int getBufferIndex(int x, int y) {
    return (x % width) + ((y % height) * width);
  }

  void fetchOpcode() {
    opcode = memory[pc++] << 8 | memory[pc++];
  }

  void handleBadOpCode() {
    debugPrint("Unknown Opcode: 0x${opcode.toRadixString(16)}");
    throw Exception("Unknown Opcode: 0x${opcode.toRadixString(16)}");
  }

  int getAddr() {
    return opcode & 0x0FFF;
  }

  int getN() {
    return opcode & 0x000F;
  }

  int getX() {
    return (opcode & 0x0F00) >> 8;
  }

  int getY() {
    return (opcode & 0x00F0) >> 4;
  }

  int getKK() {
    return opcode & 0x0FF;
  }

  void runOpCode() {
    switch (opcode & 0xF000) {
      case 0x0000:
        handleZeroOpCodes();
        break;
      case 0x1000:
        pc = getAddr();
        break;
      case 0x2000:
        stack[sp] = pc - 2;
        sp++;
        pc = getAddr();
        break;
      case 0x3000:
        if (registers[getX()] == getKK()) {
          pc += 2;
        }
        break;
      case 0x4000:
        if (registers[getX()] != getKK()) {
          pc += 2;
        }
        break;
      case 0x5000:
        if (registers[getX()] == registers[getY()]) {
          pc += 2;
        }
        break;
      case 0x6000:
        registers[getX()] = getKK();
        break;
      case 0x7000:
        registers[getX()] = (registers[getX()] + getKK()) & 0xFF;
        break;
      case 0x8000:
        handleEightOpCodes();
        break;
      case 0x9000:
        if (registers[getX()] != registers[getY()]) {
          pc += 2;
        }
        break;
      case 0xA000:
        I = getAddr();
        break;
      case 0xB000:
        pc = getAddr() + registers[0];
        break;
      case 0xC000:
        registers[getX()] = rng.nextInt(0xFF) & getKK();
        break;
      case 0xD000:
        draw();
        break;
      case 0xE000:
        handleEOpCodes();
        break;
      case 0xF000:
        handleFOpCodes();
        break;
      default:
        handleBadOpCode();
    }
  }

  void draw() {
    var x = registers[getX()];
    var y = registers[getY()];
    registers[0xF] = 0;
    for (int i = 0; i < getN(); i++) {
      var pixels = memory[I + i];
      for (int j = 0; j < 8; j++) {
        if ((pixels & (0x80 >> j)) != 0) {
          int idx = getBufferIndex(x + j, y + i);
          int val = buffer[idx];
          if (val == 1) {
            registers[0xF] = 1;
            buffer[idx] = 0;
          } else {
            buffer[idx] = 1;
          }
        }
      }
    }
  }

  void handleZeroOpCodes() {
    switch (getAddr()) {
      case 0x0E0:
        for (int i = 0; i < buffer.length; i++) {
          buffer[i] = 0;
        }
        break;
      case 0x0EE:
        sp--;
        pc = stack[sp] + 2;
        debugPrint("Return to address ${pc.toRadixString(16)}");
        break;
      default:
        handleBadOpCode();
        break;
    }
  }

  void handleEightOpCodes() {
    switch (getN()) {
      case 0x0:
        registers[getX()] = registers[getY()];
        break;
      case 0x1:
        registers[getX()] = (registers[getX()] | registers[getY()]);
        break;
      case 0x2:
        registers[getX()] = registers[getX()] & registers[getY()];
        break;
      case 0x3:
        registers[getX()] = (registers[getX()] ^ registers[getY()]) & 0xFF;
        break;
      case 0x4:
        var x = getX();
        int add = registers[x] + registers[getY()];
        if (add > 0xFF) {
          registers[0xF] = 1;
        } else {
          registers[0xF] = 0;
        }
        registers[x] = add & 0xFF;
        break;
      case 0x5:
        var x = getX();
        var vX = registers[x];
        var vY = registers[getY()];
        registers[0xF] = vX > vY ? 1 : 0;
        registers[x] = (vX - vY) & 0xFF;
        break;
      case 0x6:
        var x = getX();
        var vX = registers[x];
        if (!shiftQuirk) {
          var y = getY();
          var vY = registers[y];
          registers[0xF] = vX & 1;
          registers[y] = vY >> 1;
          registers[x] = registers[y];
        } else {
          registers[0xF] = vX & 1;
          registers[x] = vX >> 1;
        }
        break;
      case 0x7:
        var x = getX();
        var vX = registers[x];
        var vY = registers[getY()];
        registers[0xF] = vY > vX ? 1 : 0;
        registers[x] = (vY - vX) & 0xFF;
        break;
      case 0xE:
        var x = getX();
        var vX = registers[x];
        registers[0xF] = vX & 0x80 != 0 ? 1 : 0;
        registers[x] = (vX << 1) & 0xFF;
        break;
      default:
        handleBadOpCode();
        break;
    }
  }

  void handleEOpCodes() {
    switch (opcode & 0xFF) {
      case 0x9E:
        var vX = registers[getX()];
        if (vX < 16 && keyStates[vX] == KEY_PRESSED_VAL) {
          pc += 2;
        }
        break;
      case 0xA1:
        var vX = registers[getX()];
        if (vX > 16 || keyStates[vX] != KEY_PRESSED_VAL) {
          pc += 2;
        }
        break;
      default:
        handleBadOpCode();
        break;
    }
  }

  void handleFOpCodes() {
    switch (opcode & 0xFF) {
      case 0x07:
        registers[getX()] = delayTimer;
        break;
      case 0x0A:
        waitingForKeyPress = true;
        break;
      case 0x15:
        delayTimer = registers[getX()];
        break;
      case 0x18:
        soundTimer = registers[getX()];
        break;
      case 0x1E:
        I = (registers[getX()] + I) & 0xFFFF;
        break;
      case 0x29:
        I = registers[getX()] * 5;
        break;
      case 0x33:
        int vX = registers[getX()];
        memory[I] = vX ~/ 100;
        memory[I + 1] = (vX ~/ 10) % 10;
        memory[I + 2] = vX % 10;
        break;
      case 0x55:
        int x = getX();
        for (int i = 0; i <= x; i++) {
          memory[I + i] = registers[i];
        }
        if (!loadQuirk) {
          I += x + 1;
        }
        break;
      case 0x65:
        int x = getX();
        for (int i = 0; i <= x; i++) {
          registers[i] = memory[I + i];
        }
        if (!loadQuirk) {
          I += x + 1;
        }
        break;
      default:
        handleBadOpCode();
        break;
    }
  }
}
