// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File, Platform;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

/// Configuration de calibration selon l'appareil
class DeviceCalibration {
  final double faceSizeMin;
  final double faceSizeMax;
  final double horizontalTolerance;
  final double verticalTolerance;
  final double angleTolerance;
  final double eyeOpenThreshold;

  const DeviceCalibration({
    required this.faceSizeMin,
    required this.faceSizeMax,
    required this.horizontalTolerance,
    required this.verticalTolerance,
    required this.angleTolerance,
    required this.eyeOpenThreshold,
  });

  /// Configuration adaptative selon la plateforme et la caméra
  static DeviceCalibration getCalibration({
    required bool isIOS,
    required bool isFrontCamera,
    required Size screenSize,
  }) {
    // Configuration pour photo d'identité avec adaptation selon appareil
    if (isIOS) {
      if (isFrontCamera) {
        return DeviceCalibration(
          faceSizeMin: 0.35,
          faceSizeMax: 0.70,
          horizontalTolerance: 0.20,
          verticalTolerance: 0.20,
          angleTolerance: 20,
          eyeOpenThreshold: 0.5,
        );
      } else {
        return DeviceCalibration(
          faceSizeMin: 0.40,
          faceSizeMax: 0.70,
          horizontalTolerance: 0.18,
          verticalTolerance: 0.18,
          angleTolerance: 18,
          eyeOpenThreshold: 0.6,
        );
      }
    } else {
      // Android - légèrement plus tolérant pour la variété d'appareils
      if (isFrontCamera) {
        return DeviceCalibration(
          faceSizeMin: 0.32,
          faceSizeMax: 0.72,
          horizontalTolerance: 0.22,
          verticalTolerance: 0.22,
          angleTolerance: 22,
          eyeOpenThreshold: 0.45,
        );
      } else {
        return DeviceCalibration(
          faceSizeMin: 0.38,
          faceSizeMax: 0.72,
          horizontalTolerance: 0.20,
          verticalTolerance: 0.20,
          angleTolerance: 20,
          eyeOpenThreshold: 0.55,
        );
      }
    }
  }
}

/// Compresse l'image avec gestion d'erreur robuste
Future<Uint8List> compressImage(String filePath) async {
  if (kIsWeb) {
    throw UnimplementedError(
        "La compression d'image n'est pas implémentée sur le web.");
  }

  try {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("Le fichier n'existe pas: $filePath");
    }

    final compressedBytes = await FlutterImageCompress.compressWithFile(
      filePath,
      quality: 85,
      minWidth: 600,
      minHeight: 600,
    ).timeout(
      Duration(seconds: 10),
      onTimeout: () {
        debugPrint("⏱️ Timeout compression, utilisation de l'image originale");
        return null;
      },
    );

    if (compressedBytes == null || compressedBytes.isEmpty) {
      debugPrint("⚠️ Compression échouée, utilisation de l'image originale");
      return await file.readAsBytes();
    }

    debugPrint("✅ Image compressée: ${compressedBytes.length} bytes");
    return compressedBytes;
  } catch (e) {
    debugPrint("❌ Erreur compression: $e");
    // Fallback: retourner l'image originale
    return await File(filePath).readAsBytes();
  }
}

/// Recadre l'image au format photo d'identité (7:9) avec gestion d'erreur
Future<Uint8List> cropToIdentityFormat(Uint8List imageBytes) async {
  try {
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      debugPrint("⚠️ Impossible de décoder l'image pour le crop");
      return imageBytes;
    }

    final int originalWidth = originalImage.width;
    final int originalHeight = originalImage.height;

    // Ratio cible : 7:9 (photo d'identité)
    const double targetRatio = 7 / 9;

    int cropWidth;
    int cropHeight;

    final double currentRatio = originalWidth / originalHeight;

    if (currentRatio > targetRatio) {
      cropHeight = originalHeight;
      cropWidth = (cropHeight * targetRatio).round();
    } else {
      cropWidth = originalWidth;
      cropHeight = (cropWidth / targetRatio).round();
    }

    // Sécurité: vérifier que les dimensions sont valides
    cropWidth = cropWidth.clamp(1, originalWidth);
    cropHeight = cropHeight.clamp(1, originalHeight);

    final int offsetX = ((originalWidth - cropWidth) / 2).round().clamp(0, originalWidth - cropWidth);
    final int offsetY = ((originalHeight - cropHeight) / 2).round().clamp(0, originalHeight - cropHeight);

    img.Image croppedImage = img.copyCrop(
      originalImage,
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
    );

    final encodedBytes = img.encodeJpg(croppedImage, quality: 95);
    debugPrint("✅ Image recadrée: ${cropWidth}x${cropHeight}");

    return Uint8List.fromList(encodedBytes);
  } catch (e) {
    debugPrint("❌ Erreur crop: $e");
    return imageBytes; // Retourner l'original en cas d'erreur
  }
}

