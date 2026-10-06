import 'package:flutter/material.dart';

import '../models/quiz_question.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';

/// Admin: Kampüs Bilgi Yarışması'na soru ekler/siler (`quiz_questions`).
/// Uygulamayla gelen gömülü sorular burada listelenmez ve silinemez.
/// Yazma yetkisi sunucuda zorlanır (yalnızca role='admin').
class QuizAdminScreen extends StatefulWidget {
  const QuizAdminScreen({super.key});

  @override
  State<QuizAdminScreen> createState() => _QuizAdminScreenState();
}

class _QuizAdminScreenState extends State<QuizAdminScreen> {
  final _api = SupabaseDataService();
  List<QuizQuestion> _questions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getRemoteQuizQuestions();
      if (!mounted) return;
      setState(() {
        _questions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Sorular alınamadı. `quiz_questions` tablosu için migration '
            'çalıştırıldı mı?\n$e';
      });
    }
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _QuizQuestionEditor()),
    );
    if (added == true) _load();
  }

  Future<void> _delete(QuizQuestion q) async {
    final theme = themeNotifier.value;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Soruyu Sil', style: TextStyle(color: theme.textColor)),
        content: Text(q.question, style: TextStyle(color: theme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || q.id == null) return;
    try {
      await _api.deleteQuizQuestion(q.id!);
      _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Silinemedi: $e'), backgroundColor: theme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        Widget message(String text) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textMuted, height: 1.5),
                ),
              ),
            );

        Widget body;
        if (_loading) {
          body = Center(child: CircularProgressIndicator(color: theme.primary));
        } else if (_error != null) {
          body = message(_error!);
        } else if (_questions.isEmpty) {
          body = message(
            'Henüz eklenmiş soru yok. Yarışma şu an uygulamayla gelen '
            '${bundledQuizQuestions.length} soruyla oynanıyor; eklediğiniz '
            'sorular bunlara katılır.',
          );
        } else {
          body = ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: _questions.length,
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final q = _questions[i];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: theme.surface.withValues(alpha: 0.6),
                title: Text(
                  q.question,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${q.category} · Doğru: ${q.correctAnswer}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.textMuted, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: theme.error),
                  tooltip: 'Sil',
                  onPressed: () => _delete(q),
                ),
              );
            },
          );
        }

        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Geri',
            ),
            title: Text(
              'Yarışma Soruları',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          floatingActionButton: _error != null
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: theme.primary,
                  onPressed: _add,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Soru Ekle',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
          body: SafeArea(child: AnimatedThemeBackground(child: body)),
        );
      },
    );
  }
}

class _QuizQuestionEditor extends StatefulWidget {
  const _QuizQuestionEditor();

  @override
  State<_QuizQuestionEditor> createState() => _QuizQuestionEditorState();
}

class _QuizQuestionEditorState extends State<_QuizQuestionEditor> {
  final _api = SupabaseDataService();
  final _formKey = GlobalKey<FormState>();
  final _questionCtrl = TextEditingController();
  final _optionCtrls = List.generate(4, (_) => TextEditingController());
  String _category = quizCategories.first;
  int _correct = 0;
  bool _saving = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final theme = themeNotifier.value;
    final messenger = ScaffoldMessenger.of(context);
    final options = [for (final c in _optionCtrls) c.text.trim()];
    if (options.map((o) => o.toLowerCase()).toSet().length != 4) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Dört şık birbirinden farklı olmalı.'),
          backgroundColor: theme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.addQuizQuestion(
        QuizQuestion(
          question: _questionCtrl.text.trim(),
          options: options,
          correctIndex: _correct,
          category: _category,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Eklenemedi: $e'), backgroundColor: theme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.textMuted, fontSize: 13),
          filled: true,
          fillColor: theme.surface,
          border: border(theme.primary.withValues(alpha: 0.2)),
          enabledBorder: border(theme.primary.withValues(alpha: 0.2)),
          focusedBorder: border(theme.primary, 1.5),
          errorBorder: border(theme.error),
          focusedErrorBorder: border(theme.error, 1.5),
        );

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.primary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kapat',
        ),
        title: Text(
          'Soru Ekle',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _questionCtrl,
                maxLength: 300,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: theme.textColor),
                decoration: deco('Soru'),
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Soru en az 5 karakter olmalı'
                    : null,
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _category,
                dropdownColor: theme.surface,
                style: TextStyle(color: theme.textColor, fontSize: 14),
                decoration: deco('Kategori'),
                items: [
                  for (final c in quizCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (c) => setState(() => _category = c ?? _category),
              ),
              const SizedBox(height: 18),
              Text(
                'Şıklar — doğru olanı işaretleyin',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Doğru şık: ${'ABCD'[i]}',
                        onPressed: () => setState(() => _correct = i),
                        icon: Icon(
                          _correct == i
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          color: _correct == i
                              ? const Color(0xFF43A047)
                              : theme.textMuted,
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _optionCtrls[i],
                          maxLength: 80,
                          style: TextStyle(color: theme.textColor),
                          decoration: deco('${'ABCD'[i]} şıkkı')
                              .copyWith(counterText: ''),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Boş bırakılamaz'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
