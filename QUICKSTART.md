# ⚡ Quick Start - 5 Minutes

Guide ultra-rapide pour démarrer avec le widget caméra photo d'identité.

## 🎯 Ce Dont Vous Avez Besoin

- ✅ Projet Flutter ou FlutterFlow
- ✅ iOS 11.0+ ou Android API 21+
- ✅ Appareil physique (pas d'émulateur pour caméra)

## 🚀 Installation en 3 Étapes

### 1️⃣ Copier le Widget (30 secondes)

**Flutter Standard**:
```bash
cp camera_widget_improved.dart your_project/lib/widgets/
```

**FlutterFlow**:
1. Custom Code → Widgets → + Add Widget
2. Nom: `CameraWidget`
3. Copier-coller le contenu de `camera_widget_improved.dart`

### 2️⃣ Ajouter les Dépendances (1 minute)

**Flutter Standard** - Dans `pubspec.yaml`:
```yaml
dependencies:
  camera: ^0.10.5
  image_picker: ^1.0.4
  path_provider: ^2.1.1
  photo_manager: ^2.8.0
  flutter_image_compress: ^2.1.0
  google_mlkit_face_detection: ^0.9.0
  image: ^4.1.3
```

Puis:
```bash
flutter pub get
```

**FlutterFlow**:
Settings → Project Dependencies → PubSpec Dependencies
Copiez les mêmes lignes (sans le `dependencies:`)

### 3️⃣ Configurer les Permissions (2 minutes)

**iOS** - Dans `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Pour prendre votre photo d'identité</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Pour sélectionner une photo</string>
```

**Android** - Dans `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

**FlutterFlow**:
- iOS: Settings → iOS Info.plist (coller le XML)
- Android: Settings → Android Manifest (coller le XML)

## ✨ Utilisation (1 minute)

### Code Minimal

```dart
import 'package:flutter/material.dart';
import 'camera_widget_improved.dart';

class PhotoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CameraWidget(
        uploadPhotosAction: (photos) async {
          if (photos != null && photos.isNotEmpty) {
            final photo = photos.first;
            print('Photo: ${photo.name}, ${photo.bytes?.length} bytes');

            // TODO: Votre logique (upload, sauvegarde, etc.)

            Navigator.pop(context); // Retour
          }
        },
      ),
    );
  }
}
```

### Appeler depuis un Bouton

```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PhotoPage()),
    );
  },
  child: Text('Prendre une photo'),
)
```

## 🎨 Dans FlutterFlow

### Configurer le Widget

1. Ajouter `CameraWidget` sur une page
2. Ne pas définir `width` et `height` (plein écran)
3. Configurer `uploadPhotosAction`:
   - Ajouter Custom Action
   - Exemple: `savePhotoToAppState(photos[0])`

### Custom Action Exemple

Créer dans FlutterFlow:

```dart
import '/flutter_flow/flutter_flow_util.dart';

Future<void> savePhotoToAppState(
  List<FFUploadedFile>? photos,
  FFAppState appState,
) async {
  if (photos != null && photos.isNotEmpty) {
    final photo = photos.first;
    appState.update(() {
      appState.capturedPhoto = photo.bytes;
    });
  }
}
```

## ✅ Test Rapide

### 1. Lancer l'App

```bash
flutter run
# ou
# Build & Test dans FlutterFlow
```

### 2. Vérifier que ça Fonctionne

Testez dans cet ordre:
- [ ] La caméra s'ouvre
- [ ] Le visage est détecté (cercle apparaît)
- [ ] Feedback change selon position
- [ ] "Parfait !" en vert quand bien positionné
- [ ] Capture fonctionne (bouton vert)
- [ ] Photo apparaît dans votre app

### 3. Tester les Fonctions

- [ ] Bouton galerie (en bas à gauche)
- [ ] Switch caméra (en haut à droite)
- [ ] Flash (si caméra arrière)
- [ ] Mode debug (bouton 🐛)

## 🐛 Problèmes Courants

### Caméra ne s'ouvre pas
→ Vérifiez les permissions dans Info.plist / AndroidManifest.xml

### "Package not found"
→ Lancez `flutter pub get` ou vérifiez les dépendances FlutterFlow

### Pas de détection
→ Normal sur émulateur, testez sur appareil réel

### Build error "camera"
→ Vérifiez la version: `camera: ^0.10.5`

### Build error iOS
→ Vérifiez Info.plist, minimum iOS 11.0 dans Podfile

## 💡 Prochaines Étapes

Maintenant que ça fonctionne:

1. **Personnaliser**: Voir README.md section "Personnalisation"
2. **Uploader**: Ajouter votre logique d'upload (Firebase, API, etc.)
3. **Affiner**: Ajuster la calibration si besoin
4. **Déployer**: Tester en production

## 📚 Documentation Complète

- **README.md**: Guide complet avec tous les détails
- **IMPROVEMENTS.md**: Liste des 13 améliorations
- **FLUTTERFLOW_INTEGRATION.md**: Guide spécifique FlutterFlow
- **MIGRATION_GUIDE.md**: Si vous migrez depuis v1.0
- **example/main.dart**: Exemple d'app complète

## 🎉 C'est Tout !

Vous êtes prêt ! Le widget est:
- ✅ Thread-safe
- ✅ Production-ready
- ✅ Optimisé performance
- ✅ Compatible tous appareils

**Temps total: 5 minutes**
**Difficulté: Facile**
**Résultat: Professionnel**

---

## 🚀 Commandes Utiles

```bash
# Flutter clean si problème
flutter clean && flutter pub get

# Build iOS
flutter build ios

# Build Android
flutter build apk

# Voir les logs
flutter logs

# Test sur appareil
flutter run --release
```

## 📱 Test Checklist Finale

Avant de déployer:

- [ ] Testé sur iPhone réel
- [ ] Testé sur Android réel
- [ ] Capture photo fonctionne
- [ ] Upload fonctionne
- [ ] App en background OK
- [ ] Rotation appareil OK
- [ ] Flash fonctionne (caméra arrière)
- [ ] Galerie fonctionne
- [ ] Pas de crash

**Tout coché ? Go production ! 🚀**

---

**Need help?**
- 🐛 Activez le mode debug (bouton 🐛)
- 📝 Consultez README.md
- 💬 Vérifiez les logs avec emojis

**Happy coding! 🎉**
