import 'package:flutter/material.dart';
import '../theme/cosmic_theme.dart';

/// Диалоговое окно с Политикой конфиденциальности приложения,
/// соответствующее требованиям Google Play Developer Policy и GDPR.
Future<void> showPrivacyPolicyDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF161A29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: CosmicTheme.goldAccent.withOpacity(0.4), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CosmicTheme.goldAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: CosmicTheme.goldAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Конфиденциальность',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, color: CosmicTheme.cyanAccent, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Приватность на первом месте (Privacy-First)',
                          style: TextStyle(
                            color: CosmicTheme.cyanAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '1. Какие данные мы собираем',
                  style: TextStyle(color: CosmicTheme.goldAccent, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Для персонализированного астрологического расчета гороскопа приложение обрабатывает:\n'
                  '• Имя или обращение (для персонального приветствия);\n'
                  '• Email (для авторизации, защиты профиля и восстановления доступа);\n'
                  '• Дату, время и город рождения (для построения натальной карты и расчета асцендента);\n'
                  '• Город текущего пребывания (для локальных транзитов планет);\n'
                  '• Привязку к Google или Telegram (по желанию пользователя).',
                  style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text(
                  '2. Защита и хранение данных',
                  style: TextStyle(color: CosmicTheme.goldAccent, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Все персональные данные и пароли хэшируются (SHA-256) и сохраняются в защищенном локальном хранилище устройства.\n'
                  '• Приложение НЕ передает ваши данные третьим лицам, рекламным сетям или брокерам данных.\n'
                  '• Доступ к Google или Email используется исключительно для аутентификации.',
                  style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text(
                  '3. Полное удаление аккаунта',
                  style: TextStyle(color: CosmicTheme.goldAccent, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Согласно правилам Google Play, вы имеете право в любой момент безвозвратно удалить свой аккаунт и все связанные персональные данные.\n'
                  'Это можно сделать прямо в приложении: вкладка «Настройки» → кнопка «Удалить аккаунт».',
                  style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text(
                  '4. Контакты службы поддержки',
                  style: TextStyle(color: CosmicTheme.goldAccent, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'По любым вопросам конфиденциальности и удаления данных:\n'
                  'Email: support@horoscope-for-all.ru\n'
                  'GitHub: olegsidorenco-byte/Horoscope-for-all-ru',
                  style: TextStyle(color: CosmicTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Понятно',
              style: TextStyle(
                color: CosmicTheme.goldAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      );
    },
  );
}