class CameraWidget extends StatefulWidget {
  const CameraWidget({
    Key? key,
    this.width,
    this.height,
    required this.uploadPhotosAction,
  }) : super(key: key);

  final double? width;
  final double? height;
  final Future Function(List<FFUploadedFile>? photos) uploadPhotosAction;

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {

  // Caméra et détection
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  FaceDetector? _faceDetector;

  // États
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isRearCamera = true;
  bool _isProcessing = false;
  bool _isStreamingImages = false;
  bool _isDisposed = false;

  // Feedback utilisateur
  bool _positionCorrect = false;
  String _feedbackMessage = "Positionnez votre visage";
  Color _feedbackColor = Colors.white;
  IconData _feedbackIcon = Icons.face_outlined;

  // Galerie
  List<AssetEntity> _galleryAssets = [];
  Uint8List? _galleryThumbnail;

  // Configuration et debug
  static const bool _kShowDebugButton = true; // Mettre à false pour cacher le bouton debug
  late DeviceCalibration _calibration;
  Size? _actualPreviewSize;
  bool _showDebugInfo = false;
  String _debugInfo = "";
  Rect? _lastFaceBounds;
  int _noDetectionCount = 0;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Locks pour thread safety
  bool _isProcessingFrame = false;
  bool _isSwitchingCamera = false;

  // Permissions
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _calibration = DeviceCalibration.getCalibration(
      isIOS: Platform.isIOS,
      isFrontCamera: false,
      screenSize: Size(375, 812),
    );

    _initializePulseAnimation();
    _initializeApp();
  }

  void _initializePulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeApp() async {
    try {
      await _checkAndRequestPermissions();
      if (_hasPermissions) {
        await _initializeFaceDetector();
        await _initializeCamera();
        await _fetchGalleryAssets();
      }
    } catch (e) {
      debugPrint('❌ Erreur initialisation app: $e');
      _showError("Erreur d'initialisation");
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      // Les permissions sont gérées au niveau système
      // La caméra et la galerie afficheront automatiquement les dialogs de permission
      _hasPermissions = true;
      debugPrint("✅ Permissions initialisées");
    } catch (e) {
      debugPrint('❌ Erreur permissions: $e');
      _hasPermissions = true; // On laisse le système gérer
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDisposed && _hasPermissions) {
      _updateCalibration();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isDisposed || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // App en arrière-plan: arrêter la caméra
        _pauseCamera();
        break;
      case AppLifecycleState.resumed:
        // App au premier plan: redémarrer la caméra
        _resumeCamera();
        break;
      case AppLifecycleState.detached:
        // App fermée
        _cleanupCamera();
        break;
      case AppLifecycleState.hidden:
        _pauseCamera();
        break;
    }
  }

  Future<void> _pauseCamera() async {
    debugPrint("⏸️ Pause caméra");
    await _stopImageStream();
    await _turnOffFlash();
  }

  Future<void> _resumeCamera() async {
    debugPrint("▶️ Reprise caméra");
    if (_isCameraInitialized && !_isDisposed) {
      _startFaceDetection();
    }
  }

  Future<void> _cleanupCamera() async {
    debugPrint("🧹 Nettoyage caméra");
    await _stopImageStream();
    await _turnOffFlash();
  }

