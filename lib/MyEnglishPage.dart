import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'EngWords.dart';
import 'RusWords.dart';
import 'EngExpressions.dart';
import 'RusExpressions.dart';
import 'EngDialogs.dart';
import 'RusDialogs.dart';

enum TtsState { playing, stopped, paused, continued }

class MyEnglishPage extends StatefulWidget {
  MyEnglishPage() : super();

  @override
  _MyEnglishPage createState() => _MyEnglishPage();
}

class _MyEnglishPage extends State<MyEnglishPage> {
  bool showMic = false;
  bool showDebugInfo = false;
  int mode = 0, curPos = 0, maxPos = 0;
  String curEngText = '', curRusText = '';

  final SpeechToText speech = SpeechToText();
  String lastSttWords = '';
  String lastSttError = '';

  FlutterTts flutterTts;
  dynamic languages;
  String language;
  double volume = 1;
  double pitch = 1.2;
  double ttsRate = 0.5;

  TtsState ttsState = TtsState.stopped;
  get isPlaying => ttsState == TtsState.playing;
  get isStopped => ttsState == TtsState.stopped;
  get isPaused => ttsState == TtsState.paused;
  get isContinued => ttsState == TtsState.continued;

  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  List<EnglishTask> engTaskKinds = EnglishTask.getList();
  List<DropdownMenuItem> _dropDownMenuEngTaskKindItems;
  EnglishTask _selectedEngTaskKind;

  List<String> myEngWords = EngWords.getList();
  List<String> myRusWords = RusWords.getList();
  List<String> myEngExpressions = EngExpressions.getList();
  List<String> myRusExpressions = RusExpressions.getList();
  List<String> myEngDialogs = EngDialogs.getList();
  List<String> myRusDialogs = RusDialogs.getList();

  @override
  initState() {
    super.initState();
    initSpeach();
    _dropDownMenuEngTaskKindItems = buildDropDownEngTaskKindItems();
    _selectedEngTaskKind = engTaskKinds[1];
  }

  initSpeach() async {
    flutterTts = FlutterTts();
    await _setSpeakParameters();
    await initSTT();
  }

