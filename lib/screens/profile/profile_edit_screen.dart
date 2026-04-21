import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/appwrite_service.dart';
import '../../widgets/common/user_avatar.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _selectedPhotoUrl;
  String? _initialPhotoUrl;
  String _initialName = '';

  final List<String> _preloadedAvatars = const [
    'assets/images/male-avatar 1.json',
    'assets/images/male-avatar 2.json',
    'assets/images/male-avatar 3.json',
    'assets/images/female-avatar 1.json',
    'assets/images/female-avatar 2.json',
    'assets/images/female-avatar 3.json',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _initialName = user?.name ?? '';
    _initialPhotoUrl = user?.photoUrl;
    _selectedPhotoUrl = user?.photoUrl;
    _nameCtrl.text = _initialName;
    _nameCtrl.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onFieldChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  bool get _hasPendingChanges {
    final normalizedName = _nameCtrl.text.trim();
    final currentPhoto = (_selectedPhotoUrl ?? '').trim();
    final initialPhoto = (_initialPhotoUrl ?? '').trim();
    return normalizedName != _initialName.trim() ||
        currentPhoto != initialPhoto;
  }

  Future<void> _selectPreloadedAvatar(String assetPath) async {
    setState(() {
      _selectedPhotoUrl = assetPath;
    });
  }

  Future<void> _pickAndUploadPhoto() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null) {
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null || !mounted) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPhotoUrl = photoUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Зураг амжилттай сонгогдлоо. Хадгалах товч дарж баталгаажуулна уу.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Зураг оруулахад алдаа гарлаа: $e\n\nСанамж: Appwrite Storage -> profile_photos bucket дээр Create эрх шалгана уу.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final newName = _nameCtrl.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Нэр хоосон байж болохгүй'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (!_hasPendingChanges) {
      return;
    }

    setState(() => _saving = true);
    try {
      await auth.updateProfile(name: newName, photoUrl: _selectedPhotoUrl);
      await auth.refreshProfile();

      if (!mounted) {
        return;
      }

      final refreshed = auth.user;
      setState(() {
        _initialName = refreshed?.name ?? newName;
        _initialPhotoUrl = refreshed?.photoUrl ?? _selectedPhotoUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Профайл амжилттай шинэчлэгдлээ'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final textTheme = Theme.of(context).textTheme;

    final previewName = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : (user?.name ?? 'Хэрэглэгч');
    final canSave = !_saving && !_uploadingPhoto && _hasPendingChanges;

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
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                if (_uploadingPhoto)
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else
                  UserAvatar(
                    photoUrl: _selectedPhotoUrl,
                    name: previewName,
                    isPremium: auth.hasPremium,
                    size: 112,
                  ),
                const SizedBox(height: 12),
                Text(
                  auth.hasPremium
                      ? 'Premium хүрээ идэвхтэй'
                      : 'Free хүрээ идэвхтэй',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Нэр',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textTertiary(context),
                      size: 20,
                    ),
                    hintText: 'Нэрээ оруулна уу',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary(context),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppColors.background(context),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Text(
                'Аватар сонгох',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: const Text('Өөр зураг оруулах'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _preloadedAvatars.map((path) {
              final isSelected = (_selectedPhotoUrl ?? '').trim() == path;
              return GestureDetector(
                onTap: () => _selectPreloadedAvatar(path),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceVariant(context),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(
                        scale: 1.45,
                        child: Lottie.asset(path, fit: BoxFit.cover),
                      ),
                      if (isSelected)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.only(right: 6, bottom: 6),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSave ? _saveProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textTertiary(
                  context,
                ).withValues(alpha: 0.24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Хадгалах',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
