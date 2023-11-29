import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class StaticImage extends StatefulWidget {
  @override
  _StaticImageState createState() => _StaticImageState();
}

class _StaticImageState extends State<StaticImage> {
  File _image;
  List _recognitions;
  bool _busy;
  double _imageWidth, _imageHeight;

  final picker = ImagePicker();

  tfl.Interpreter _interpreter;

  Future loadModel() async {
    try {
      InterpreterOptions interpreterOptions = InterpreterOptions();

      interpreterOptions.threads = 2;
      _interpreter = await Interpreter.fromAsset('assets/models/ssd_mobilenet.tflite', options: interpreterOptions);

    } catch (e) {
      print('Error loading model: $e');
    }
  }

  Future runModelOnImage() async {
    final imageBytes = File(_image.path).readAsBytesSync();
    img.Image imageTemp = img.decodeImage(imageBytes.toList());
    var resized = img.copyResize(imageTemp, width: 300, height: 300);
    var imgBytes = resized.getBytes();
    var input = imgBytes.buffer.asFloat32List();

    // Assuming that the output is of size [1, 10, 4], [1, 10], [1, 10] and [1]
    var outputLocations = List.filled(1 * 10 * 4, 0).reshape([1, 10, 4]);
    var outputClasses = List.filled(1 * 10, 0).reshape([1, 10]);
    var outputScores = List.filled(1 * 10, 0).reshape([1, 10]);
    var numLocations = List.filled(1, 0).reshape([1]);

    var outputs = {
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: numLocations,
    };

    _interpreter.runForMultipleInputs([input], outputs);

    var recognitions = [];
    for (int i = 0; i < numLocations[0]; i++) {
      double top = outputLocations[0][i][0] * _imageHeight;
      double left = outputLocations[0][i][1] * _imageWidth;
      double bottom = outputLocations[0][i][2] * _imageHeight;
      double right = outputLocations[0][i][3] * _imageWidth;

      var recognition = {
        "rect": {"x": left, "y": top, "w": right - left, "h": bottom - top},
        "confidenceInClass": outputScores[0][i],
        "detectedClass": outputClasses[0][i].toString(),
      };

      recognitions.add(recognition);
    }
    setState(() {
      _recognitions = recognitions;
    });
  }



  @override
  void initState() {
    super.initState();
    _busy = true;
    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;

    Color blue = Colors.blue;

    return _recognitions.map((re) {
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
                color: blue,
                width: 3,
              )),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = blue,
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    List<Widget> stackChildren = [];

    stackChildren.add(Positioned(
      child: _image == null
          ? Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Please Select an Image"),
          ],
        ),
      )
          : Container(child: Image.file(_image)),
    ));

    stackChildren.addAll(renderBoxes(size));

    if (_busy) {
      stackChildren.add(Center(
        child: CircularProgressIndicator(),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Object Detector"),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            heroTag: "Fltbtn2",
            child: Icon(Icons.camera_alt),
            onPressed: getImageFromCamera,
          ),
          SizedBox(
            width: 10,
          ),
          FloatingActionButton(
            heroTag: "Fltbtn1",
            child: Icon(Icons.photo),
            onPressed: getImageFromGallery,
          ),
        ],
      ),
      body: Container(
        alignment: Alignment.center,
        child: Stack(
          children: stackChildren,
        ),
      ),
    );
  }


  Future getImageFromCamera() async {
    final pickedFile = await picker.getImage(source: ImageSource.camera);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        print("No image Selected");
      }
    });
    runModelOnImage();
  }

  Future getImageFromGallery() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        print("No image Selected");
      }
    });
    runModelOnImage();
  }
}
































// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:tflite/tflite.dart';
//
// class StaticImage extends StatefulWidget {
//   @override
//   _StaticImageState createState() => _StaticImageState();
// }
//
// class _StaticImageState extends State<StaticImage> {
//   File _image;
//   List _recognitions;
//   bool _busy;
//   double _imageWidth, _imageHeight;
//
//   final picker = ImagePicker();
//
//   // this function loads the model
//   loadTfModel() async {
//     await Tflite.loadModel(
//       model: "assets/models/ssd_mobilenet.tflite",
//       labels: "assets/models/labels.txt",
//     );
//   }
//
//   // this function detects the objects on the image
//   detectObject(File image) async {
//     var recognitions = await Tflite.detectObjectOnImage(
//         path: image.path, // required
//         model: "SSDMobileNet",
//         imageMean: 127.5,
//         imageStd: 127.5,
//         threshold: 0.4, // defaults to 0.1
//         numResultsPerClass: 10, // defaults to 5
//         asynch: true // defaults to true
//         );
//     FileImage(image)
//         .resolve(ImageConfiguration())
//         .addListener((ImageStreamListener((ImageInfo info, bool _) {
//           setState(() {
//             _imageWidth = info.image.width.toDouble();
//             _imageHeight = info.image.height.toDouble();
//           });
//         })));
//     setState(() {
//       _recognitions = recognitions;
//     });
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _busy = true;
//     loadTfModel().then((val) {
//       {
//         setState(() {
//           _busy = false;
//         });
//       }
//     });
//   }
//
//   // display the bounding boxes over the detected objects
//   List<Widget> renderBoxes(Size screen) {
//     if (_recognitions == null) return [];
//     if (_imageWidth == null || _imageHeight == null) return [];
//
//     double factorX = screen.width;
//     double factorY = _imageHeight / _imageHeight * screen.width;
//
//     Color blue = Colors.blue;
//
//     return _recognitions.map((re) {
//       return Container(
//         child: Positioned(
//             left: re["rect"]["x"] * factorX,
//             top: re["rect"]["y"] * factorY,
//             width: re["rect"]["w"] * factorX,
//             height: re["rect"]["h"] * factorY,
//             child: ((re["confidenceInClass"] > 0.50))
//                 ? Container(
//                     decoration: BoxDecoration(
//                         border: Border.all(
//                       color: blue,
//                       width: 3,
//                     )),
//                     child: Text(
//                       "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
//                       style: TextStyle(
//                         background: Paint()..color = blue,
//                         color: Colors.white,
//                         fontSize: 15,
//                       ),
//                     ),
//                   )
//                 : Container()),
//       );
//     }).toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.of(context).size;
//
//     List<Widget> stackChildren = [];
//
//     stackChildren.add(Positioned(
//       // using ternary operator
//       child: _image == null
//           ? Container(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: <Widget>[
//                   Text("Please Select an Image"),
//                 ],
//               ),
//             )
//           : // if not null then
//           Container(child: Image.file(_image)),
//     ));
//
//     stackChildren.addAll(renderBoxes(size));
//
//     if (_busy) {
//       stackChildren.add(Center(
//         child: CircularProgressIndicator(),
//       ));
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Object Detector"),
//       ),
//       floatingActionButton: Row(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: <Widget>[
//           FloatingActionButton(
//             heroTag: "Fltbtn2",
//             child: Icon(Icons.camera_alt),
//             onPressed: getImageFromCamera,
//           ),
//           SizedBox(
//             width: 10,
//           ),
//           FloatingActionButton(
//             heroTag: "Fltbtn1",
//             child: Icon(Icons.photo),
//             onPressed: getImageFromGallery,
//           ),
//         ],
//       ),
//       body: Container(
//         alignment: Alignment.center,
//         child: Stack(
//           children: stackChildren,
//         ),
//       ),
//     );
//   }
//
//   // gets image from camera and runs detectObject
//   Future getImageFromCamera() async {
//     final pickedFile = await picker.getImage(source: ImageSource.camera);
//
//     setState(() {
//       if (pickedFile != null) {
//         _image = File(pickedFile.path);
//       } else {
//         print("No image Selected");
//       }
//     });
//     detectObject(_image);
//   }
//
//   // gets image from gallery and runs detectObject
//   Future getImageFromGallery() async {
//     final pickedFile = await picker.getImage(source: ImageSource.gallery);
//     setState(() {
//       if (pickedFile != null) {
//         _image = File(pickedFile.path);
//       } else {
//         print("No image Selected");
//       }
//     });
//     detectObject(_image);
//   }
// }
