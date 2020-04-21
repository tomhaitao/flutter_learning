import 'dart:typed_data';
import 'dart:ui';
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:face_detect/face_contour_painter.dart';
import 'package:face_detect/utils.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;

class FaceContourDetectionScreen extends StatefulWidget {
  @override
  _FaceContourDetectionScreenState createState() =>
      _FaceContourDetectionScreenState();
}

class _FaceContourDetectionScreenState
    extends State<FaceContourDetectionScreen> {
  final FaceDetector faceDetector = FirebaseVision.instance.faceDetector(
      FaceDetectorOptions(
          enableClassification: false,
          enableLandmarks: false,
          enableContours: true,
          enableTracking: false));
  List<Face> faces;
  CameraController _camera;
  bool cameraEnabled = true;
  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.back;
  GlobalKey rootWidgetKey = GlobalKey();
  List<Uint8List> images = List();
  String imagePath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    CameraDescription description = await getCamera(_direction);
    ImageRotation rotation = rotationIntToImageRotation(
      description.sensorOrientation,
    );

    print(rotation);

    _camera = CameraController(
      description,
      defaultTargetPlatform == TargetPlatform.iOS
          ? ResolutionPreset.low
          : ResolutionPreset.medium,
    );
    await _camera.initialize();

    print("initialize Camera");
    print(description.lensDirection);
    print(_camera.description.lensDirection);

    _camera.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;

      detect(image, faceDetector.processImage, rotation).then(
        (dynamic result) {
          setState(() {
            faces = result;
          });

          _isDetecting = false;
        },
      ).catchError(
        (_) {
          _isDetecting = false;
        },
      );
    });
  }

  Widget _buildResults() {
    const Text noResultsText = const Text('No results!');

    if (faces == null || _camera == null || !_camera.value.isInitialized) {
      return noResultsText;
    }

    CustomPainter painter;

    final Size imageSize = Size(
      _camera.value.previewSize.height,
      _camera.value.previewSize.width,
    );

    if (faces is! List<Face>) return noResultsText;
    painter = FaceContourPainter(imageSize, faces, _direction);

    return CustomPaint(
      painter: painter,
    );
  }

  Widget _buildImage() {
    return Container(
      constraints: const BoxConstraints.expand(),
      child: _camera == null
          ? const Center(
              child: Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 30.0,
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CameraPreview(_camera),
                _buildResults(),
                Positioned(
                  bottom: 0.0,
                  left: 0.0,
                  right: 0.0,
                  child: Container(
                    color: Colors.white,
                    height: 50.0,
                    child: ListView(
                      children: faces
                          .map((face) =>
                              Text(face.boundingBox.center.toString()))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _toggleCameraDirection() async {
    if (_direction == CameraLensDirection.back) {
      _direction = CameraLensDirection.front;
    } else {
      _direction = CameraLensDirection.back;
    }

    await _camera.stopImageStream();
    await _camera.dispose();

    setState(() {
      _camera = null;
    });

    _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Flutter Face Contour Detection"),
        actions: <Widget>[
//          Center(child: Text(faces.length.toString() ?? '0')),
          IconButton(
              icon:
                  Icon(cameraEnabled ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  cameraEnabled = !cameraEnabled;
                });
              })
        ],
      ),
      body: _camera == null
          ? const Center(
              child: Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 30.0,
                ),
              ),
            )
          : _liveCameraWithFaceDetection(),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleCameraDirection,
        child: _direction == CameraLensDirection.back
            ? const Icon(Icons.camera_front)
            : const Icon(Icons.camera_rear),
      ),
    );
  }

  Widget _liveCameraWithFaceDetection() {
    return Column(
      children: <Widget>[
        Expanded(
          child: RepaintBoundary(
            key: rootWidgetKey,
            child: Container(
              constraints: const BoxConstraints.expand(),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  cameraEnabled
                      ? CameraPreview(_camera)
                      : Container(
                    color: Colors.black,
                  ),
                  (faces != null && _camera.value.isInitialized)
                      ? CustomPaint(
                    painter: FaceContourPainter(
                        Size(
                          _camera.value.previewSize.height,
                          _camera.value.previewSize.width,
                        ),
                        faces,
                        _camera.description.lensDirection
                    ),
                  )
                      : null,
                  Image.asset('images/head.png')
                ],
              ),
            ),
          ),
        ),
        _captureControlRowWidget(),
        _showImageBoxWidget(),
//        _listViewWidget(),
      ],
    );
  }

  Widget _captureControlRowWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.camera_alt),
          color: Colors.blue,
          onPressed: _camera != null &&
              _camera.value.isInitialized ? onTakePictureButtonPressed : null,
        ),
