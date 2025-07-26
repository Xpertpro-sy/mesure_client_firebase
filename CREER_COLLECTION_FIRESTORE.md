# Comment créer la collection `users` dans Firestore

## 🎯 **Méthode la plus simple (Recommandée)**

### 1. **Lancer l'application**
```bash
flutter run
```

### 2. **Se connecter et aller dans Profil**
- Connectez-vous à l'application
- Allez dans la page "Profil"
- La collection sera créée automatiquement

## 🔥 **Méthode manuelle via Console Firebase**

### 1. **Accéder à Firebase Console**
- Allez sur [console.firebase.google.com](https://console.firebase.google.com)
- Sélectionnez votre projet

### 2. **Aller dans Firestore**
- Cliquez sur "Firestore Database" dans le menu
- Si c'est la première fois, cliquez sur "Créer une base de données"

### 3. **Créer la collection**
1. Cliquez sur "Démarrer en mode test" (temporairement)
2. Cliquez sur "Créer une collection"
3. Nom de la collection : `users`
4. ID du document : `test` (temporaire)
5. Ajoutez ces champs :

| Champ | Type | Valeur |
|-------|------|--------|
| `email` | string | `test@example.com` |
| `firstName` | string | `null` |
| `lastName` | string | `null` |
| `phoneNumber` | string | `null` |
| `profileImageUrl` | string | `null` |
| `createdAt` | timestamp | `now` |
| `updatedAt` | timestamp | `now` |

### 4. **Supprimer le document de test**
- Une fois créé, supprimez le document `test`

## 🔧 **Méthode programmatique**

L'application inclut maintenant un service qui crée automatiquement la collection :

```dart
// Dans profil_page.dart
final FirestoreInitializer _firestoreInitializer = FirestoreInitializer();

// La collection est créée automatiquement lors du chargement
await _firestoreInitializer.initializeFirestore();
await _firestoreInitializer.createUserIfNotExists();
```

## 📋 **Structure de la collection**

### Collection : `users`
### Document ID : `{userId}` (ID de l'utilisateur Firebase Auth)

```json
{
  "email": "user@example.com",
  "firstName": "Prénom",
  "lastName": "Nom",
  "phoneNumber": "+223 78 71 16 23",
  "profileImageUrl": "https://...",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

## 🔒 **Règles de sécurité**

Assurez-vous d'avoir ces règles dans Firestore :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
  }
}
```

## ✅ **Vérification**

Pour vérifier que la collection est créée :

1. **Dans la console Firebase** : Firestore Database → Collection `users`
2. **Dans l'application** : Profil → Modifier le profil → Sauvegarder
3. **Logs** : Vérifiez les logs pour voir "Collection users créée avec succès"

## 🚨 **Problèmes courants**

### Erreur "Permission denied"
- Vérifiez que les règles Firestore sont correctes
- Assurez-vous que l'utilisateur est connecté

### Collection ne se crée pas
- Vérifiez la connexion internet
- Vérifiez que Firebase est bien configuré
- Redémarrez l'application

### Erreur de compilation
```bash
flutter clean
flutter pub get
flutter run
```

## 🎯 **Test rapide**

1. Lancez l'application : `flutter run`
2. Connectez-vous
3. Allez dans Profil
4. Vérifiez les logs : "Collection users créée avec succès"
5. Vérifiez dans Firebase Console que la collection existe

La collection sera créée automatiquement lors de la première utilisation ! 🎉 