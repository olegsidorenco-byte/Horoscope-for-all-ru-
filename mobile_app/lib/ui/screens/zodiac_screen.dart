import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/zodiac_model.dart';
import '../../services/horoscope_sync_service.dart';
import '../../services/storage_service.dart';
import '../theme/cosmic_theme.dart';
import '../widgets/cosmic_background.dart';

class ZodiacScreen extends StatefulWidget {
  final String? initialSignId;

  const ZodiacScreen({super.key, this.initialSignId});

  @override
  State<ZodiacScreen> createState() => _ZodiacScreenState();
}

class _ZodiacScreenState extends State<ZodiacScreen> {
  ZodiacDayData? _zodiacData;
  bool _isLoading = false;
  String? _errorMessage;

  String _selectedElement = 'Все';
  String _activeSignId = 'aries';

  final List<String> _elements = ['Все', 'Огонь', 'Земля', 'Воздух', 'Вода'];

  @override
  void initState() {
    super.initState();
    if (widget.initialSignId != null) {
      _activeSignId = widget.initialSignId!;
    }
    _loadZodiacData();
  }

  Future<void> _loadZodiacData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final savedSign = await StorageService.getSelectedZodiacSign();
      if (widget.initialSignId == null) {
        _activeSignId = savedSign;
      }

