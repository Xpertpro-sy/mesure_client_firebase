import 'package:flutter/material.dart';
import '../model/user_model.dart';

class ProfileInfoWidget extends StatelessWidget {
  final UserModel? user;
  final VoidCallback? onEditPressed;
  final bool isLoading;

  const ProfileInfoWidget({
    super.key,
    this.user,
    this.onEditPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildProfileImage(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserName(),
                    const SizedBox(height: 4),
                    _buildUserEmail(),
                    const SizedBox(height: 8),
                    _buildUserPhone(),
                  ],
                ),
              ),
              if (onEditPressed != null)
                IconButton(
                  onPressed: isLoading ? null : onEditPressed,
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    shape: const CircleBorder(),
                  ),
                ),
            ],
          ),
          if (user != null && user!.hasCompleteProfile) ...[
            const SizedBox(height: 16),
            _buildProfileCompletionIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: ClipOval(
        child: user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty
            ? Image.network(
                user!.profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatar();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey.shade100,
      child: const Icon(
        Icons.person,
        size: 30,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildUserName() {
    return Text(
      user?.fullName ?? 'Utilisateur',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildUserEmail() {
    return Text(
      user?.email ?? 'email@example.com',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildUserPhone() {
    final phone = user?.phoneNumber;
    if (phone == null || phone.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.phone_outlined,
            size: 16,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 4),
          Text(
            'Aucun numéro',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.phone_outlined,
          size: 16,
          color: Colors.green.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          phone,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCompletionIndicator() {
    final completionPercentage = _calculateCompletionPercentage();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Profil complet',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              '${completionPercentage.round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: completionPercentage >= 100 
                    ? Colors.green.shade600 
                    : Colors.orange.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: completionPercentage / 100,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            completionPercentage >= 100 
                ? Colors.green.shade600 
                : Colors.orange.shade600,
          ),
        ),
      ],
    );
  }

  double _calculateCompletionPercentage() {
    if (user == null) return 0;
    
    int completedFields = 0;
    int totalFields = 4; // firstName, lastName, phoneNumber, profileImageUrl
    
    if (user!.firstName?.isNotEmpty == true) completedFields++;
    if (user!.lastName?.isNotEmpty == true) completedFields++;
    if (user!.phoneNumber?.isNotEmpty == true) completedFields++;
    if (user!.profileImageUrl?.isNotEmpty == true) completedFields++;
    
    return (completedFields / totalFields) * 100;
  }
} 