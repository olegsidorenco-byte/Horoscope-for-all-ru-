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
          // Фильтры по стихиям
          _buildElementFilterChips(),
          const SizedBox(height: 14),

          // Горизонтальный селектор 12 знаков
          _buildZodiacCarousel(),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _elements.map((el) {
          final isSelected = _selectedElement == el;
          Color chipColor = CosmicTheme.goldAccent;
          IconData? icon;

          if (el == 'Огонь') {
            chipColor = const Color(0xFFE76F51);
            icon = Icons.local_fire_department_rounded;
          } else if (el == 'Земля') {
            chipColor = const Color(0xFF2A9D8F);
            icon = Icons.eco_rounded;
          } else if (el == 'Воздух') {
            chipColor = const Color(0xFFE9C46A);
            icon = Icons.air_rounded;
          } else if (el == 'Вода') {
            chipColor = const Color(0xFF457B9D);
            icon = Icons.water_drop_rounded;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: icon != null
                  ? Icon(icon, size: 16, color: isSelected ? Colors.black : chipColor)
                  : null,
              label: Text(el),
              selected: isSelected,
              selectedColor: chipColor,
              backgroundColor: CosmicTheme.backgroundCard,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : CosmicTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? chipColor : Colors.white12,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedElement = el;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildZodiacCarousel() {
    final signs = _zodiacData?.signs ?? [];
    return SizedBox(
      height: 94,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: signs.length,
        itemBuilder: (context, index) {
          final sign = signs[index];
          final isSelected = sign.id == _activeSignId;

          return GestureDetector(
            onTap: () => _onSignSelected(sign.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 12),
              width: 74,
              decoration: BoxDecoration(
                color: isSelected
                    ? sign.elementColor.withOpacity(0.2)
                    : CosmicTheme.backgroundCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? sign.elementColor : Colors.white10,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: sign.elementColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sign.symbol,
                    style: TextStyle(
                      fontSize: 28,
                      color: isSelected ? sign.elementColor : CosmicTheme.goldSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sign.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : CosmicTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