      final data = await HoroscopeSyncService.fetchLatestZodiac(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _zodiacData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSignSelected(String signId) {
    setState(() {
      _activeSignId = signId;
    });
    StorageService.setSelectedZodiacSign(signId);
  }

  List<ZodiacSign> get _filteredSigns {
    if (_zodiacData == null) return [];
    if (_selectedElement == 'Все') return _zodiacData!.signs;
    return _zodiacData!.signs
        .where((s) => s.element.toLowerCase() == _selectedElement.toLowerCase())
        .toList();
  }

  ZodiacSign? get _activeSign {
    if (_zodiacData == null || _zodiacData!.signs.isEmpty) return null;
    return _zodiacData!.signs.firstWhere(
      (s) => s.id == _activeSignId,
      orElse: () => _zodiacData!.signs.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Гороскоп по знакам'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CosmicTheme.goldAccent),
                  )
                : const Icon(Icons.refresh_rounded, color: CosmicTheme.cyanAccent),
            tooltip: 'Обновить прогноз знаков',
            onPressed: () => _loadZodiacData(forceRefresh: true),
          ),
        ],
      ),
      body: CosmicBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _zodiacData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: CosmicTheme.goldAccent),
            SizedBox(height: 16),
            Text(
              'Загрузка гороскопа по 12 знакам...',
              style: TextStyle(color: CosmicTheme.goldSoft),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _zodiacData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: CosmicTheme.roseGlow, size: 54),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CosmicTheme.textPrimary, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _loadZodiacData(forceRefresh: true),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final active = _activeSign;

    return RefreshIndicator(
      color: CosmicTheme.goldAccent,
      backgroundColor: CosmicTheme.backgroundCard,
      onRefresh: () => _loadZodiacData(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Фильтры по стихиям (Ряд 1: кнопка "Все знаки", Ряд 2: 4 стихии)
          _buildElementFilterChips(),
          const SizedBox(height: 12),

          // Ряд 3: Селектор всех 12 знаков в 2 ряда по 6 кнопок (аналогично главной странице)
          _buildZodiacGridSelector(),
          const SizedBox(height: 16),

          // Большая карточка активного знака
          if (active != null) _buildActiveHeroCard(active),
          const SizedBox(height: 20),

          // Список всех остальных знаков
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              'Все знаки зодиака (${_filteredSigns.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CosmicTheme.textPrimary,
              ),
            ),
          ),
          ..._filteredSigns.map((sign) => _buildSignCompactTile(sign)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildElementFilterChips() {
    final isAllSelected = _selectedElement == 'Все';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 1. Верхняя кнопка "Все 12 знаков зодиака" по всей ширине экрана с идеальным центрированием
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedElement = 'Все';
              });
            },
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: isAllSelected
                    ? CosmicTheme.goldAccent
                    : const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isAllSelected ? CosmicTheme.goldAccent : Colors.white24,
                  width: 1.2,
                ),
                boxShadow: isAllSelected
                    ? [
                        BoxShadow(
                          color: CosmicTheme.goldAccent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 17,
                    color: isAllSelected ? Colors.black : CosmicTheme.goldAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Все 12 знаков зодиака',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isAllSelected ? Colors.black : Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. 4 кнопки стихий в одну строку на всю ширину экрана
          Row(
            children: [
              _buildElementButton('Огонь', const Color(0xFFE76F51), Icons.local_fire_department_rounded),
              const SizedBox(width: 6),
              _buildElementButton('Земля', const Color(0xFF2A9D8F), Icons.eco_rounded),
              const SizedBox(width: 6),
              _buildElementButton('Воздух', const Color(0xFFE9C46A), Icons.air_rounded),
              const SizedBox(width: 6),
              _buildElementButton('Вода', const Color(0xFF457B9D), Icons.water_drop_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildElementButton(String name, Color color, IconData icon) {
    final isSelected = _selectedElement == name;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedElement = name;
          });
        },
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isSelected ? color : Colors.white12,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : color,
              ),
              const SizedBox(width: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZodiacGridSelector() {
    final signs = _zodiacData?.signs ?? [];
    if (signs.length < 12) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CosmicTheme.backgroundCard.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          // Ряд 1: 6 знаков (Овен - Дева)
          _buildSelectorRow(signs.sublist(0, 6)),
          const SizedBox(height: 8),
          // Ряд 2: 6 знаков (Весы - Рыбы)
          _buildSelectorRow(signs.sublist(6, 12)),
        ],
      ),
    );
  }

  Widget _buildSelectorRow(List<ZodiacSign> signs) {
    return Row(
      children: signs.map((sign) {
        final isSelected = sign.id == _activeSignId;
        final matchesElement = _selectedElement == 'Все' ||
            sign.element.toLowerCase() == _selectedElement.toLowerCase();

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: GestureDetector(
              onTap: () => _onSignSelected(sign.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? sign.elementColor.withOpacity(0.28)
                      : CosmicTheme.backgroundDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? sign.elementColor
                        : (matchesElement ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.02)),
                    width: isSelected ? 1.8 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: sign.elementColor.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Opacity(
                  opacity: matchesElement ? 1.0 : 0.4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        sign.symbol,
                        style: TextStyle(
                          fontSize: 18,
                          color: isSelected ? sign.elementColor : CosmicTheme.goldAccent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sign.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isSelected ? Colors.white : CosmicTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActiveHeroCard(ZodiacSign sign) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CosmicTheme.backgroundElevated,
            CosmicTheme.backgroundCard.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sign.elementColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: sign.elementColor.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: sign.elementColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: sign.elementColor.withOpacity(0.5), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  sign.symbol,
                  style: TextStyle(fontSize: 32, color: sign.elementColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sign.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: CosmicTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sign.elementColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sign.elementColor.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sign.elementIcon, color: sign.elementColor, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                sign.element,
                                style: TextStyle(
                                  color: sign.elementColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sign.dates,
                      style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // Бейджи параметров (Фокус, Энергия, Часы)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge(Icons.track_changes_rounded, 'Фокус: ${sign.focus}', CosmicTheme.goldAccent),
              _buildBadge(Icons.bolt_rounded, 'Энергия: ${sign.energy}', const Color(0xFF2EC4B6)),
              _buildBadge(Icons.access_time_rounded, 'Часы: ${sign.luckyHours}', CosmicTheme.cyanAccent),
            ],
          ),
          const SizedBox(height: 18),

          // Текст прогноза
          Text(
            sign.forecast,
            style: const TextStyle(
              color: CosmicTheme.textPrimary,
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignCompactTile(ZodiacSign sign) {
    final isSelected = sign.id == _activeSignId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? sign.elementColor.withOpacity(0.12)
            : CosmicTheme.backgroundCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? sign.elementColor : Colors.white10,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: sign.elementColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            sign.symbol,
            style: TextStyle(fontSize: 22, color: sign.elementColor),
          ),
        ),
        title: Row(
          children: [
            Text(
              sign.name,
              style: const TextStyle(
                color: CosmicTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${sign.dates})',
              style: const TextStyle(color: CosmicTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            sign.forecast,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: CosmicTheme.textSecondary, fontSize: 12.5),
          ),
        ),
        trailing: Icon(
          isSelected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
          color: isSelected ? sign.elementColor : CosmicTheme.textMuted,
          size: 16,
        ),
        onTap: () => _onSignSelected(sign.id),
      ),
    );
  }
}
