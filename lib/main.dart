import 'dart:convert';

import 'package:flame/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wafer/core.dart';
import 'package:flutter/gestures.dart';

import 'chip8game.dart';

void main() {
  runApp(MaterialApp(
    title: 'Wafer',
    home: GameListPage(),
  ));
}

Future<Chip8Game> createGame(GameInfo gameInfo) async {
  Util util = Util();
  await util.fullScreen();
  await util.setOrientation(DeviceOrientation.portraitUp);

  Core core = new Core(Core.DEFAULT_WIDTH, Core.DEFAULT_HEIGHT,
      gameInfo.shiftQuirk, gameInfo.loadQuirk);
  Chip8Game game = new Chip8Game(
      foreground: Colors.amber,
      background: Colors.blueAccent,
      highlight: Colors.orange,
      core: core);

  runApp(game.widget);

  TapGestureRecognizer tapper = TapGestureRecognizer();
  tapper.onTapDown = game.onTapDown;
  tapper.onTapUp = game.onTapUp;
  util.addGestureRecognizer(tapper);

  await game.init();
  await rootBundle.load('assets/${gameInfo.name}').then((data) {
    debugPrint("Loaded game of size: ${data.lengthInBytes}");
    game.loadGame(data);
  });
  core.setPause(false);
  return game;
}

class GameListPage extends StatefulWidget {
  @override
  _GameListPageState createState() => _GameListPageState();
}

class _GameListPageState extends State<GameListPage> {
  GameFiles _data = GameFiles(games: List<GameInfo>());

  void loadGamesList() async {
    _data = await loadGameList('games.json');
    debugPrint('Loaded the following game names:');
    _data.games.forEach((f) => debugPrint(f.toString()));
    setState(() {});
  }

  Future<GameFiles> loadGameList(String filename) async {
    return await rootBundle.loadString('assets/$filename').then((data) {
      var parsed = json.decoder.convert(data);
      return GameFiles.fromJson(parsed);
    });
  }

  @override
  void initState() {
    loadGamesList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Chip8 Games';

    return MaterialApp(
      title: title,
      home: Scaffold(
        appBar: AppBar(
          title: Text(title, style: TextStyle(fontFamily: 'PressStart2P')),
        ),
        body: new ListView.separated(
          itemCount: _data.games.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Center(child: Text(_data.games[index].name, style: TextStyle(fontFamily: 'PressStart2P')))),
              onTap: () async => await createGame(_data.games[index]),
            );
          },
          separatorBuilder: (context, index) => Divider(
                color: Colors.grey,
              ),
        ),
      ),
    );
  }
}

class GameFiles {
  List<GameInfo> games;

  GameFiles({this.games});

  GameFiles.fromJson(dynamic data) {
    dynamic gameList = data['games'];
    games = List<GameInfo>();
    gameList.forEach((g) {
      String name = g['name'];
      bool shiftQuirk = g['shiftQuirk'] ?? false;
      bool loadQuirk = g['loadQuirk'] ?? false;
      games.add(
          GameInfo(name: name, shiftQuirk: shiftQuirk, loadQuirk: loadQuirk));
    });
  }
}

class GameInfo {
  String name;
  bool shiftQuirk;
  bool loadQuirk;

  GameInfo({this.name, this.shiftQuirk, this.loadQuirk});

  String toString() {
    return "game: $name";
  }
}
