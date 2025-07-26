# Guide de résolution des problèmes

## 🔧 **Problème 1: MissingPluginException pour flutter_image_compress**

### Symptômes
```
MissingPluginException(No implementation found for method compressWithFile on channel flutter_image_compress)
```

### Solutions

#### 1. **Redémarrage complet de l'application**
```bash
flutter clean
flutter pub get
flutter run
```

#### 2. **Vérification des dépendances**
Assurez-vous que `flutter_image_compress` est bien dans `pubspec.yaml`:
```yaml
dependencies:
  flutter_image_compress: ^2.1.0
```

#### 3. **Utilisation de la version alternative**
Si le problème persiste, l'application utilise automatiquement `StorageServiceAlternative` qui ne dépend pas de `flutter_image_compress`.

## 🔧 **Problème 2: Permission denied pour Firestore**

### Symptômes
```
[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

### Solutions

#### 1. **Mettre à jour les règles Firestore**
Copiez ces règles dans votre console Firebase > Firestore > Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Règles pour les mesures
    match /measurements/{id} {
      allow create: if request.auth != null 
        && request.auth.uid == request.resource.data.userId;
      
      allow update: if request.auth != null 
        && request.auth.uid == resource.data.userId;
      
      allow delete: if request.auth != null 
        && request.auth.uid == resource.data.userId;
      
      allow read: if request.auth != null 
        && request.auth.uid == resource.data.userId;
    }

    // Règles pour les configurations
    match /measurement_configs/{userId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }

    // Règles pour les utilisateurs
    match /users/{userId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
  }
}
```

#### 2. **Vérifier l'authentification**
Assurez-vous que l'utilisateur est bien connecté avant d'essayer d'accéder à Firestore.

#### 3. **Créer la collection manuellement (optionnel)**
Si la collection `users` n'existe pas, vous pouvez la créer manuellement dans la console Firebase.

## 🔧 **Problème 3: Erreurs de compilation**

### Solutions

#### 1. **Nettoyer le cache**
```bash
flutter clean
flutter pub get
```

#### 2. **Redémarrer l'IDE**
Fermez et rouvrez votre IDE (VS Code, Android Studio, etc.)

#### 3. **Vérifier les imports**
Assurez-vous que tous les fichiers sont correctement importés.

## 🔧 **Problème 4: Images qui ne s'affichent pas**

### Solutions

#### 1. **Vérifier les règles Firebase Storage**
Ajoutez ces règles dans Firebase Storage:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_images/{imageId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
        && request.resource.size < 5 * 1024 * 1024
        && request.resource.contentType.matches('image/.*');
    }
  }
}
```

#### 2. **Vérifier la connexion internet**
Assurez-vous d'avoir une connexion internet stable.

## 🔧 **Problème 5: Validation des numéros de téléphone**

### Format attendu pour le Mali
- ✅ `+223 78 71 16 23`
- ✅ `223 78 71 16 23`
- ✅ `78711623`
- ❌ `+223 12 34 56 78` (commence par 1 au lieu de 6 ou 7)

## 🔧 **Problème 6: Performance lente**

### Solutions

#### 1. **Optimiser les images**
- Utilisez des images de taille raisonnable (< 5MB)
- Le format WebP est recommandé

#### 2. **Vérifier la connexion**
- Testez avec une connexion wifi stable
- Évitez les connexions 3G/4G lentes

## 🔧 **Problème 7: L'application ne démarre pas**

### Solutions

#### 1. **Vérifier les dépendances**
```bash
flutter doctor
flutter pub deps
```

#### 2. **Vérifier la configuration Firebase**
- Assurez-vous que `google-services.json` (Android) et `GoogleService-Info.plist` (iOS) sont présents
- Vérifiez que le projet Firebase est correctement configuré

#### 3. **Logs détaillés**
```bash
flutter run --verbose
```

## 📞 **Support**

Si les problèmes persistent :

1. **Vérifiez les logs** dans la console de débogage
2. **Testez sur un émulateur** différent
3. **Vérifiez la documentation Firebase**
4. **Consultez les forums Flutter**

## 🎯 **Tests recommandés**

### Test de base
1. Ouvrir l'application
2. Se connecter
3. Aller dans Profil
4. Cliquer sur "Modifier le profil"
5. Tester la sélection d'image
6. Tester la validation des champs
7. Sauvegarder

### Test de validation
1. Entrer un nom invalide (trop court)
2. Entrer un numéro de téléphone invalide
3. Sélectionner une image trop volumineuse
4. Vérifier que les messages d'erreur s'affichent

### Test de sauvegarde
1. Remplir tous les champs correctement
2. Sauvegarder
3. Vérifier que les données sont bien enregistrées dans Firestore
4. Vérifier que l'image est uploadée dans Storage 