import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:text_to_speech/text_to_speech.dart';
import 'package:tflite/tflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

List<CameraDescription> cameras = [];

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? cameraController;
  CameraImage? cameraImage;
  List recognitionsList = [];
  TextToSpeech tts = TextToSpeech();
  initCamera() async {
    cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await cameraController!.initialize().then((value) {
      setState(() {
        try {
          cameraController!.startImageStream((image) => {
                cameraImage = image,
                runModel(),
              });
        } catch (e) {
          print(e);
        }
      });
    });
  }

  runModel() async {
    final cI = cameraImage!;
    try {
      recognitionsList = (await Tflite.detectObjectOnFrame(
        bytesList: cI.planes.map((plane) {
          return plane.bytes;
        }).toList(),
        imageHeight: cI.height,
        imageWidth: cI.width,
        imageMean: 127.5,
        imageStd: 127.5,
        numResultsPerClass: 1,
        threshold: 0.4,
      ))!;
    } catch (e) {
      print(e);
    }

    setState(() {
      cameraImage;
    });
  }

  Future loadModel() async {
    Tflite.close();
    await Tflite.loadModel(
        model: "assets/model.tflite", labels: "assets/labels.txt");
  }

  @override
  void dispose() {
    super.dispose();

    cameraController!.stopImageStream();
    Tflite.close();
  }

  @override
  void initState() {
    super.initState();

    loadModel();
    initCamera();
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (recognitionsList == null) return [];

    double factorX = screen.width;
    double factorY = screen.height;

    Color colorPick = Colors.pink;

    return recognitionsList.map((result) {
      tts.speak(result['detectedClass'].toString());
      return Positioned(
        left: result["rect"]["x"] * factorX,
        top: result["rect"]["y"] * factorY,
        width: result["rect"]["w"] * factorX,
        height: result["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${result['detectedClass']} ${(result['confidenceInClass'] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.black,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> list = [];

    list.add(
      Positioned(
        top: 0.0,
        left: 0.0,
        width: size.width,
        height: size.height - 100,
        child: Container(
          height: size.height - 100,
          child: (!cameraController!.value.isInitialized)
              ? new Container()
              : AspectRatio(
                  aspectRatio: cameraController!.value.aspectRatio,
                  child: CameraPreview(cameraController!),
                ),
        ),
      ),
    );

    if (cameraImage != null) {
      list.addAll(displayBoxesAroundRecognizedObjects(size));
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.only(top: 50),
          color: Colors.black,
          child: Stack(
            children: list,
          ),
        ),
      ),
    );
  }
}
