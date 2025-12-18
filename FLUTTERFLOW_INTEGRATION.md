# 🎯 Intégration FlutterFlow

Guide complet pour intégrer le widget caméra dans votre projet FlutterFlow.

## 📋 Étapes d'Intégration

### 1. Ajouter le Widget Custom

1. Dans FlutterFlow, allez dans **Custom Code**
2. Cliquez sur **Widgets** puis **+ Add Widget**
3. Nommez le widget: `CameraWidget`
4. Copiez-collez le contenu de `camera_widget_improved.dart`

### 2. Configurer les Dépendances

Dans FlutterFlow, allez dans **Settings & Integrations** > **Project Dependencies** > **PubSpec Dependencies**:

```yaml
camera: 0.10.5
image_picker: 1.0.4
path_provider: 2.1.1
photo_manager: 2.8.0
flutter_image_compress: 2.1.0
google_mlkit_face_detection: 0.9.0
image: 4.1.3
```

### 3. Configuration Native iOS

Dans FlutterFlow, allez dans **Settings & Integrations** > **iOS Info.plist**:

```xml
<key>NSCameraUsageDescription</key>
<string>Nous avons besoin de la caméra pour prendre votre photo d'identité</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Nous avons besoin d'accéder à vos photos</string>
```

### 4. Configuration Native Android

Dans FlutterFlow, allez dans **Settings & Integrations** > **Android Manifest**:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### 5. Définir les Paramètres du Widget

Dans l'éditeur de Custom Widget, définissez les paramètres:

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `width` | double | Non | Largeur du widget (null = plein écran) |
| `height` | double | Non | Hauteur du widget (null = plein écran) |
| `uploadPhotosAction` | Future Function(List\<FFUploadedFile>?) | Oui | Callback quand photo capturée |

## 🎨 Utilisation dans FlutterFlow

### Scénario 1: Page Plein Écran

1. Créez une nouvelle page dans FlutterFlow
2. Ajoutez le widget **CameraWidget** sur la page
3. Ne définissez pas `width` et `height` (laissez null)
4. Configurez l'action `uploadPhotosAction`

**Action uploadPhotosAction**:
```
Custom Action
└─ Upload Photo to Firebase
   └─ Set State: photoURL
   └─ Navigate Back
```

### Scénario 2: Modal / Dialog

1. Créez un Bottom Sheet ou Dialog
2. Ajoutez le widget **CameraWidget**
3. Définissez `width` et `height` selon votre layout
4. Configurez l'action

### Scénario 3: Container dans Page

```
Column
├─ Text: "Prendre une photo"
├─ Container (height: 500)
│  └─ CameraWidget
│     ├─ height: 500
│     └─ uploadPhotosAction: Custom Action
└─ Button: "Retour"
```

## 🔧 Actions Personnalisées FlutterFlow

### Action: Upload Photo to Firebase

Créez une Custom Action dans FlutterFlow:

```dart
import 'package:firebase_storage/firebase_storage.dart';

Future<String?> uploadPhotoToFirebase(FFUploadedFile photo) async {
  try {
    final storageRef = FirebaseStorage.instance.ref();
    final photoRef = storageRef.child('photos/${photo.name}');

    // Upload
    await photoRef.putData(
      photo.bytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    // Obtenir l'URL
    final downloadURL = await photoRef.getDownloadURL();

    return downloadURL;
  } catch (e) {
    print('Erreur upload: $e');
    return null;
  }
}
```

### Action: Save Photo to App State

```dart
Future<void> savePhotoToAppState(
  FFUploadedFile photo,
  FFAppState appState,
) async {
  // Sauvegarder dans l'app state
  appState.update(() {
    appState.capturedPhotoBytes = photo.bytes;
    appState.capturedPhotoName = photo.name;
  });
}
```

### Action: Upload Photo to Custom API

```dart
import 'package:http/http.dart' as http;

Future<bool> uploadPhotoToAPI(
  FFUploadedFile photo,
  String apiUrl,
  String authToken,
) async {
  try {
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        photo.bytes!,
        filename: photo.name,
      ),
    );

    request.headers['Authorization'] = 'Bearer $authToken';

    var response = await request.send();

    return response.statusCode == 200;
  } catch (e) {
    print('Erreur upload API: $e');
    return false;
  }
}
```

## 📱 Exemple de Flow Complet

### Page: Home
```
Button "Prendre Photo d'Identité"
└─ Action: Navigate To
   └─ Page: CameraPage
```

### Page: CameraPage (Full Screen)
```
CameraWidget (plein écran)
└─ uploadPhotosAction:
   ├─ 1. Save Photo to App State
   ├─ 2. Show Snackbar "Photo capturée !"
   └─ 3. Navigate Back
```

### Page: Home (après retour)
```
Conditional Visibility (appState.capturedPhotoBytes != null)
├─ Image from Bytes: appState.capturedPhotoBytes
├─ Text: "Photo prête"
└─ Button "Confirmer et Uploader"
   └─ Action:
      ├─ 1. Show Loading Indicator
      ├─ 2. Upload Photo to Firebase
      ├─ 3. Save URL to Firestore
      ├─ 4. Hide Loading Indicator
      └─ 5. Navigate to Success Page
```

## 🎯 App State Recommandé

Créez ces variables dans votre **App State**:

