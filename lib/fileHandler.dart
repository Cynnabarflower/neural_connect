
import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'slideToConfirm.dart';

class StatisticsPage extends StatefulWidget {

  StatisticsPage();

  static Future<void> saveStats(stats, time) async {
    final directory = await Directory(
        (await getApplicationDocumentsDirectory()).path + '/saved_data/').create();
    var file = File("${directory.path}_${time.toString()}.txt");

    file.writeAsString(stats.fold(
        "$time", (previousValue, element) =>
        previousValue + '\n' + element.toString()))
        .then((value) {
      print('stats saved ${file.path}');
    });
  }

  @override
  State<StatefulWidget> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<bool> checkBoxes = [];
  List<String> files = [];
  bool loaded = false;
  bool deleteDragStarted = false;
  Timer updateTimer;
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  Future<String> getChosenFiles() async {
    var chosenFiles = [];
    for (int i = 0; i < files.length; i++)
      if (checkBoxes[i])
        chosenFiles.add(files[i]);
    String fileToShare;
    if (chosenFiles.isEmpty)
      return "";
    if (chosenFiles.length == 1)
      fileToShare = chosenFiles[0];
    else {
      var encoder = ZipFileEncoder();
      var path = (await getApplicationDocumentsDirectory()).path + '/stats_${DateTime.now().year}:${DateTime.now().month}:${DateTime.now().day}:${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}.zip';
      encoder.create(path);
      chosenFiles.forEach((element) { encoder.addFile(File(element)); });
      encoder.close();
      fileToShare = path;
    }
    return fileToShare;
  }

  Future<void> shareFiles() async {
    var fileToShare = await getChosenFiles();
    if (fileToShare.isEmpty)
      return;
    String fileName = fileToShare.substring(fileToShare.lastIndexOf('/') + 1);
    await Share.file(fileName.substring(fileName.lastIndexOf('.')), fileName, File(fileToShare).readAsBytesSync(), fileName.endsWith('.zip') ? 'application/zip' : 'text/plain')
        .then((value) =>
    fileName.endsWith('.zip') ? File(fileToShare).delete() : {}
    );
  }

  deleteFiles() async {
    for (int i = 0; i < files.length; i++)
      if (checkBoxes[i]) {
        var file = File(files[i]);
        if (file.existsSync()) {
          file.delete();
        }
      }
    files.clear();
    checkBoxes.clear();
    loadStats();
  }

  download() async {

    var status = await Permission.storage.status;
    if (status.isUndetermined || status.isDenied) {
      status = await Permission.storage.request();
    }

    var filePath = await getChosenFiles();
    if (filePath.isNotEmpty) {
      var path = '';
      if (Platform.isIOS) {
        path = (await getDownloadsDirectory()).path;
      } else if (Platform.isAndroid) {
        path = '/storage/emulated/0/Download/';
      }
      var f = File(filePath);
      f.copy(path + filePath.substring(filePath.lastIndexOf('/') + 1)).then((value) => filePath.endsWith('.zip') ? File(filePath).delete() : {});
      (scaffoldKey.currentState).showSnackBar(
          SnackBar(
            content: Text("Saved to downloads"),
            duration: Duration(milliseconds: 800),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      body: Container(
        height: 1000,
        child: Stack(
          children: [
            Container(
              alignment: Alignment.center,
              child: loaded
                  ? ListView.builder(
                  itemCount: checkBoxes.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8))),
                      child: CheckboxListTile(
                        dense: true,
                        isThreeLine: false,
                        title: FittedBox(
                            fit: BoxFit.fill,
                            alignment: Alignment.centerLeft,
                            child: Text(files[index].split('/').last.replaceAll('.txt', ''),
                                style: TextStyle(color: Colors.black, fontSize: 20))),
                        value: checkBoxes[index],
                        onChanged: (value) {
                          setState(() {
                            checkBoxes[index] = !checkBoxes[index];
                          });
                        },
                      ),
                    );
                  })
                  :  SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  strokeWidth: 10,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
            Align(
              alignment: Alignment.lerp(Alignment.centerRight, Alignment.bottomRight, 0.9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ConfirmationSlider(
                        height: 50,
                        width: 140,
                        shadow: BoxShadow(color: Color.fromARGB(0, 0, 0, 0)),
                        backgroundColor: Colors.redAccent[100],
                        backgroundShape: BorderRadius.circular(30),
                        icon: Icons.delete,
                        textStyle: TextStyle(fontSize: 20, color: Colors.white),
                        foregroundColor: Colors.redAccent,
                        onConfirmation: () => deleteFiles(),
                        onStarted:(){}
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: MaterialButton(
                        child: Icon(Icons.file_download, color: Colors.white, size: 20,),
                        color: Colors.green,
                        shape: CircleBorder(),
                        onPressed: download,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: RaisedButton(
                        child: Icon(Icons.check, color: Colors.white, size: 20,),
                        color: Colors.orange,
                        shape: CircleBorder(),
                        onPressed: () {
                          for (int i = 0; i < files.length; i++)
                            if (checkBoxes[i]) {
                              for (int j = 0; j < files.length; j++)
                                checkBoxes[j] = false;
                              setState(() {});
                              return;
                            } else
                              checkBoxes[i] = true;
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: RaisedButton(
                        child: Icon(Icons.share, color: Colors.white, size: 20,),
                        color: Colors.blueAccent,
                        shape: CircleBorder(),
                        onPressed: shareFiles,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  loadStats() async {
    final directory =
        Directory((await getApplicationDocumentsDirectory()).path + '/saved_data/');
    if (!directory.existsSync())
      directory.createSync();
    var files = (directory.listSync().where((element) => element is File).map((e) => e.path)).toList();
    files = files.where((element) => !this.files.contains(element)).toList();
    setState(() {
      loaded = true;
      checkBoxes.addAll(List(files.length)..fillRange(0, files.length, false));
      this.files.addAll(files);
    });
  }


  @override
  void dispose() {
    if (updateTimer != null)
      updateTimer.cancel();
    super.dispose();
  }

  @override
  void initState() {
    loadStats();
    updateTimer = Timer.periodic(Duration(seconds: 4), (timer) {
      loadStats();
    });
    super.initState();
  }
}
