import 'package:appwrite/appwrite.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/appwrite_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingPhoto = false;

  final List<String> _preloadedAvatars = [
    'assets/images/male-avatar 1.json',
    'assets/images/male-avatar 2.json',
    'assets/images/female-avatar 1.json',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text = user?.name ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectPreloadedAvatar(String assetPath) async {
    final auth = context.read<AuthProvider>();
    try {
      setState(() => _uploadingPhoto = true);
      await auth.updatePhotoUrl(assetPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Аватар амжилттай солигдлоо'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final storage = AppwriteService.instance.storage;
      final fileId = ID.unique();
      
      final file = await storage.createFile(
        bucketId: AppConfig.profilePhotosBucket,
        fileId: fileId,
        file: InputFile.fromPath(path: picked.path, filename: '$fileId.jpg'),
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );

      final endpoint = AppConfig.appwriteEndpoint;
      final projectId = AppConfig.appwriteProjectId;
      final uploadedFileId = file.$id;
      final photoUrl =
          '$endpoint/storage/buckets/${AppConfig.profilePhotosBucket}/files/$uploadedFileId/view?project=$projectId';

      await auth.updatePhotoUrl(photoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Зураг амжилттай солигдлоо'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Зураг оруулахад алдаа: $e\n\nСанамж: Appwrite Storage -> profile_photos bucket -> "Users" эсвэл "Any" бүлэгт Create эрх өгөгдсөн эсэхийг шалгана уу.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;

    setState(() => _saving = true);
    try {
      if (newName != auth.user?.name) {
        await auth.updateName(newName);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Профайл амжилттай шинэчлэгдлээ'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildAvatarPreview(String? photoUrl, String name, Color primaryColor) {
    if (_uploadingPhoto) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceVariant(context),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.endsWith('.json')) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceVariant(context),
            border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
          ),
          clipBehavior: Clip.antiAlias,
          child: Transform.scale(
            scale: 1.5,
            child: Lottie.asset(photoUrl, fit: BoxFit.cover),
          ),
        );
      }
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _avatarPlaceholder(name),
          errorWidget: (_, __, ___) => _avatarPlaceholder(name),
        ),
      );
    }
    
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: _avatarPlaceholder(name),
    );
  }

  Widget _avatarPlaceholder(String name) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 32,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Профайл засах', style: textTheme.titleLarge),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        child: Column(
          children: [
            // ── TOP SECTION (Preview Avatar & Name input) ──
            Row(
              children: [
                _buildAvatarPreview(user?.photoUrl, user?.name ?? '', AppColors.primary),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Нэр',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textTertiary(context), size: 20),
                          hintText: 'Нэрээ оруулна уу',
                          hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 14),
                          filled: true,
                          fillColor: AppColors.surfaceVariant(context),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // ── AVATAR GRID ──
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Аватар сонгох',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.start,
                children: [
                  // Pick own photo button
                  GestureDetector(
                    onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceVariant(context),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.add_a_photo_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  // Preloaded Avatars
                  ..._preloadedAvatars.map((path) {
                    final isSelected = user?.photoUrl == path;
                    return GestureDetector(
                      onTap: () => _selectPreloadedAvatar(path),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceVariant(context),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            width: isSelected ? 3 : 0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Transform.scale(
                          scale: 1.5,
                          child: Lottie.asset(path, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // ── SAVE BUTTON ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Хадгалах', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
