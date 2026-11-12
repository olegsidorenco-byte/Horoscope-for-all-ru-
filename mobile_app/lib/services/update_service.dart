import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../ui/theme/cosmic_theme.dart';

class UpdateInfo {
  final String version;
  final String tag;
  final String downloadUrl;
  final String releaseUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.tag,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static const String currentVersion = '1.0.31';
  static const int currentBuildNumber = 31;

  static const String _prefLastCheckKey = 'last_update_check_epoch';
  static const String _prefDismissedKey = 'last_dismissed_update_version';

  static const MethodChannel _channel = MethodChannel('com.cosmic/background_service');

  /// Проверяет наличие новой версии приложения через Cloud Run, GitHub Raw и GitHub Releases API.
  static Future<UpdateInfo?> checkForUpdate({
    bool force = false,
    String lang = 'ru',
  }) async {
    // 1. Попытка через наш Cloud Run API
    try {
      final res = await http
          .get(Uri.parse('https://cosmic-horoscope-api-u7j7j2v2mq-ey.a.run.app/app/latest-version'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final v = (data['version'] ?? '').toString().trim();
        if (isNewerVersion(v, currentVersion)) {
          final notesMap = data['release_notes'];
          String notes = '';
          if (notesMap is Map) {
            notes = (notesMap[lang] ?? notesMap['ru'] ?? notesMap['en'] ?? '').toString();
          } else if (notesMap is String) {
            notes = notesMap;
          }
          return UpdateInfo(
            version: v,
            tag: (data['tag'] ?? 'app-v$v').toString(),
            downloadUrl: (data['download_url'] ??
                    'https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/download/app-v$v/Horoscope-for-all-ru.apk')
                .toString(),
            releaseUrl: (data['release_url'] ??
                    'https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/tag/app-v$v')
                .toString(),
            releaseNotes: notes,
          );
        } else {
          return null; // Установлена актуальная версия
        }
      }
    } catch (_) {}

    // 2. Резервная проверка через GitHub raw version.json
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final rawUrl = Uri.parse(
          'https://raw.githubusercontent.com/olegsidorenco-byte/Horoscope-for-all-ru-/main/version.json?t=$cacheBuster');
      final res = await http.get(rawUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final v = (data['version'] ?? '').toString().trim();
        if (isNewerVersion(v, currentVersion)) {
          final notesMap = data['release_notes'];
          String notes = '';
          if (notesMap is Map) {
            notes = (notesMap[lang] ?? notesMap['ru'] ?? notesMap['en'] ?? '').toString();
          } else if (notesMap is String) {
            notes = notesMap;
          }
          return UpdateInfo(
            version: v,
            tag: (data['tag'] ?? 'app-v$v').toString(),
            downloadUrl: (data['download_url'] ??
                    'https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/download/app-v$v/Horoscope-for-all-ru.apk')
                .toString(),
            releaseUrl: (data['release_url'] ??
                    'https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/tag/app-v$v')
                .toString(),
            releaseNotes: notes,
          );
        } else {
          return null;
        }
      }
    } catch (_) {}

    // 3. Резервная проверка напрямую через GitHub Releases API
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/olegsidorenco-byte/Horoscope-for-all-ru-/releases/latest'),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'HoroscopeApp',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final tag = (data['tag_name'] ?? '').toString();
        final v = tag.replaceFirst('app-v', '').replaceFirst('v', '').trim();

        if (isNewerVersion(v, currentVersion)) {
          String apkUrl =
              'https://github.com/olegsidorenco-byte/Horoscope-for-all-ru-/releases/latest/download/Horoscope-for-all-ru.apk';
          final assets = data['assets'];
          if (assets is List) {
            for (final a in assets) {
              if (a is Map && (a['name'] ?? '').toString().endsWith('.apk')) {
                apkUrl = (a['browser_download_url'] ?? apkUrl).toString();
                break;
              }
            }
          }

          return UpdateInfo(
            version: v,
            tag: tag,
            downloadUrl: apkUrl,
            releaseUrl: (data['html_url'] ?? '').toString(),
            releaseNotes: (data['body'] ?? '').toString(),
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Сравнивает семантические версии (например, "1.0.31" против "1.0.30")
  static bool isNewerVersion(String remote, String current) {
    if (remote.isEmpty) return false;
    final rClean = remote.replaceFirst('app-v', '').replaceFirst('v', '').trim();
    final cClean = current.replaceFirst('app-v', '').replaceFirst('v', '').trim();
    if (rClean == cClean) return false;

    final rParts = rClean.split(RegExp(r'[.\-+]')).map((s) => int.tryParse(s) ?? 0).toList();
    final cParts = cClean.split(RegExp(r'[.\-+]')).map((s) => int.tryParse(s) ?? 0).toList();

    final maxLen = rParts.length > cParts.length ? rParts.length : cParts.length;
    for (int i = 0; i < maxLen; i++) {
      final rVal = i < rParts.length ? rParts[i] : 0;
      final cVal = i < cParts.length ? cParts[i] : 0;
      if (rVal > cVal) return true;
      if (rVal < cVal) return false;
    }
    return false;
  }

  /// Открывает ссылку на скачивание APK в браузере смартфона
  static Future<bool> launchDownload(String url) async {
    try {
      final res = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Фоновая проверка обновлений при старте приложения (не чаще 1 раза в 6 часов)
  static Future<void> checkSilentlyOnStartup(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_prefLastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Ограничиваем частоту проверок
      if (now - lastCheck < const Duration(hours: 4).inMilliseconds) {
        return;
      }
      await prefs.setInt(_prefLastCheckKey, now);

      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      final update = await checkForUpdate(lang: l10n.langCode);

      if (update != null && context.mounted) {
        final dismissed = prefs.getString(_prefDismissedKey);
        if (dismissed == update.version) {
          return; // Пользователь уже нажал "Позже" для этой конкретной версии
        }
        await showUpdateDialog(context, update);
      }
    } catch (_) {}
  }

  /// Показывает диалоговое окно обновления в космическом стиле
  static Future<void> showUpdateDialog(
    BuildContext context,
    UpdateInfo info, {
    bool isManual = false,
  }) async {
    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2032),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: CosmicTheme.goldAccent.withOpacity(0.4), width: 1.2),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CosmicTheme.goldAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: CosmicTheme.goldAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.updateAvailableTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: CosmicTheme.backgroundDeep,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('v$currentVersion',
                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, color: CosmicTheme.goldAccent, size: 14),
                  const SizedBox(width: 6),
                  Text('v${info.version}',
                      style: const TextStyle(color: CosmicTheme.goldAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.updateAvailableDesc(info.version),
              style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141824),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_prefDismissedKey, info.version);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              l10n.remindLaterButton,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: CosmicTheme.goldAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await launchDownload(info.downloadUrl);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(
              l10n.downloadUpdateButton,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
