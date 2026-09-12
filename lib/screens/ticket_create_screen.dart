import 'package:flutter/material.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';

class TicketCreateScreen extends StatefulWidget {
  const TicketCreateScreen({super.key});

  @override
  State<TicketCreateScreen> createState() => _TicketCreateScreenState();
}

class _TicketCreateScreenState extends State<TicketCreateScreen> {
  final _dataService = SupabaseDataService();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedType = 'request'; // default: Talep
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Konu boş olamaz.');
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Açıklama boş olamaz.');
      return;
    }
    if (_subjectCtrl.text.trim().length < 5) {
      setState(() => _errorMsg = 'Konu en az 5 karakter olmalıdır.');
      return;
    }
    if (_descCtrl.text.trim().length < 10) {
      setState(() => _errorMsg = 'Açıklama en az 10 karakter olmalıdır.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await _dataService.createTicket(
        type: _selectedType,
        subject: _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Yeni Talep / Şikayet',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              Text(
                'Talep Türü',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildTypeSelector(theme),
              const SizedBox(height: 24),

              // Subject field
              Text(
                'Konu',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectCtrl,
                style: TextStyle(color: theme.textColor),
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Örn: Yemekhane menüsü hakkında öneri',
                  hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
                  counterStyle: TextStyle(color: theme.textMuted, fontSize: 11),
                  filled: true,
                  fillColor: theme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Description field
              Text(
                'Açıklama',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                style: TextStyle(color: theme.textColor),
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Talep, şikayet veya önerinizi detaylı olarak yazın...',
                  hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
                  counterStyle: TextStyle(color: theme.textMuted, fontSize: 11),
                  filled: true,
                  fillColor: theme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primary, width: 2),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: theme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Talebiniz yöneticilerimize iletilecektir. Durum değişikliklerinde bildirim alacaksınız. '
                        'Şikayetleriniz gizlilik ilkesi çerçevesinde değerlendirilir.',
                        style: TextStyle(color: theme.textMuted, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMsg != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: TextStyle(color: theme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Gönder',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(AppTheme theme) {
    final types = [
      {'value': 'complaint', 'label': 'Şikayet', 'icon': Icons.report_problem_outlined, 'color': 0xFFE53935},
      {'value': 'request', 'label': 'Talep', 'icon': Icons.assignment_outlined, 'color': 0xFF1E88E5},
      {'value': 'suggestion', 'label': 'Öneri', 'icon': Icons.lightbulb_outlined, 'color': 0xFF43A047},
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedType == type['value'];
        final color = Color(type['color'] as int);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: type['value'] == 'suggestion' ? 0 : 8),
            child: InkWell(
              onTap: () => setState(() => _selectedType = type['value'] as String),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.2) : theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : theme.primary.withValues(alpha: 0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      color: isSelected ? color : theme.textMuted,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        color: isSelected ? color : theme.textMuted,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}