  Future _setSpeakParameters() async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(ttsRate);
    await flutterTts.setPitch(pitch);
    await flutterTts.setLanguage('en-US'); // ru-RU uk-UA en-US
  }

  Future<void> _speak(String _text) async {
    if (_text != null && _text.isNotEmpty) {
      await flutterTts.awaitSpeakCompletion(true);
      await flutterTts.speak(_text);
    }
  }

  readAllSentencesList(List<String> allSentences) async {
    for (int i=0; i<allSentences.length; i++){
      await _speak(allSentences[i]);
    }
  }

  initSTT() async {
    var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: false,
        finalTimeout: Duration(milliseconds: 0));

    speech.errorListener = errorListener;
    speech.statusListener = statusListener;

    print('initSpeechState hasSpeech $hasSpeech');

    if (hasSpeech) {
      //var _localeNames = await speech.locales();
      //_localeNames.forEach((element) => print(element.localeId));
      var systemLocale = await speech.systemLocale();
      var _currentLocaleId = systemLocale.localeId;
      print('initSpeechState _currentLocaleId $_currentLocaleId');
    }

    if (!hasSpeech) {
      print('STT not mounted.');
      return;
    }
  }

  void errorListener(SpeechRecognitionError error) {
    print("Received Eng error status: $error, listening: ${speech.isListening}");
    /*
    setState(() {
      showMic = false;
    });
    displaySttDialog();

     */
  }

  void statusListener(String status) {
    print("Received listener status: $status, listening: ${speech.isListening}");
    if (status == 'notListening') {
      setState(() {
        showMic = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (mode == 0) {
      return startEnglishMenu(context);
    } else {
      return englishTaskPage(context);
    }
  }

  void displaySttDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => new CupertinoAlertDialog(
        title: Text("Я тебя не понял...", textScaleFactor: 1.3,),
        content: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("Повторим?", textScaleFactor: 1.6),
        ),
        actions: [
          FlatButton(
              child: Text('Да'),
              onPressed: () {
                startListening();
                Navigator.pop(context, true);
              }),
          FlatButton(
              child: Text('Нет'),
              onPressed: () {
                Navigator.pop(context, true);
              }),
        ],
      ),
    );
  }

  Widget englishTaskPage(BuildContext context) {
    return Scaffold(
        //appBar: AppBar(title: Text('Английский')),
        body: Column(
          children: <Widget>[
            Expanded(
                flex: 3,
                child: MediaQuery.of(context).size.height > 400
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ewTaskList(),
                      )
                    : ListView(
                        children: ewTaskList(),
                      )
            ),
            Expanded( //BlinkingIcons(showMic: showMic),
              child: showMic?
                blinkMicrophoneW()
                : TextButton(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fingerprint, size: 48,),
                        Text('START', textScaleFactor: 1.2,),
                        Text('SPEAKING', textScaleFactor: 1.2,),
                      ],
                    ),
                    onPressed: (){ startListening(); })
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    child: IconButton(
                      icon: Icon(Icons.skip_previous),
                      onPressed: () {
                        setState(() {
                          curPos--;
                        });
                        mainEnglishLoop();
                      },
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    child: IconButton(
                      icon: Icon(Icons.repeat),
                      onPressed: () {
                        mainEnglishLoop();
                      },
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    child: IconButton(
                      icon: Icon(Icons.skip_next),
                      onPressed: () {
                        setState(() {
                          curPos++;
                        });
                        mainEnglishLoop();
                      },
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    child: IconButton(
                        icon: Icon(Icons.settings),
                        onPressed: (){
                          setState(() {
                            mode = 0;
                          });
                        }
                    ),
                  ),
                ],
              ),
            )
          ],
        ));
  }

  Widget blinkMicrophoneW() {
    return InkWell(
        splashColor: Colors.white,
        onTap: () {
          print('run startListening');
          startListening();
        }, // handle your onTap here
        child: Center(child: Image.asset('assets/animMicroph.gif', width: 40, height: 40))
    );
  }

  List<Widget> ewTaskList() {
    return [
      Text(
        curEngText,
        textScaleFactor: 2,
        textAlign: TextAlign.center,
      ),
      SizedBox(
        height: 20,
      ),
      Text(
        curRusText,
        textScaleFactor: 1.6,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.green[900]),
      ),
      SizedBox(
        height: 20,
      ),
      Text('Слышу:\n$lastSttWords',
          textScaleFactor: 1.4, textAlign: TextAlign.center),
    ];
  }

  Widget startEnglishMenu(BuildContext context) {
    return Scaffold(
        //appBar: AppBar(title: Text('Английский')),
        body: Column(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Когда будешь готов - нажми',
                    textScaleFactor: 2,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  FlatButton(
                    color: Colors.blue,
                    textColor: Colors.white,
                    disabledColor: Colors.grey,
                    disabledTextColor: Colors.black,
                    padding: EdgeInsets.only(
                        left: 40, right: 40, top: 20, bottom: 20),
                    splashColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'СТАРТ',
                      textScaleFactor: 2,
                    ),
                    onPressed: () {
                      startEngTraining();
                      setState(() {
                        mode = 1;
                      });
                    },
                  )
                ],
              )),
            ),
            Expanded(
              flex: 1,
              child: Container(
                  color: Colors.lightBlue[200],
                  //MediaQuery.of(context).size.height > 400
                  child: ListView(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Настройки тренера:',
                          textScaleFactor: 1.3,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text('Режим: ', textScaleFactor: 1.3),
                          DropdownButton(
                              value: _selectedEngTaskKind,
                              items: _dropDownMenuEngTaskKindItems,
                              onChanged: (newVal) {
                                setState(() {
                                  _selectedEngTaskKind = newVal;
                                });
                              }),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Text('  Скорость:'),
                          Slider(
                            value: ttsRate,
                            min: 0,
                            max: 1,
                            onChanged: (newRate) {
                              setState(() {
                                ttsRate = newRate;
                              });
                              flutterTts.setSpeechRate(newRate);
                            },
                          ),
                        ],
                      )
                    ],
                  )),
            )
          ],
        ));
  }

  List<DropdownMenuItem<EnglishTask>> buildDropDownEngTaskKindItems() {
    List<DropdownMenuItem<EnglishTask>> items = List();
    for (EnglishTask tt in engTaskKinds) {
      items.add(DropdownMenuItem(value: tt, child: Text(tt.name)));
    }
    return items;
  }

  void startEngTraining() {
    if (_selectedEngTaskKind.name == 'Слова') {
      maxPos = myEngWords.length;
    } else if (_selectedEngTaskKind.name == 'Популярные выражения') {
      maxPos = myEngExpressions.length;
    } else if (_selectedEngTaskKind.name == 'Диалоги') {
      maxPos = myEngDialogs.length;
    }
    var rng = new Random();
    curPos = rng.nextInt(maxPos);
    mainEnglishLoop();
  }

  void mainEnglishLoop() async {
    await speech.stop();
    setState(() {
      if (_selectedEngTaskKind.name == 'Слова') {
        curEngText = myEngWords[curPos];
        curRusText = myRusWords[curPos];
      } else if (_selectedEngTaskKind.name == 'Популярные выражения') {
        curEngText = myEngExpressions[curPos];
        curRusText = myRusExpressions[curPos];
      } else if (_selectedEngTaskKind.name == 'Диалоги') {
        curEngText = myEngDialogs[curPos];
        curRusText = myRusDialogs[curPos];
      }
    });
    await _speak(curEngText);
    //await delay(1);
    startListening();
    //speech.cancel();
  }

  void startListening() {
    speech.listen(
        onResult: resultListener,
        listenFor: Duration(seconds: 5),
        pauseFor: Duration(seconds: 5),
        partialResults: false,
        localeId: 'en_US', // en_US uk_UA ru_RU
        onSoundLevelChange: soundLevelListener,
        cancelOnError: false,
        onDevice: false,
        listenMode: ListenMode.confirmation
    );
    setState(() {
      showMic = true;
    });
    lastSttError = "";
  }

  void soundLevelListener(double level) {
    //print('level $level');
    //minSoundLevel = min(minSoundLevel, level);
    //maxSoundLevel = max(maxSoundLevel, level);
    // print("sound level $level: $minSoundLevel - $maxSoundLevel ");
    //setState(() {
      //this.level = level;
    //});
  }

  delay(int sec) async {
    await Future.delayed(Duration(seconds: sec));
  }

  void resultListener(SpeechRecognitionResult result) async {
    print('got result for listening $result');

    if (result.finalResult) {
      await speech.stop();
      print('stop speech listening');

      String recognizedWords = result.recognizedWords.toString();

      List<String> realAlternatives = [];
      for(int i=1; i<result.alternates.length; i++){
        final elem = result.alternates[i];
        if (elem.confidence < 0.2) {
          continue;
        }
        realAlternatives.add(elem.recognizedWords.toString());
      }

      setState(() {
        lastSttWords = recognizedWords;
        showMic = false;
      });

      if (checkForCorrectAnswer(recognizedWords, realAlternatives)) {
        curPos++;
        if (curPos == maxPos) {
          curPos = 0;
        }
        await _speak('ok! fine!');
        await delay(1);
        setState(() {
          lastSttWords = '';
        });
        mainEnglishLoop();
      } else {
        await _speak("That's wrong...");
        await _speak(curEngText);
        startListening();
      }
    } else {
      print('got tmp result $result');
    }
  }

  bool checkForCorrectAnswer(String recognizedWords, List<String> realAlternatives) {
    String _userText = removeAllGarbage(recognizedWords);
    String _expText = removeAllGarbage(curEngText);
    if (_userText == _expText) {
      return true;
    }
    if (showDebugInfo) {
      showAlertPage(_userText + ' / ' + _expText + ' $curPos');
    }
    for (int i=0; i < realAlternatives.length; i++){
      String _userText = removeAllGarbage(realAlternatives[i]);
      if (_userText == _expText) {
        lastSttWords = realAlternatives[i];
        return true;
      }
    }
    return false;
  }

  String removeAllGarbage(String _text) {
    return _text
        .toUpperCase()
        .replaceAll("OKAY", "OK")
        .replaceAll("FAVOURITE", "FAVORITE")
        .replaceAll("'RE", " ARE")
        .replaceAll("'S", " IS")
        .replaceAll("'M", " AM")
        .replaceAll("'LL", " WILL")
        .replaceAll("ALL RIGHT", "ALLRIGHT")
        .replaceAll("ALRIGHT", "ALLRIGHT")
        .replaceAll("APARTMENT", "APT")
        .replaceAll("BEECH", "BEACH")
        .replaceAll("COLOUR", "COLOR")
        .replaceAll("GREY", "GRAY")
        .replaceAll("KILOGRAM", "KG")
        .replaceAll("KILOMETER", "KM")
        .replaceAll("P.M.", "PM")
        .replaceAll("A.M.", "AM")
        .replaceAll(" AN ", " A ")
        .replaceAll(" THE ", " A ")
        .replaceAll(
            new RegExp(
                '(:00|PERCENT|PERCENTS|DOLLAR|DOLLARS|O\'CLOCK|O\'CLOCKS|[.,%-();№!@~#\$\'^%*&:?/\\()_+*{}])'),
            ' ')
        .replaceAll(new RegExp('[ \t]{2,}'), ' ')
        .trim();
  }

  showAlertPage(String msg) {
    showAboutDialog(
      context: context,
      applicationName: 'Alert',
      children: <Widget>[
        Padding(
            padding: EdgeInsets.only(top: 15), child: Center(child: Text(msg)))
      ],
    );
  }
}

