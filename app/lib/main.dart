import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'textstyles.dart';
import 'ble_controls.dart';

void main() {
  runApp(const MyApp());
}

final List<String> weekDays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clock Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
      ),
      darkTheme: ThemeData.dark(),
      home: const MyHomePage(title: 'CLOCK CONTROLLER'),
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
  int _hours = 0;
  int _minutes = 0;
  int _seconds = 0;
  int _day = 0;
  bool _skipButtonsEnabled = false;

  String _timeToString() {
    String result;
    result = _hours.toString() + ":" + _minutes.toString() + ":" + _seconds.toString() + ":" + weekDays[_day];
    return result;
  }

//! TODO: Refactor increments and decrements to only use one function
//        with positive/negative "amount" value ( eg. changeHours(amount) ).

  void _incrementHours({int count = 1}) {
    setState(() {
      _hours += count;
      _hours = _hours % 24;
    });
  }

  void _decrementHours({int count = 1}) {
    setState(() {
      _hours -= count;
      _hours = _hours % 24;
    });
  }

  void _incrementMinutes({int count = 1}) {
    setState(() {
      _minutes += count;
      if(_minutes >= 60) _incrementHours();
      _minutes %= 60;
    });
  }

  void _decrementMinutes({int count = 1}) {
    setState(() {
      _minutes -= count;
      if(_minutes < 0) _decrementHours();
      _minutes %= 60;
    });
  }

  void _incrementSeconds({int count = 1}) {
    setState(() {
      _seconds += count;
      if(_seconds >= 60) _incrementMinutes();
      _seconds %= 60;
    });
  }

  void _decrementSeconds({int count = 1}) {
    setState(() {
      _seconds -= count;
      if(_seconds < 0) _decrementMinutes();
      _seconds %= 60;
    });
  }

  void _incrementDay() {
    setState(() {
      _day += 1;
      _day %= 7;
    });
  }

  void _decrementDay() {
    setState(() {
      _day -= 1;
      _day %= 7;
    });
  }

  void _syncDataWithPhone() {
    setState(() {
      DateTime time = DateTime.now();
      _day = time.weekday - 1; // weekday values start at 1, end at 7.
      _hours = time.hour;
      _minutes = time.minute;
      _seconds = time.second;
    });
  }

  void _connectClock() async {
    try {
      bool success = await connectToClock();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connected to clock!"))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not find device."))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed: ${e.toString()}"))
      );
    }
  }

  void _syncDataWithClock() async {
    try {
      Map<String, int> timeData = await getTimeFromClock();
      setState(() {
        _hours = timeData['hours']!;
        _minutes = timeData['minutes']!;
        _seconds = timeData['seconds']!;
        _day = timeData['day']!;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to sync: ${e.toString()}"))
      );
    }
  }

  void _sendDataToClock() async {
    try {
      await sendTimeToClock(_hours, _minutes, _seconds, _day);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Time sent to clock!"))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send: ${e.toString().substring(11)}"))
      );
    }
  }

  void _toggleSkipButtons() {
    setState(() {
      _skipButtonsEnabled = !_skipButtonsEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title,
          style: defaultStyle.copyWith(
            fontSize: defaultStyle.fontSize! * 2,
          ),
        ),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if(_skipButtonsEnabled) TextButton(
                  onPressed: () => _incrementHours(count: 4),
                  child: Row(children: [const Icon(Icons.add), const Icon(Icons.add)]),
                ),
                TextButton(
                  onPressed: _incrementHours,
                  child: const Icon(Icons.add),
                ),
                Text(
                  _hours < 10 ? '0$_hours' : '$_hours',
                  style: defaultStyle.copyWith(
                    fontSize: defaultStyle.fontSize! * 2,
                  ),
                ),
                TextButton(
                  onPressed: _decrementHours,
                  child: const Icon(Icons.remove),
                ),
                if(_skipButtonsEnabled) TextButton(
                  onPressed: () => _decrementHours(count: 4),
                  child: Row(children: [const Icon(Icons.remove), const Icon(Icons.remove)]),
                ),
              ]
            ),
            Text(
              ':',
              style: defaultStyle.copyWith(
                fontSize: defaultStyle.fontSize! * 2,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if(_skipButtonsEnabled) TextButton(
                  onPressed: () => _incrementMinutes(count: 10),
                  child: Row(children: [const Icon(Icons.add), const Icon(Icons.add)]),
                ),
                TextButton(
                  onPressed: _incrementMinutes,
                  child: const Icon(Icons.add),
                ),
                Text(
                  _minutes < 10 ? '0$_minutes' : '$_minutes',
                  style: defaultStyle.copyWith(
                    fontSize: defaultStyle.fontSize! * 2,
                  ),
                ),
                TextButton(
                  onPressed: _decrementMinutes,
                  child: const Icon(Icons.remove),
                ),
                if(_skipButtonsEnabled) TextButton(
                  onPressed: () => _decrementMinutes(count: 10),
                  child: Row(children: [const Icon(Icons.remove), const Icon(Icons.remove)]),
                ),
              ]
            ),
            Text(
              ':',
              style: defaultStyle.copyWith(
                fontSize: defaultStyle.fontSize! * 2,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if(_skipButtonsEnabled) TextButton(
                  onPressed: () => _incrementSeconds(count: 10),
                  child: Row(children: [const Icon(Icons.add), const Icon(Icons.add)]),
                ),
                TextButton(
                  onPressed: _incrementSeconds,
                  child: const Icon(Icons.add),
                ),
                Text(
                  _seconds < 10 ? '0$_seconds' : '$_seconds',
                  style: defaultStyle.copyWith(
                    fontSize: defaultStyle.fontSize! * 2,
                  ),
                ),
                TextButton(
                  onPressed: _decrementSeconds,
                  child: const Icon(Icons.remove),
                ),
                if(_skipButtonsEnabled) TextButton(
                  onPressed: () => _decrementSeconds(count: 10),
                  child: Row(children: [const Icon(Icons.remove), const Icon(Icons.remove)]),
                ),
              ]
            ),
            SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _incrementDay,
                  child: const Icon(Icons.add),
                ),
                Text(
                  weekDays[_day],
                  style: defaultStyle.copyWith(
                    fontSize: defaultStyle.fontSize! * 2,
                  ),
                ),
                TextButton(
                  onPressed: _decrementDay,
                  child: const Icon(Icons.remove),
                ),
              ]
            ),
          ],
        )
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FloatingActionButton(
            onPressed: _toggleSkipButtons,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [const Icon(Icons.add), const Icon(Icons.add)]
                ),
                Text(
                  "BUTTONS",
                  style: defaultStyle.copyWith(
                    fontSize: defaultStyle.fontSize! * 0.75,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _syncDataWithPhone,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.sync),
                Text(
                  "PHONE",
                  style: defaultStyle.copyWith(
                    fontSize: defaultStyle.fontSize! * 0.75,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _connectClock,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.sync),
                Text(
                  "CLOCK",
                  style: defaultStyle.copyWith(
                    fontSize: defaultStyle.fontSize! * 0.75,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendDataToClock,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.send),
                Text(
                  "SEND",
                  style: defaultStyle.copyWith(
                    fontSize: defaultStyle.fontSize! * 0.75,
                  ),
                ),
              ],
            ),
          ),
        ],
      )
    );
  }
}
