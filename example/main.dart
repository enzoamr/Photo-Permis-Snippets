import 'package:flutter/material.dart';
import '../lib/custom_widgets/camera_widget_improved.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Identité Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _capturedPhotoBytes;
  String? _photoName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photo d\'Identité'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_capturedPhotoBytes != null) ...[
              // Afficher la photo capturée
              Container(
                width: 280,
                height: 360,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    _capturedPhotoBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Photo capturée !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Nom: $_photoName',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Taille: ${(_capturedPhotoBytes!.length / 1024).toStringAsFixed(1)} KB',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 30),
              // Boutons d'action
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openCamera,
                    icon: Icon(Icons.camera_alt),
                    label: Text('Reprendre'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _uploadPhoto,
                    icon: Icon(Icons.cloud_upload),
                    label: Text('Uploader'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // État initial sans photo
              Icon(
                Icons.photo_camera,
                size: 100,
                color: Colors.grey[400],
              ),
              SizedBox(height: 30),
              Text(
                'Aucune photo capturée',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 50),
              ElevatedButton.icon(
                onPressed: _openCamera,
                icon: Icon(Icons.camera_alt, size: 28),
                label: Text(
                  'Prendre une photo',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraWidget(
          uploadPhotosAction: (photos) async {
            if (photos != null && photos.isNotEmpty) {
              final photo = photos.first;

              // Sauvegarder la photo dans l'état
              setState(() {
                _capturedPhotoBytes = photo.bytes;
                _photoName = photo.name;
              });

              // Afficher un message de succès
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Photo capturée avec succès !'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );

              // Retourner à la page d'accueil
              Navigator.pop(context);
            }
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _uploadPhoto() async {
    if (_capturedPhotoBytes == null) return;

    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Upload en cours...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // TODO: Remplacer par votre logique d'upload
      // Exemple:
      // await uploadToServer(_capturedPhotoBytes!, _photoName!);

      // Simuler un upload
      await Future.delayed(Duration(seconds: 2));

      // Fermer le dialog
      Navigator.pop(context);

      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_done, color: Colors.white),
              SizedBox(width: 10),
              Text('Photo uploadée avec succès !'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Réinitialiser l'état
      setState(() {
        _capturedPhotoBytes = null;
        _photoName = null;
      });
    } catch (e) {
      // Fermer le dialog
      Navigator.pop(context);

      // Afficher une erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Erreur lors de l\'upload'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// Exemple de fonction d'upload (à adapter selon votre backend)
/*
Future<void> uploadToServer(Uint8List imageBytes, String fileName) async {
  final dio = Dio();

  final formData = FormData.fromMap({
    'file': MultipartFile.fromBytes(
      imageBytes,
      filename: fileName,
    ),
  });

  try {
    final response = await dio.post(
      'https://votre-api.com/upload',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer YOUR_TOKEN',
        },
      ),
    );

    if (response.statusCode == 200) {
      print('Upload réussi: ${response.data}');
    } else {
      throw Exception('Erreur upload: ${response.statusCode}');
    }
  } catch (e) {
    print('Erreur: $e');
    throw e;
  }
}
*/
