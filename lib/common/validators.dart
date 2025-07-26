class Validators {
  /// Valide un nom (prénom ou nom de famille)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ce champ est requis';
    }
    
    if (value.trim().length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }
    
    if (value.trim().length > 50) {
      return 'Le nom ne peut pas dépasser 50 caractères';
    }
    
    // Vérifier que le nom ne contient que des lettres, espaces et tirets
    final RegExp nameRegex = RegExp(r'^[a-zA-ZÀ-ÿ\s\-]+$');
    if (!nameRegex.hasMatch(value.trim())) {
      return 'Le nom ne peut contenir que des lettres, espaces et tirets';
    }
    
    return null;
  }

  /// Valide un numéro de téléphone
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le numéro de téléphone est requis';
    }
    
    // Nettoyer le numéro (supprimer espaces, tirets, parenthèses)
    final String cleanNumber = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Vérifier que c'est un numéro malien valide
    // Format: +223 XX XX XX XX ou 223 XX XX XX XX
    final RegExp phoneRegex = RegExp(r'^(?:\+?223|00223)?\s*[67]\d{1}\s*\d{2}\s*\d{2}\s*\d{2}$');
    
    if (!phoneRegex.hasMatch(cleanNumber)) {
      return 'Veuillez entrer un numéro de téléphone malien valide (ex: +223 78 71 16 23)';
    }
    
    return null;
  }

  /// Formate un numéro de téléphone pour l'affichage
  static String formatPhoneNumber(String phoneNumber) {
    // Nettoyer le numéro
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Si le numéro commence par +223, le garder tel quel
    if (cleanNumber.startsWith('+223')) {
      cleanNumber = cleanNumber.substring(4); // Enlever le +223
    }
    
    // Si le numéro commence par 00223, le convertir
    if (cleanNumber.startsWith('00223')) {
      cleanNumber = cleanNumber.substring(5); // Enlever le 00223
    }
    
    // Si le numéro commence par 223, le convertir
    if (cleanNumber.startsWith('223')) {
      cleanNumber = cleanNumber.substring(3); // Enlever le 223
    }
    
    // Formater le numéro malien (format: +223 XX XX XX XX)
    if (cleanNumber.length == 8 && (cleanNumber.startsWith('6') || cleanNumber.startsWith('7'))) {
      return '+223 ${cleanNumber.substring(0, 2)} ${cleanNumber.substring(2, 4)} ${cleanNumber.substring(4, 6)} ${cleanNumber.substring(6)}';
    }
    
    return phoneNumber;
  }

  /// Valide une URL d'image
  static String? validateImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // URL optionnelle
    }
    
    try {
      final Uri uri = Uri.parse(value.trim());
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return 'L\'URL doit commencer par http:// ou https://';
      }
      
      // Vérifier que l'URL se termine par une extension d'image
      final String path = uri.path.toLowerCase();
      final List<String> validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
      final bool hasValidExtension = validExtensions.any((ext) => path.endsWith(ext));
      
      if (!hasValidExtension) {
        return 'L\'URL doit pointer vers une image (jpg, jpeg, png, gif, webp)';
      }
      
      return null;
    } catch (e) {
      return 'URL invalide';
    }
  }

  /// Valide la taille d'un fichier image
  static String? validateImageFileSize(int fileSizeInBytes) {
    const int maxSizeInBytes = 5 * 1024 * 1024; // 5MB
    
    if (fileSizeInBytes > maxSizeInBytes) {
      return 'L\'image est trop volumineuse. Taille maximale: 5MB';
    }
    
    return null;
  }

  /// Valide les dimensions d'une image
  static String? validateImageDimensions(int width, int height) {
    const int minWidth = 100;
    const int minHeight = 100;
    const int maxWidth = 4096;
    const int maxHeight = 4096;
    
    if (width < minWidth || height < minHeight) {
      return 'L\'image est trop petite. Dimensions minimales: 100x100 pixels';
    }
    
    if (width > maxWidth || height > maxHeight) {
      return 'L\'image est trop grande. Dimensions maximales: 4096x4096 pixels';
    }
    
    return null;
  }

  /// Formate la taille d'un fichier en format lisible
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Valide un email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'email est requis';
    }
    
    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );
    
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Veuillez entrer un email valide';
    }
    
    return null;
  }

  /// Nettoie et normalise un nom
  static String normalizeName(String name) {
    if (name.trim().isEmpty) return '';
    
    // Nettoyer les espaces multiples et normaliser
    String normalized = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Capitaliser chaque mot
    List<String> words = normalized.split(' ');
    List<String> capitalizedWords = words.map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();
    
    return capitalizedWords.join(' ');
  }
} 