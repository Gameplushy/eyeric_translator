import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eyeric Translator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellow),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<String> _logs = [];
  final TextEditingController _englishFolderController =
      TextEditingController();
  final TextEditingController _translatedFolderController =
      TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();

  late final SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) {
      prefs = value;
      _englishFolderController.value = TextEditingValue(
          text: prefs.getString("englishFolder") ??
              "C:\\Program Files (x86)\\Steam\\steamapps\\common\\The Void Rains Upon Her Heart\\language\\english");
      _translatedFolderController.value = TextEditingValue(
          text: prefs.getString("translatedFolder") ??
              "C:\\Program Files (x86)\\Steam\\steamapps\\common\\The Void Rains Upon Her Heart\\custom languages");
      _languageController.value = TextEditingValue(text: prefs.getString("language") ?? "");
      _versionController.value = const TextEditingValue(text: "Early Access v8.9e");
    });
  }

  void newLog(String s) {
    setState(() {
      _logs.add(s);
    });
  }

  void newLogs(Iterable<String> s) {
    setState(() {
      _logs.addAll(s);
    });
  }

  void updateTranslation() async {
    String rootEn = _englishFolderController.value.text;
    String rootTrans = _translatedFolderController.value.text;
    String language = _languageController.value.text;
    String version = _versionController.value.text;

    prefs.setString("englishFolder", rootEn);
    prefs.setString("translatedFolder", rootTrans);
    prefs.setString("language", language);

    Directory dirEn = Directory.fromUri(Uri.file(rootEn));
    List<File> filesEn =
        dirEn.listSync(recursive: true).whereType<File>().toList();
    Directory dirTrans = Directory.fromUri(Uri.file(rootTrans));
    List<File> filesTrans =
        dirTrans.listSync(recursive: true).whereType<File>().toList();
    /*setState(() {
      _logs.addAll(filesEn.map((f) => f.path));
      _logs.addAll(filesTrans.map((f) => f.path));
    });*/

    //check if there's a version file in both folders
    if (!filesEn.any((f) => f.path.endsWith("\\version"))) {
      newLog("No version file in English folder.");
      return;
    }
    if (!filesTrans.any((f) => f.path.endsWith("\\version"))) {
      newLog("No version file in Translated folder.");
      return;
    }

    List<String> pathsEn =
        filesEn.map((f) => f.path.substring(rootEn.length)).toList();
    List<String> pathsTrans =
        filesTrans.map((f) => f.path.substring(rootTrans.length)).toList();

    Map<String, File> mapEn = {
      for (File f in filesEn) f.path.substring(rootEn.length): f
    };
    Map<String, File> mapTrans = {
      for (File f in filesTrans) f.path.substring(rootTrans.length): f
    };
    /*setState(() {
      _logs.addAll(mapEn.keys);
      _logs.addAll(mapTrans.keys);
    });*/

    Set<String> setEn = pathsEn.toSet();
    Set<String> setTrans = pathsTrans.toSet();

    var newStuff = setEn.difference(setTrans);

    if (newStuff.isNotEmpty) {
      newLog("New files :");
      newLogs(newStuff);
      for (String s in setEn) {
        createFile(rootTrans, s, await mapEn[s]!.readAsString());
      }
    } else {
      newLog("No new file.");
    }

    var oldStuff = setEn.intersection(setTrans);

    for (String sf in oldStuff) {
      if (sf == "\\version") {
        String versionFile = "[version]\r\nname=\"$language\"\r\nversion=\"$version\"";
        createFile(rootTrans, sf, versionFile);
        continue;
      }
      bool notify =true;
      List<String> textEn = await mapEn[sf]!.readAsLines();
      List<String> textTrans = await mapTrans[sf]!.readAsLines();
      List<String> textRes = [];
      int lineTrans = 0;
      for (int lineEn = 0; lineEn < textEn.length; lineEn++) {
        if (lineTrans >= textTrans.length) {
          textRes.add(textEn[lineEn]);
          continue;
        }
        //check if line lineEn of textEn is a JSON key-value pair
        if (textEn[lineEn].contains(":")) {
          //take the left part and compare it to the left part of textTrans[lineTrans]
          String keyEn = textEn[lineEn].split(":").first;
          String keyTrans = textTrans[lineTrans].split(":").first;
          if (keyEn != keyTrans) {
            if(notify) {
              newLog("$sf: New data found.");
              notify = false;
            }
            /*newLog(
                "$sf at line $lineEn : $keyEn != $keyTrans");*/
            textRes.add(textEn[lineEn]);
          } else {
            textRes.add(textTrans[lineTrans]);
            lineTrans++;
          }
        } else {
          //check keyen == keytrans
          if (textEn[lineEn] != textTrans[lineTrans]) {
                        if(notify) {
              newLog("$sf: New data found.");
              notify = false;
            }
            /*newLog(
                "Line mismatch in file $sf at line $lineEn : ${textEn[lineEn]} != ${textTrans[lineTrans]}");*/
            textRes.add(textEn[lineEn]);
          } else {
            textRes.add(textTrans[lineTrans]);
            lineTrans++;
          }
        }
      }
      //Map<String,dynamic> jsonEn = jsonDecode(await mapEn[sf]!.readAsString());
      //Map<String,dynamic> jsonTrans = jsonDecode(await mapTrans[sf]!.readAsString());

      //List<String> missingAttributes = jsonEn.keys.where((j) => !jsonTrans.keys.contains(j)).toList();

      //newLog(sf);
      //newLogs(missingAttributes);

      createFile(rootTrans, sf, textRes.join("\n"));
      newLog("Done with $sf");
    }

    /*File vEn = filesEn.singleWhere((f) => f.uri.pathSegments.last == "version");
    File vTrans = filesTrans.singleWhere((f) => f.uri.pathSegments.last == "version");
    setState(() {
      _logs.add(vEn.path);
      _logs.add(vTrans.path);
    });
    String verEn = (await vEn.readAsLines()).last;
        String verTrans = (await vTrans.readAsLines()).last;
            setState(() {
      _logs.add(verEn);
      _logs.add(verTrans);
    });*/
    newLog("All done!");
  }

  void createFile(String root, String sf, String content) async {
    File newFile = File("${root}_new$sf");
    if (!await newFile.parent.exists()) {
      await newFile.parent.create(recursive: true);
    }
    await newFile.writeAsString(content);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Eyeric translator"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller: _englishFolderController,
              decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  label: const Text("English folder location"),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder),
                    onPressed: () async {
                      String? res = await FilePicker.platform.getDirectoryPath(
                          initialDirectory:
                              _englishFolderController.value.text);
                      if (res != null) {
                        _englishFolderController.value =
                            TextEditingValue(text: res);
                      }
                    },
                  )),
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller: _translatedFolderController,
              decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  label: const Text("Translated folder location"),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder),
                    onPressed: () async {
                      String? res = await FilePicker.platform.getDirectoryPath(
                          initialDirectory:
                              _translatedFolderController.value.text);
                      if (res != null) {
                        _translatedFolderController.value =
                            TextEditingValue(text: res);
                      }
                    },
                  )),
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller: _languageController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text("Language"),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller: _versionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text("Game Version"),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton.tonal(
                    onPressed: () => updateTranslation(),
                    child: const Text("Update")),
                OutlinedButton(
                    onPressed: () => setState(() {
                          _logs.clear();
                        }),
                    child: const Text("Clean")),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            Expanded(
              child: Container(
                decoration:
                    BoxDecoration(border: Border.all(), color: Colors.white),
                child: SingleChildScrollView(
                  child: ListView(
                    shrinkWrap: true,
                    children: _logs.map((s) => Text(s)).toList(),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
