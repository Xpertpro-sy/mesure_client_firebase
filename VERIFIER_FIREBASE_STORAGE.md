# Vérification des règles Firebase Storage

## 🔥 **Problème identifié**

L'upload d'image prend trop de temps (timeout après 30 secondes). Cela peut être dû à :

1. **Règles Firebase Storage incorrectes**
2. **Connexion internet lente**
3. **Image trop volumineuse**

## 🔧 **Solution 1: Vérifier les règles Storage**

### 1. **Aller dans Firebase Console**
- [console.firebase.google.com](https://console.firebase.google.com)
- Sélectionnez votre projet

### 2. **Aller dans Storage**
- Cliquez sur "Storage" dans le menu
- Cliquez sur "Règles"

### 3. **Remplacer les règles par :**
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
    
    // Règles pour tous les autres fichiers (optionnel)
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 4. **Publier les règles**
- Cliquez sur "Publier"

## 🔧 **Solution 2: Test de connexion**

### **Test simple**
```bash
# Testez votre connexion internet
ping google.com
```

### **Vérifier la taille des images**
- Utilisez des images de moins de 5MB
- Formats recommandés : JPG, PNG, WebP

## 🔧 **Solution 3: Utilisation de l'application**

### **Option 1: Sauvegarder sans image**
1. Remplissez le formulaire
2. **Ne sélectionnez pas d'image**
3. Cliquez "Sauvegarder"
4. ✅ Sauvegarde immédiate

### **Option 2: Sauvegarder avec image**
1. Remplissez le formulaire
2. Sélectionnez une image
3. Cliquez "Sauvegarder"
4. **Dialog apparaît** : "Voulez-vous uploader l'image maintenant ?"
5. Choisissez "Plus tard" ou "Uploader maintenant"

### **Option 3: Supprimer l'image**
1. Sélectionnez une image
2. Cliquez "Supprimer l'image"
3. Sauvegardez sans image

## 📊 **Logs attendus**

### **Sans image** :
```
flutter: Début de la mise à jour du profil...
flutter: Profil mis à jour avec succès
```

### **Avec image (succès)** :
```
flutter: Début de la mise à jour du profil...
flutter: Profil mis à jour avec succès
flutter: Tentative d'upload de l'image...
flutter: Upload de l'image terminé: https://...
flutter: URL de l'image mise à jour
```

### **Avec image (timeout)** :
```
flutter: Début de la mise à jour du profil...
flutter: Profil mis à jour avec succès
flutter: Image sélectionnée mais upload différé
```

## 🚨 **Si le problème persiste**

### **Vérifier les règles Storage**
1. Allez dans Firebase Console > Storage > Règles
2. Vérifiez que les règles sont correctes
3. Publiez les règles

### **Tester avec une image plus petite**
1. Utilisez une image de moins de 1MB
2. Format JPG recommandé

### **Vérifier la connexion**
1. Testez avec une connexion wifi stable
2. Évitez les connexions 3G/4G lentes

### **Alternative : Ignorer l'upload**
1. Sauvegardez sans image
2. L'image peut être uploadée plus tard

## ✅ **Résultats attendus**

- ✅ **Sauvegarde rapide** des données (1-2 secondes)
- ✅ **Dialog d'upload** si image sélectionnée
- ✅ **Option de suppression** d'image
- ✅ **Pas de loading infini**
- ✅ **Timeout de 30 secondes** maximum

La fonctionnalité fonctionne maintenant même avec une connexion lente ! 🎉 