//        IconButton(
//          icon: const Icon(Icons.videocam),
//          color: Colors.blue,
//        )
      ],
    );
  }

  Widget _showImageBoxWidget() {
    return SizedBox(
//        width: 100,
        height: 240,
        child: imagePath == null ? Container() : Image.file(File(imagePath)),
    );
  }

  Widget _listViewWidget() {
    return Expanded(
      child: ListView.builder(
        itemBuilder: (context, index) {
          return Image.memory(
            images[index],
            fit: BoxFit.cover,
          );
        },
        itemCount: images.length,
        scrollDirection: Axis.horizontal,
      ),
    );
  }

  _capturePng() async {
    try {
      RenderRepaintBoundary boundary =
      rootWidgetKey.currentContext.findRenderObject();
      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData.buffer.asUint8List();
      images.add(pngBytes);
//      setState(() {});
      return pngBytes;
    } catch (e) {
      print(e);
    }
    return null;
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      print(11111111);
      print(filePath);
      setState(() {
        imagePath = filePath;
      });
    });
  }

  Future<String> takePicture() async {
    if (!_camera.value.isInitialized) {
//      showInSnackBar('Error: select a camera first.');
      return null;
    }
//    final Directory extDir = await getApplicationDocumentsDirectory();
//    final String dirPath = '${extDir.path}/Pictures/flutter_test';
//    await Directory(dirPath).create(recursive: true);
//    final String filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch.toString()}.jpg';
//      final filePath = (await getTemporaryDirectory()).path+'${DateTime.now()}.png';
    final filePath = join(
      (await getTemporaryDirectory()).path,
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
    print(filePath);
//    final filePath = join(
//      // Store the picture in the temp directory.
//      // Find the temp directory using the `path_provider` plugin.
//      (await getTemporaryDirectory()).path,
//      '${DateTime.now()}.png',
//    );

    if (_camera.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
//      await _camera.stopImageStream();
//      await _camera.dispose();
//      await Future.delayed(Duration(milliseconds: 2000));
      //必须停止流外加延迟一定时间才能拍照成功
      await _camera.stopImageStream();
      await Future.delayed(Duration(milliseconds:10));
      await _camera.takePicture(filePath);
      _startStream();//重新启动相机流去识别图像
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  void _startStream() async{
    CameraDescription description = await getCamera(_direction);
    ImageRotation rotation = rotationIntToImageRotation(
      description.sensorOrientation,
    );
    _camera.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;

      detect(image, faceDetector.processImage, rotation).then(
            (dynamic result) {
          setState(() {
            faces = result;
          });

          _isDetecting = false;
        },
      ).catchError(
            (_) {
          _isDetecting = false;
        },
      );
    });
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
//    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

class LiveCameraWithFaceDetection extends StatelessWidget {
  final List<Face> faces;
  final CameraController camera;
  final bool cameraEnabled;

  const LiveCameraWithFaceDetection(
      {Key key, this.faces, this.camera, this.cameraEnabled = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    print(camera.description.lensDirection);
    return Container(
      constraints: const BoxConstraints.expand(),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          cameraEnabled
              ? CameraPreview(camera)
              : Container(
                  color: Colors.black,
                ),
          (faces != null && camera.value.isInitialized)
              ? CustomPaint(
                  painter: FaceContourPainter(
                      Size(
                        camera.value.previewSize.height,
                        camera.value.previewSize.width,
                      ),
                      faces,
                      camera.description.lensDirection),
                )
              : const Text('No results!'),
        ],
      ),
    );
  }
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');