  void _updateCalibration() {
    if (mounted && !_isDisposed) {
      final screenSize = MediaQuery.of(context).size;
      setState(() {
        _calibration = DeviceCalibration.getCalibration(
          isIOS: Platform.isIOS,
          isFrontCamera: !_isRearCamera,
          screenSize: screenSize,
        );
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    _stopImageStream().then((_) {
      _turnOffFlash().then((_) {
        _cameraController?.dispose();
        _faceDetector?.close();
        _pulseController.dispose();
      });
    });

    super.dispose();
  }

  Future<void> _initializeFaceDetector() async {
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableClassification: true,
          enableTracking: false,
          minFaceSize: 0.05,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      debugPrint("✅ Face detector initialisé");
    } catch (e) {
      debugPrint("❌ Erreur init face detector: $e");
    }
  }

  void _resetState() {
    if (mounted && !_isDisposed) {
      setState(() {
        _positionCorrect = false;
        _feedbackMessage = "Positionnez votre visage";
        _feedbackColor = Colors.white;
        _feedbackIcon = Icons.face_outlined;
        _lastFaceBounds = null;
        if (!_showDebugInfo) {
          _debugInfo = "";
        }
        _noDetectionCount = 0;
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed) return;

    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        _showError("Aucune caméra disponible");
        return;
      }

      // Chercher la caméra frontale en priorité pour les selfies
      CameraDescription initialCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _isRearCamera = initialCamera.lensDirection == CameraLensDirection.back;
      _updateCalibration();

      await _setupCameraController(initialCamera);

    } catch (e) {
      debugPrint('❌ Erreur initialisation caméra: $e');
      _showError("Erreur caméra");
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    if (_isDisposed) return;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );

    try {
      await _cameraController!.initialize().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("Timeout initialisation caméra");
        },
      );

      _actualPreviewSize = _cameraController!.value.previewSize;

      debugPrint("📷 Caméra initialisée:");
      debugPrint("- Camera: ${camera.name}");
      debugPrint("- Preview size: $_actualPreviewSize");
      debugPrint("- Direction: ${camera.lensDirection}");
      debugPrint("- Plateforme: ${Platform.isIOS ? 'iOS' : 'Android'}");

      if (mounted && !_isDisposed) {
        setState(() {
          _isCameraInitialized = true;
        });
        _startFaceDetection();
      }
    } catch (e) {
      debugPrint('❌ Erreur setup caméra: $e');
      _showError("Impossible d'initialiser la caméra");
    }
  }

  Future<void> _stopImageStream() async {
    if (_isStreamingImages && _cameraController != null) {
      try {
        await _cameraController!.stopImageStream();
        _isStreamingImages = false;
        debugPrint("⏹️ Stream arrêté");
      } catch (e) {
        debugPrint('⚠️ Erreur arrêt stream: $e');
        _isStreamingImages = false; // Forcer l'état même en cas d'erreur
      }
    }
  }