| Variable | Type | Initial | Description |
|----------|------|---------|-------------|
| `capturedPhotoBytes` | DataType: Bytes | null | Données de la photo |
| `capturedPhotoName` | String | '' | Nom du fichier |
| `photoUploadURL` | String | '' | URL après upload |
| `isPhotoUploading` | bool | false | État upload |

## 🔔 Notifications à l'Utilisateur

### Snackbar Succès
```
Show Snackbar
├─ Message: "Photo capturée avec succès !"
├─ Background Color: #00E676
└─ Duration: 2 seconds
```

### Snackbar Erreur
```
Show Snackbar
├─ Message: "Positionnez votre visage correctement"
├─ Background Color: #FF5252
└─ Duration: 3 seconds
```

### Loading Indicator
```
Show Loading Indicator
└─ Message: "Traitement de la photo..."
```

## 🎨 Personnalisation Thème FlutterFlow

Le widget utilise automatiquement:
- Couleurs system (blanc, noir, gris)
- Feedback vert: `#00E676` pour succès
- Feedback orange: `Colors.orangeAccent` pour avertissements

Pour personnaliser, modifiez directement dans le code du widget.

## 📊 Analytics & Tracking

Ajoutez des événements dans vos actions:

```dart
// Dans uploadPhotosAction
Future<void> trackPhotoCapture(FFUploadedFile photo) async {
  // Firebase Analytics
  await FirebaseAnalytics.instance.logEvent(
    name: 'photo_captured',
    parameters: {
      'file_name': photo.name,
      'file_size': photo.bytes?.length ?? 0,
    },
  );

  // Mixpanel, Amplitude, etc.
  // ...
}
```

## 🐛 Debug dans FlutterFlow

### Mode Test
1. Activez le mode debug dans le widget (bouton 🐛)
2. Observez les métriques en temps réel
3. Capturez même si position incorrecte

### Logs
Les logs du widget apparaissent dans:
- FlutterFlow Test Mode Console
- Debug Console (lors du run)
- Xcode Console (iOS)
- Logcat (Android)

Recherchez les emojis: ✅ ❌ ⚠️ 📷 💡 🔄

## ⚠️ Limitations FlutterFlow

### Pas de Hot Reload pour Custom Widgets
Après modification du widget:
1. Sauvegardez
2. Arrêtez le test
3. Relancez le test

### Tester sur Appareil Réel
La caméra et ML Kit nécessitent un appareil physique:
- iOS: Testez via TestFlight ou Xcode
- Android: Testez via APK ou USB debugging

### Permissions en Test Mode
Les permissions peuvent ne pas fonctionner en Test Mode.
Testez en mode Production ou sur appareil.

## 🚀 Déploiement

### iOS
1. Vérifiez Info.plist dans **iOS Settings**
2. Activez Camera capability
3. Build via FlutterFlow ou Xcode

### Android
1. Vérifiez AndroidManifest.xml
2. Permissions CAMERA et READ_EXTERNAL_STORAGE
3. Build via FlutterFlow ou Android Studio

### Tests Recommandés
- ✅ Capture photo
- ✅ Changement caméra avant/arrière
- ✅ Flash on/off
- ✅ Sélection galerie
- ✅ App en arrière-plan
- ✅ Rotation appareil
- ✅ Upload réussi
- ✅ Gestion erreurs

## 💡 Astuces FlutterFlow

### 1. Utiliser un Dialog Modal
```
Button "Photo"
└─ Show Dialog
   └─ Type: Custom
      └─ Content: CameraWidget
         └─ height: MediaQuery.of(context).size.height * 0.8
```

### 2. Prévisualisation Avant Upload
```
uploadPhotosAction:
├─ 1. Save to App State
├─ 2. Navigate to Preview Page
└─ Preview Page:
   ├─ Image from appState
   ├─ Button "Retour" → Navigate Back to Camera
   └─ Button "Confirmer" → Upload
```

### 3. Plusieurs Photos (Collection)
```dart
// Custom Action
Future<void> addPhotoToCollection(
  FFUploadedFile photo,
  FFAppState appState,
) async {
  appState.update(() {
    appState.photoCollection.add(photo);
  });
}
```

### 4. Compression Personnalisée
Modifiez la fonction `compressImage` dans le widget:
```dart
quality: 85,  // Réduire pour plus de compression
minWidth: 600,  // Augmenter pour plus de qualité
```

### 5. Ratio Personnalisé
Modifiez la fonction `cropToIdentityFormat`:
```dart
const double targetRatio = 7 / 9;  // Changer selon besoin
// Ex: 1 / 1 pour carré, 16 / 9 pour paysage
```

## 📞 Support

Si problème dans FlutterFlow:
1. Vérifiez les dépendances (pubspec.yaml)
2. Vérifiez les permissions (iOS/Android config)
3. Testez sur appareil réel
4. Activez le mode debug
5. Consultez les logs avec emojis

## ✅ Checklist Intégration

- [ ] Widget ajouté dans Custom Code
- [ ] Dépendances ajoutées dans pubspec
- [ ] Info.plist configuré (iOS)
- [ ] AndroidManifest.xml configuré (Android)
- [ ] Custom Action upload créée
- [ ] App State défini
- [ ] Page caméra créée
- [ ] Navigation configurée
- [ ] Snackbars configurés
- [ ] Testé sur appareil réel iOS
- [ ] Testé sur appareil réel Android
- [ ] Cycle de vie testé (background/foreground)
- [ ] Upload testé avec succès
- [ ] Gestion erreurs testée

**Une fois cette checklist complétée, votre intégration est prête ! 🎉**
