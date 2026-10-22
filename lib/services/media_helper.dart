import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum CropPresetType {
  eventBanner, // 16:9 landscape
  avatar, // 1:1 square / circle
}

/// Reusable media helper supporting Camera & Gallery image picking + cropping
class MediaHelper {
  MediaHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// Pick and crop an image with aspect ratio preset (16:9 for event banner, 1:1 for avatar)
  static Future<String?> pickAndCropImage(
    BuildContext context, {
    required CropPresetType cropType,
    ImageSource? source,
  }) async {
    ImageSource? chosenSource = source;

    chosenSource ??= await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cropType == CropPresetType.avatar
                      ? 'Change Profile Photo'
                      : 'Upload Event Banner',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cropType == CropPresetType.avatar
                      ? 'Choose a photo for your organizer profile (1:1)'
                      : 'Choose a wide cover banner for your event (16:9)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.accentLime.withValues(alpha: 0.15)
                          : AppTheme.primaryPurple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                    ),
                  ),
                  title: Text(
                    'Take Photo',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.accentLime.withValues(alpha: 0.15)
                          : AppTheme.primaryPurple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: isDark ? AppTheme.accentLime : AppTheme.primaryPurple,
                    ),
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );

    if (chosenSource == null) return null;

    try {
      final pickedFile = await _picker.pickImage(
        source: chosenSource,
        maxWidth: cropType == CropPresetType.eventBanner ? 1920 : 800,
        maxHeight: cropType == CropPresetType.eventBanner ? 1080 : 800,
        imageQuality: 88,
      );

      if (pickedFile == null) return null;

      // On Web or non-mobile platforms where image_cropper isn't native, return picked path directly
      if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
        return pickedFile.path;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: cropType == CropPresetType.eventBanner
            ? const CropAspectRatio(ratioX: 16, ratioY: 9)
            : const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: cropType == CropPresetType.eventBanner ? 'Crop Event Cover' : 'Crop Profile Avatar',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            statusBarLight: false,
            activeControlsWidgetColor: const Color(0xFFD4E79E),
            initAspectRatio: cropType == CropPresetType.eventBanner
                ? CropAspectRatioPreset.ratio16x9
                : CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: cropType == CropPresetType.eventBanner ? 'Crop Event Cover' : 'Crop Avatar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      return croppedFile?.path ?? pickedFile.path;
    } catch (e) {
      debugPrint('[MEDIA_HELPER] Error picking/cropping image: $e');
      return null;
    }
  }
}