  void _startFaceDetection() {
    if (_isDisposed ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isStreamingImages) {
      return;
    }

    int frameCount = 0;
    _isStreamingImages = true;

    try {
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isDisposed || !_isStreamingImages) return;

        frameCount++;

        // Traiter seulement toutes les 3 frames
        if (frameCount % 3 != 0) return;

        // Lock pour éviter le traitement concurrent
        if (_isProcessingFrame) return;
        _isProcessingFrame = true;

        try {
          if (_faceDetector != null) {
            final faces = await _detectFacesFromCameraImage(image)
                .timeout(Duration(milliseconds: 500));

            if (!_isDisposed && _isStreamingImages) {
              _updateFeedback(faces);
            }
          }
        } catch (e) {
          if (frameCount % 30 == 0) { // Log toutes les 10 frames traitées
            debugPrint('⚠️ Erreur détection frame: $e');
          }
        } finally {
          await Future.delayed(Duration(milliseconds: 100));
          _isProcessingFrame = false;
        }
      });

      debugPrint("▶️ Détection de visage démarrée");
    } catch (e) {
      debugPrint('❌ Erreur démarrage stream: $e');
      _isStreamingImages = false;
    }
  }

  InputImageRotation _getImageRotation() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return InputImageRotation.rotation0deg;
    }

    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == (_isRearCamera
          ? CameraLensDirection.back
          : CameraLensDirection.front),
      orElse: () => _cameras.first,
    );

    final sensorOrientation = camera.sensorOrientation;

    // Sur Android, on doit ajuster la rotation selon l'orientation du capteur
    // Sur iOS, la rotation est généralement correcte directement
    InputImageRotation rotation;

    if (Platform.isIOS) {
      // iOS: utiliser directement l'orientation du capteur
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    } else {
      // Android: ajustement pour caméra frontale vs arrière
      if (_isRearCamera) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation90deg;
      } else {
        // Caméra frontale: peut nécessiter un ajustement différent
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation270deg;
      }
    }

    debugPrint("📐 Rotation calculée: $rotation (Sensor: $sensorOrientation°, isRear: $_isRearCamera, iOS: ${Platform.isIOS})");

    return rotation;
  }

  Future<List<Face>> _detectFacesFromCameraImage(CameraImage image) async {
    try {
      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == (_isRearCamera
            ? CameraLensDirection.back
            : CameraLensDirection.front),
        orElse: () => _cameras.first,
      );

      final imageRotation = _getImageRotation();

      // NV21 et BGRA8888 n'ont qu'un seul plan selon la doc Google ML Kit
      final bytes = image.planes.first.bytes;

      final InputImageFormat inputImageFormat = Platform.isIOS
          ? InputImageFormat.bgra8888
          : InputImageFormat.nv21;

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );

      final faces = await _faceDetector!.processImage(inputImage);

      // Afficher les infos debug à l'écran si le mode debug est activé
      if (_showDebugInfo && mounted) {
        String rotationName = imageRotation.toString().split('.').last;
        setState(() {
          _debugInfo = "🔍 DEBUG INFO\n"
              "Platform: ${Platform.isIOS ? 'iOS' : 'Android'}\n"
              "Image: ${image.width}x${image.height}\n"
              "Rotation: $rotationName\n"
              "Format: ${inputImageFormat.toString().split('.').last}\n"
              "Planes: ${image.planes.length}\n"
              "Bytes: ${bytes.length}\n"
              "BytesPerRow: ${image.planes[0].bytesPerRow}\n"
              "Faces: ${faces.length}";
        });
      }

      if (faces.isEmpty) {
        _noDetectionCount++;

        if (_noDetectionCount % 30 == 0) {
          debugPrint("⚠️ Aucun visage (${_noDetectionCount}x) - Rotation: $imageRotation, Format: $inputImageFormat");
        }
      } else {
        _noDetectionCount = 0;
        debugPrint("✅ Visage détecté ! Rotation: $imageRotation, Faces: ${faces.length}");
      }

      return faces;
    } catch (e) {
      debugPrint('❌ Erreur ML Kit: $e');
      if (_showDebugInfo && mounted) {
        setState(() {
          _debugInfo = "❌ ERREUR ML KIT:\n$e";
        });
      }
      return [];
    }
  }

  void _updateFeedback(List<Face> faces) {
    if (!mounted || _isDisposed) return;

    setState(() {
      if (faces.isEmpty) {
        _positionCorrect = false;
        _feedbackMessage = "Positionnez votre visage";
        _feedbackColor = Colors.white;
        _feedbackIcon = Icons.face_outlined;
        _lastFaceBounds = null;
        // Ne pas écraser les infos debug si le mode debug est activé
        if (!_showDebugInfo) {
          _debugInfo = "Aucun visage";
        }
        return;
      }

      if (faces.length > 1) {
        _positionCorrect = false;
        _feedbackMessage = "Une seule personne";
        _feedbackColor = Colors.orangeAccent;
        _feedbackIcon = Icons.people_outline;
        if (!_showDebugInfo) {
          _debugInfo = "${faces.length} visages";
        }
        return;
      }

      final face = faces.first;
      final faceBounds = face.boundingBox;
      _lastFaceBounds = faceBounds;

      if (_actualPreviewSize == null) {
        if (!_showDebugInfo) {
          _debugInfo = "Preview size indisponible";
        }
        return;
      }

      // Calculer les dimensions selon la rotation
      double imageWidth;
      double imageHeight;
      final rotation = _getImageRotation();

      if (rotation == InputImageRotation.rotation90deg ||
          rotation == InputImageRotation.rotation270deg) {
        imageWidth = _actualPreviewSize!.height;
        imageHeight = _actualPreviewSize!.width;
      } else {
        imageWidth = _actualPreviewSize!.width;
        imageHeight = _actualPreviewSize!.height;
      }

      final faceRatio = faceBounds.height / imageHeight;
      String debugStr = "Taille: ${(faceRatio * 100).toStringAsFixed(0)}% ";

      bool allChecksPass = true;
      String failReason = "";

      // Vérification taille
      if (faceRatio < _calibration.faceSizeMin) {
        _positionCorrect = false;
        _feedbackMessage = "Rapprochez-vous";
        _feedbackColor = Colors.orangeAccent;
        _feedbackIcon = Icons.zoom_in_outlined;
        failReason = "Trop loin";
        allChecksPass = false;
      } else if (faceRatio > _calibration.faceSizeMax) {
        _positionCorrect = false;
        _feedbackMessage = "Éloignez-vous";
        _feedbackColor = Colors.orangeAccent;
        _feedbackIcon = Icons.zoom_out_outlined;
        failReason = "Trop près";
        allChecksPass = false;
      }

      // Vérification centrage horizontal
      if (allChecksPass) {
        final faceCenterX = faceBounds.left + (faceBounds.width / 2);
        final screenCenterX = imageWidth / 2;
        final horizontalOffset = (faceCenterX - screenCenterX).abs() / imageWidth;

        if (horizontalOffset > _calibration.horizontalTolerance) {
          _positionCorrect = false;
          _feedbackMessage = "Centrez horizontalement";
          _feedbackColor = Colors.orangeAccent;
          _feedbackIcon = Icons.center_focus_weak;
          failReason = "Décalage H";
          allChecksPass = false;
        }
      }

      // Vérification centrage vertical
      if (allChecksPass) {
        final faceCenterY = faceBounds.top + (faceBounds.height / 2);
        final screenCenterY = imageHeight / 2;
        final verticalOffset = (faceCenterY - screenCenterY).abs() / imageHeight;

        if (verticalOffset > _calibration.verticalTolerance) {
          _positionCorrect = false;
          _feedbackMessage = "Centrez verticalement";
          _feedbackColor = Colors.orangeAccent;
          _feedbackIcon = Icons.center_focus_weak;
          failReason = "Décalage V";
          allChecksPass = false;
        }
      }

      // Vérification orientation
      if (allChecksPass) {
        final yaw = face.headEulerAngleY ?? 0;
        final roll = face.headEulerAngleZ ?? 0;

        debugStr += "Y=${yaw.toInt()}° R=${roll.toInt()}° ";

        if (yaw.abs() > _calibration.angleTolerance) {
          _positionCorrect = false;
          _feedbackMessage = "Regardez droit devant";
          _feedbackColor = Colors.orangeAccent;
          _feedbackIcon = Icons.crop_rotate;
          failReason = "Rotation Y";
          allChecksPass = false;
        } else if (roll.abs() > _calibration.angleTolerance) {
          _positionCorrect = false;
          _feedbackMessage = "Tenez votre tête droite";
          _feedbackColor = Colors.orangeAccent;
          _feedbackIcon = Icons.crop_rotate;
          failReason = "Rotation R";
          allChecksPass = false;
        }
      }

      // Vérification yeux
      if (allChecksPass &&
          face.leftEyeOpenProbability != null &&
          face.rightEyeOpenProbability != null) {
        final leftEyeOpen = face.leftEyeOpenProbability!;
        final rightEyeOpen = face.rightEyeOpenProbability!;

        if (leftEyeOpen < _calibration.eyeOpenThreshold ||
            rightEyeOpen < _calibration.eyeOpenThreshold) {
          _positionCorrect = false;
          _feedbackMessage = "Ouvrez les yeux";
          _feedbackColor = Colors.orangeAccent;
          _feedbackIcon = Icons.remove_red_eye_outlined;
          failReason = "Yeux fermés";
          allChecksPass = false;
        }
      }

      if (allChecksPass) {
        _positionCorrect = true;
        _feedbackMessage = "Parfait !";
        _feedbackColor = Color(0xFF00E676);
        _feedbackIcon = Icons.check_circle_outline;
        if (!_showDebugInfo) {
          _debugInfo = debugStr + "✅";
        }
      } else {
        if (!_showDebugInfo) {
          _debugInfo = debugStr + failReason;
        }
      }
    });
  }

  Future<void> _turnOffFlash() async {
    if (_isFlashOn && _cameraController != null && _isRearCamera) {
      try {
        await _cameraController!.setFlashMode(FlashMode.off);
        if (mounted && !_isDisposed) {
          setState(() {
            _isFlashOn = false;
          });
        }
        debugPrint("💡 Flash éteint");
      } catch (e) {
        debugPrint('⚠️ Erreur extinction flash: $e');
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isRearCamera) return;

    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      }

      debugPrint("💡 Flash: ${_isFlashOn ? 'ON' : 'OFF'}");
    } catch (e) {
      debugPrint('❌ Erreur toggle flash: $e');
      _showError("Flash non disponible");
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isSwitchingCamera) return;

    _isSwitchingCamera = true;

    try {
      // Arrêter le stream et le flash
      await _stopImageStream();
      await _turnOffFlash();
      _resetState();

      // Trouver la nouvelle caméra
      CameraDescription newCamera;
      if (_isRearCamera) {
        newCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );
      } else {
        newCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _isCameraInitialized = false;
        });
      }

      // Disposer l'ancien contrôleur
      await _cameraController?.dispose();
      _cameraController = null;

      _isRearCamera = newCamera.lensDirection == CameraLensDirection.back;
      _updateCalibration();

      // Configurer le nouveau contrôleur
      await _setupCameraController(newCamera);

      debugPrint("🔄 Caméra changée: ${_isRearCamera ? 'Arrière' : 'Avant'}");
    } catch (e) {
      debugPrint('❌ Erreur changement caméra: $e');
      _showError("Erreur changement caméra");
    } finally {
      _isSwitchingCamera = false;
    }
  }

  Future<void> _takePhoto() async {
    if (!_positionCorrect && !_showDebugInfo) {
      _showError("Positionnez votre visage correctement");
      return;
    }

    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // Arrêter le stream
      await _stopImageStream();

      // Attendre un peu pour stabiliser
      await Future.delayed(Duration(milliseconds: 100));

      // Prendre la photo
      final XFile image = await _cameraController!.takePicture().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException("Timeout prise de photo");
        },
      );

      // Traiter l'image
      Uint8List imageBytes;
      if (kIsWeb) {
        imageBytes = await image.readAsBytes();
      } else {
        imageBytes = await compressImage(image.path);
      }

      imageBytes = await cropToIdentityFormat(imageBytes);

      final uploadedFile = FFUploadedFile(
        name: path.basename(image.path),
        bytes: imageBytes,
        height: 0,
        width: 0,
        blurHash: '',
      );

      // Supprimer le fichier temporaire
      if (!kIsWeb) {
        try {
          await File(image.path).delete();
        } catch (e) {
          debugPrint('⚠️ Impossible de supprimer le fichier temp: $e');
        }
      }

      _resetState();

      // Upload
      await widget.uploadPhotosAction([uploadedFile]);

      // Redémarrer la détection
      if (mounted && !_isDisposed && _isCameraInitialized) {
        _startFaceDetection();
      }
    } catch (e) {
      debugPrint('❌ Erreur prise de photo: $e');
      _showError("Erreur lors de la capture");

      // Redémarrer la détection même en cas d'erreur
      if (mounted && !_isDisposed && _isCameraInitialized) {
        _resetState();
        _startFaceDetection();
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _openGallery() async {
    if (_isProcessing) return;

    // Arrêter le stream proprement
    await _stopImageStream();

    final ImagePicker picker = ImagePicker();

    try {
      setState(() {
        _isProcessing = true;
      });

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () => null,
      );

      if (image == null) {
        // Utilisateur a annulé
        debugPrint("📷 Sélection galerie annulée");
        return;
      }

      Uint8List imageBytes;
      if (kIsWeb) {
        imageBytes = await image.readAsBytes();
      } else {
        imageBytes = await compressImage(image.path);
      }

      imageBytes = await cropToIdentityFormat(imageBytes);

      final uploadedFile = FFUploadedFile(
        name: path.basename(image.path),
        bytes: imageBytes,
        height: 0,
        width: 0,
        blurHash: '',
      );

      await widget.uploadPhotosAction([uploadedFile]);

    } catch (e) {
      debugPrint('❌ Erreur galerie: $e');
      _showError("Erreur import photo");
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isProcessing = false;
        });

        // Redémarrer la détection si on est toujours sur la page
        if (_isCameraInitialized) {
          await Future.delayed(Duration(milliseconds: 500));
          _startFaceDetection();
        }
      }
    }
  }

  Future<void> _fetchGalleryAssets() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        debugPrint("⚠️ Permission galerie refusée");
        return;
      }

      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );

      if (albums.isNotEmpty) {
        final List<AssetEntity> recentAssets = await albums[0].getAssetListPaged(
          page: 0,
          size: 1,
        );

        // Charger la thumbnail une seule fois
        Uint8List? thumbnail;
        if (recentAssets.isNotEmpty) {
          thumbnail = await recentAssets.first.thumbnailDataWithSize(
            ThumbnailSize(100, 100),
          );
        }

        if (mounted && !_isDisposed) {
          setState(() {
            _galleryAssets = recentAssets;
            _galleryThumbnail = thumbnail;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur fetch galerie: $e');
    }
  }

  void _toggleDebugMode() {
    if (mounted && !_isDisposed) {
      setState(() {
        _showDebugInfo = !_showDebugInfo;
        if (!_showDebugInfo) {
          _debugInfo = ""; // Réinitialiser les infos debug quand on désactive
        }
      });
      debugPrint("🐛 Mode debug: ${_showDebugInfo ? 'ON' : 'OFF'}");
    }
  }

  void _showError(String message) {
    if (mounted && !_isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildModernIconButton({
    required VoidCallback onPressed,
    required IconData icon,
    Color? backgroundColor,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? (backgroundColor ?? Colors.amber).withValues(alpha: 0.9)
                : (backgroundColor ?? Colors.black).withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.2),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityOverlay(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final bool isPortrait = screenHeight > screenWidth;
    final double ovalWidth = screenWidth * (isPortrait ? 0.70 : 0.50);
    final double ovalHeight = screenHeight * (isPortrait ? 0.50 : 0.70);

    return CustomPaint(
      size: Size(screenWidth, screenHeight),
      painter: MinimalGuidePainter(
        ovalWidth: ovalWidth,
        ovalHeight: ovalHeight,
        showDebug: _showDebugInfo,
        faceBounds: _lastFaceBounds,
        previewSize: _actualPreviewSize,
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _feedbackColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_feedbackIcon, color: _feedbackColor, size: 20),
                  SizedBox(width: 10),
                  Text(
                    _feedbackMessage,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            if ((_showDebugInfo || !Platform.isIOS) && _debugInfo.isNotEmpty) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _debugInfo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.yellow,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    final bool canCapture = _positionCorrect || _showDebugInfo;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: canCapture ? _takePhoto : null,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_positionCorrect)
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(0xFF00E676).withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canCapture
                        ? (_positionCorrect ? Color(0xFF00E676) : Colors.orange)
                        : Colors.white.withValues(alpha: 0.3),
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: canCapture
                        ? [
                            BoxShadow(
                              color: (_positionCorrect
                                      ? Color(0xFF00E676)
                                      : Colors.orange)
                                  .withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGalleryButton() {
    return GestureDetector(
      onTap: _openGallery,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _galleryThumbnail != null
              ? Image.memory(
                  _galleryThumbnail!,
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.grey[800],
                  child: Icon(Icons.photo_library, color: Colors.white, size: 20),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double previewWidth = widget.width ?? MediaQuery.of(context).size.width;
    final double previewHeight = widget.height ?? MediaQuery.of(context).size.height;

    if (!_hasPermissions) {
      return Container(
        width: previewWidth,
        height: previewHeight,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt, color: Colors.white, size: 64),
              SizedBox(height: 20),
              Text(
                "Permission caméra requise",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkAndRequestPermissions,
                child: Text("Autoriser"),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          // Nettoyage avant de quitter
          await _stopImageStream();
          await _turnOffFlash();
        }
      },
      child: Stack(
        children: [
          if (_isCameraInitialized && _cameraController != null)
            Center(
              child: ClipRect(
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.height,
                      height: _cameraController!.value.previewSize!.width,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: previewWidth,
              height: previewHeight,
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Initialisation...",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          if (_isCameraInitialized && _cameraController != null)
            _buildIdentityOverlay(context),
          if (_isCameraInitialized && !_isProcessing)
            _buildStatusIndicator(),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Traitement...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildModernIconButton(
                          onPressed: () async {
                            await _stopImageStream();
                            await _turnOffFlash();
                            Navigator.of(context).pop();
                          },
                          icon: Icons.close,
                        ),
                        Row(
                          children: [
                            if (_kShowDebugButton)
                              _buildModernIconButton(
                                onPressed: _toggleDebugMode,
                                icon: Icons.bug_report,
                                backgroundColor: _showDebugInfo ? Colors.yellow : null,
                                isActive: _showDebugInfo,
                              ),
                            if (_kShowDebugButton) SizedBox(width: 12),
                            if (_isRearCamera)
                              _buildModernIconButton(
                                onPressed: _toggleFlash,
                                icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                                backgroundColor: _isFlashOn ? Colors.amber : null,
                                isActive: _isFlashOn,
                              ),
                            if (_isRearCamera) SizedBox(width: 12),
                            if (_cameras.length > 1)
                              _buildModernIconButton(
                                onPressed: _switchCamera,
                                icon: Icons.flip_camera_ios,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  Padding(
                    padding: EdgeInsets.only(bottom: 40, left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildGalleryButton(),
                        _buildCaptureButton(),
                        SizedBox(width: 44),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Extension pour obtenir la rotation depuis une valeur int
extension InputImageRotationValue on InputImageRotation {
  static InputImageRotation? fromRawValue(int value) {
    switch (value) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return null;
    }
  }
}

// Painter minimaliste et professionnel
class MinimalGuidePainter extends CustomPainter {
  final double ovalWidth;
  final double ovalHeight;
  final bool showDebug;
  final Rect? faceBounds;
  final Size? previewSize;

  MinimalGuidePainter({
    required this.ovalWidth,
    required this.ovalHeight,
    this.showDebug = false,
    this.faceBounds,
    this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    final Rect ovalRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: ovalWidth,
      height: ovalHeight,
    );

    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, darkPaint);
    canvas.drawOval(ovalRect, borderPaint);

    final double cornerLength = 30;
    final double cornerOffset = 10;

    // Coins style moderne
    _drawCorner(canvas, cornerPaint, ovalRect.left, ovalRect.top,
                cornerLength, cornerOffset, isTopLeft: true);
    _drawCorner(canvas, cornerPaint, ovalRect.right, ovalRect.top,
                cornerLength, cornerOffset, isTopRight: true);
    _drawCorner(canvas, cornerPaint, ovalRect.left, ovalRect.bottom,
                cornerLength, cornerOffset, isBottomLeft: true);
    _drawCorner(canvas, cornerPaint, ovalRect.right, ovalRect.bottom,
                cornerLength, cornerOffset, isBottomRight: true);

    // Ligne guide pour les yeux
    final Paint centerLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double eyeLineY = ovalRect.top + (ovalHeight * 0.42);
    canvas.drawLine(
      Offset(ovalRect.left + 20, eyeLineY),
      Offset(ovalRect.right - 20, eyeLineY),
      centerLinePaint,
    );
  }

  void _drawCorner(Canvas canvas, Paint paint, double x, double y,
                   double length, double offset,
                   {bool isTopLeft = false, bool isTopRight = false,
                    bool isBottomLeft = false, bool isBottomRight = false}) {
    if (isTopLeft) {
      canvas.drawLine(
        Offset(x - offset, y + length),
        Offset(x - offset, y - offset),
        paint,
      );
      canvas.drawLine(
        Offset(x - offset, y - offset),
        Offset(x + length, y - offset),
        paint,
      );
    } else if (isTopRight) {
      canvas.drawLine(
        Offset(x + offset, y + length),
        Offset(x + offset, y - offset),
        paint,
      );
      canvas.drawLine(
        Offset(x + offset, y - offset),
        Offset(x - length, y - offset),
        paint,
      );
    } else if (isBottomLeft) {
      canvas.drawLine(
        Offset(x - offset, y - length),
        Offset(x - offset, y + offset),
        paint,
      );
      canvas.drawLine(
        Offset(x - offset, y + offset),
        Offset(x + length, y + offset),
        paint,
      );
    } else if (isBottomRight) {
      canvas.drawLine(
        Offset(x + offset, y - length),
        Offset(x + offset, y + offset),
        paint,
      );
      canvas.drawLine(
        Offset(x + offset, y + offset),
        Offset(x - length, y + offset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