class EnglishTask {
  String name;

  EnglishTask(this.name);

  static getList() {
    List<EnglishTask> lt = [];
    lt.add(EnglishTask('Слова'));
    lt.add(EnglishTask('Популярные выражения'));
    lt.add(EnglishTask('Диалоги'));
    return lt;
  }
}

/*

class BlinkingIcons extends StatelessWidget {
  const BlinkingIcons({
    Key key,
    @required this.showMic,
  }) : super(key: key);

  final bool showMic;

  @override
  Widget build(BuildContext context) {
    return BlinkWidget(
      children: <Widget>[
        Icon(
          Icons.mic,
          size: 40,
          color: showMic ? Colors.green : Colors.transparent,
        ),
        Icon(Icons.mic, size: 40, color: Colors.transparent),
      ],
    );
  }
}

class BlinkWidget extends StatefulWidget {
  final List<Widget> children;
  final int interval;

  BlinkWidget({@required this.children, this.interval = 500, Key key})
      : super(key: key);

  @override
  _BlinkWidgetState createState() => _BlinkWidgetState();
}

class _BlinkWidgetState extends State<BlinkWidget>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  int _currentWidget = 0;

  initState() {
    super.initState();

    _controller = new AnimationController(
        duration: Duration(milliseconds: widget.interval)); //, vsync: this

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          if (++_currentWidget == widget.children.length) {
            _currentWidget = 0;
          }
        });

        _controller.forward(from: 0.0);
      }
    });

    _controller.forward();
  }

  dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: widget.children[_currentWidget],
    );
  }
}
*/