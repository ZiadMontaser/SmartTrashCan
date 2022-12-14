import 'dart:async';
import 'dart:ffi';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          scaffoldBackgroundColor: Color.fromARGB(255, 40, 152, 200),
          textTheme: TextTheme(
            headline2: TextStyle(),
          ).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          )),
      home: const MyHomePage(title: 'Smart Trash Can'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  bool isOpened = true;
  num motionSensor = 30.0;
  num levelSensor = 20.0;
  num depth = 40;

  String number = "";

  StreamSubscription<DatabaseEvent>? reference;
  final TextEditingController numberController = TextEditingController();
  FocusNode numberFocus = FocusNode();
  bool enableNumberEdit = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final prefs = await SharedPreferences.getInstance();
      number = numberController.text = prefs.getString('number') ?? "+20";

      // numberController = TextEditingController();
      Setuplistenrs();
    });
  }

  void ChangeNumber(String newNumber) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('number', newNumber);
    number = newNumber;

    print("New number is ${newNumber}");

    Setuplistenrs();
  }

  void Setuplistenrs() {
    if (reference != null) {
      reference?.cancel();
      reference = null;
    }

    if (number.isEmpty) return;
    print("Setup listeners");
    // reference =
    //     FirebaseDatabase.instance.ref("cans/${number}").onValue.listen((event) {
    //   print(event.snapshot.value);
    //   if (event.snapshot.value == null) return;

    //   print(event.snapshot.value);
    //   Map<Object?, dynamic> values =
    //       event.snapshot.value as Map<Object?, Object?>;
    //   Map<Object?, dynamic> states = values['state'] as Map<Object?, Object?>;
    //   List<dynamic> keysList = states.keys.toList();
    //   keysList.sort();
    //   var lastKey = keysList.first;
    //   print(lastKey);
    //   Map<Object?, dynamic> lastInfo = states[lastKey] as Map<Object?, dynamic>;
    //   print(lastInfo);
    //   isOpened = lastInfo['isOpened'];
    //   motionSensor = lastInfo['motion_distance'];
    //   levelSensor = lastInfo['level_distance'];
    //   depth = lastInfo['depth'];

    //   setState(() {});
    // });

    reference = FirebaseDatabase.instance
        .ref("cans/${number}/state")
        .limitToLast(1)
        .onValue
        .listen((event) {
      print(event.snapshot.value);
      if (event.snapshot.value == null) return;

      print(event.snapshot.value);

      Map<Object?, dynamic> values =
          event.snapshot.value as Map<Object?, Object?>;

      Map<Object?, dynamic> lastInfo =
          values.values.toList()[0] as Map<Object?, dynamic>;
      print(lastInfo);
      isOpened = lastInfo['isOpened'] ?? false;
      motionSensor = lastInfo['motion_distance'] ?? 256;
      levelSensor = lastInfo['level_distance'] ?? 256;
      depth = lastInfo['depth'] ?? 100;

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
            elevation: 3,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
              Radius.circular(20),
            )),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        print(hasFocus);
                        !hasFocus ? numberController.text = number : null;
                      },
                      child: TextField(
                        controller: numberController,
                        focusNode: numberFocus,
                        // initialValue: number,
                        decoration: InputDecoration(
                          hintText: "Number",
                          alignLabelWithHint: false,
                        ),
                        enabled: enableNumberEdit,
                        onEditingComplete: () {
                          enableNumberEdit = false;
                          ChangeNumber(numberController.text);
                          numberFocus.unfocus();
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        enableNumberEdit = true;
                        numberFocus.requestFocus();
                      });
                    },
                    icon: Icon(Icons.edit),
                  )
                ],
              ),
            ),
          ),
          Text(
            "${CalculatePercentage()} %",
            style: theme.textTheme.headline2,
          ),
          Text(
            isOpened ? "Lid is opened" : "Lid is closed",
            style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    isOpened ? Color.fromARGB(255, 110, 230, 114) : Colors.red),
          ),
          Stack(
            children: [
              Image.asset(
                "images/back.png",
                width: 250,
              ),
              // var theme = .of(context);
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: LayoutBuilder(
                    builder: (p0, p1) => Container(
                      child: Image.asset(
                        "images/trash.png",
                        width: 250,
                        height: (p1.maxHeight * 0.635) *
                            CalculatePercentage() /
                            100,
                        alignment: FractionalOffset.bottomCenter,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              Image.asset(
                "images/can_empty.png",
                // scale: 0.1,
                width: 250,
              )
            ],
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              children: [
                Text("Debug: ", style: theme.textTheme.bodySmall),
                Text("Motion sensor: ${motionSensor}",
                    style: theme.textTheme.bodySmall),
                Text("Level sensor: ${levelSensor}",
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int CalculatePercentage() => ((depth - levelSensor) / depth * 100).round();
}
