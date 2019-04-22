import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wafer/core.dart';
import 'package:convert/convert.dart';

void loadProgram(List<String> instructions, Core core) {
  ByteData data = ByteData(instructions.length * 2);
  instructions.map((i) => hex.decode(i))
      .expand((i) => i)
      .toList()
      .asMap()
      .forEach((i, v) {
        data.setUint8(i, v);
      });
  core.loadProgram(data);
  core.setPause(false);
}

// Test manually from command line if getting Not found: `dart:ui` errors:
// flutter test test/core_test.dart
void main() {
  Core core = Core(Core.DEFAULT_WIDTH, Core.DEFAULT_HEIGHT, false, false);

  // UTILITY TESTS
  test('Get opcode', () {
    loadProgram(["8123"], core);
    expect(Core.PROGRAM_START, core.pc);
    core.fetchOpcode();
    expect(0x8123, core.opcode);
    expect(Core.PROGRAM_START + 2, core.pc);
  });

  test('Test getX', () {
    loadProgram(["1234"], core);
    core.fetchOpcode();
    expect(0x2, core.getX());
  });

  test('Test getY', () {
    loadProgram(["1234"], core);
    core.fetchOpcode();
    expect(0x3, core.getY());
  });

  test('Test getN', () {
    loadProgram(["1234"], core);
    core.fetchOpcode();
    expect(0x4, core.getN());
  });

  test('Test getKK', () {
    loadProgram(["1234"], core);
    core.fetchOpcode();
    expect(0x34, core.getKK());
  });

  test('Test getAddr', () {
    loadProgram(["1234"], core);
    core.fetchOpcode();
    expect(0x234, core.getAddr());
  });

  test('Program start', () {
    expect(512, Core.PROGRAM_START);
  });

  // Instruction tests

  test('Test SE Vx, byte success', () {
    loadProgram(["3F05"], core);
    core.registers[0xF] = 5;
    expect(core.pc, Core.PROGRAM_START);
    core.emulateCycle();
    expect(core.pc, Core.PROGRAM_START + 4);
  });

  test('Test SE Vx, byte failure', () {
    loadProgram(["3F01"], core);
    expect(0, core.registers[0xF]);
    expect(core.pc, Core.PROGRAM_START);
    core.emulateCycle();
    expect(core.pc, Core.PROGRAM_START + 2);
  });

  test('Test ADD Vx, byte', () {
    loadProgram(["71F3"], core);
    expect(0x00, core.registers[1]);
    core.emulateCycle();
    expect(0xF3, core.registers[1]);
  });

  test('Test LD Vx, Vy', () {
    loadProgram(["8120"], core);
    core.registers[1] = 11;
    core.registers[2] = 44;
    core.emulateCycle();
    expect(44, core.registers[1]);
    expect(44, core.registers[2]);
  });

  test('Test OR Vx, Vy', () {
    loadProgram(["8121"], core);
    core.registers[1] = 11;
    core.registers[2] = 12;
    core.emulateCycle();
    expect(15, core.registers[1]);
    expect(12, core.registers[2]);
  });

  test('Test AND Vx, Vy', () {
    loadProgram(["8122"], core);
    core.registers[1] = 11;
    core.registers[2] = 12;
    core.emulateCycle();
    expect(8, core.registers[1]);
    expect(12, core.registers[2]);
  });

  test('Test XOR Vx, Vy', () {
    loadProgram(["8123"], core);
    core.registers[1] = 11;
    core.registers[2] = 12;
    core.emulateCycle();
    expect(7, core.registers[1]);
    expect(12, core.registers[2]);
  });

  test('Test LD B, Vx', () {
    loadProgram(["F133"], core);
    core.I = 0x300;
    core.registers[1] = 128;
    core.emulateCycle();
    expect(1, core.memory[core.I]);
    expect(2, core.memory[core.I+1]);
    expect(8, core.memory[core.I+2]);
  });

  test('Test SUBN Vx, Vy greater', () {
    loadProgram(["8017"], core); // V[x] = V[y] - V[x]
    core.registers[0] = 1; // v[x] = 1
    core.registers[1] = 0; // V[y] = 0
    core.emulateCycle();
    expect(0, core.registers[0xF]);
    expect(255, core.registers[0]);
  });

  test('Test SUBN Vx, Vy lesser', () {
    loadProgram(["8017"], core); // V[x] = V[y] - V[x]
    core.registers[0] = 0; // v[x] = 0
    core.registers[1] = 1; // V[y] = 1
    core.emulateCycle();
    expect(1, core.registers[0xF]);
    expect(1, core.registers[0]);
  });
}