import 'package:flutter/material.dart';
import '../theme.dart';

class DiffViewer extends StatelessWidget {
  final String diffText;

  const DiffViewer({super.key, required this.diffText});

  @override
  Widget build(BuildContext context) {
    if (diffText.isEmpty) {
      return Center(
        child: Text(
          'Sem dados de diff disponíveis.',
          style: TextStyle(color: AmethystTheme.textMuted, fontStyle: FontStyle.italic),
        ),
      );
    }

    final List<String> lines = diffText.split('\n');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF06040A), // Fundo de terminal escuro
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33A855F7)),
      ),
      padding: const EdgeInsets.all(16),
      child: SelectionArea(
        child: ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            Widget lineWidget = _buildLine(line);
            
            // Adiciona um pequeno padding entre seções para melhor legibilidade
            if (line.startsWith('📋') || line.startsWith('=')) {
              return Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                child: lineWidget,
              );
            }
            return lineWidget;
          },
        ),
      ),
    );
  }

  Widget _buildLine(String line) {
    TextStyle style = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: AmethystTheme.textPrimary,
      height: 1.4,
    );

    Color? bg;
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2);

    if (line.contains('❌ ANTES:')) {
      style = style.copyWith(
        color: AmethystTheme.neonRed,
        fontWeight: FontWeight.w500,
      );
      bg = AmethystTheme.neonRed.withOpacity(0.08);
    } else if (line.contains('✅ DEPOIS:')) {
      style = style.copyWith(
        color: AmethystTheme.neonCyan,
        fontWeight: FontWeight.w600,
      );
      bg = AmethystTheme.neonCyan.withOpacity(0.08);
    } else if (line.startsWith('📋')) {
      style = style.copyWith(
        color: AmethystTheme.accentAmethyst,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      );
      padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 6);
    } else if (line.startsWith('=')) {
      style = style.copyWith(
        color: AmethystTheme.textMuted,
        fontWeight: FontWeight.bold,
      );
    } else if (line.contains('(sem alteração)')) {
      style = style.copyWith(
        color: AmethystTheme.textMuted,
      );
    } else if (line.contains('──')) {
      style = style.copyWith(
        color: AmethystTheme.textMuted.withOpacity(0.7),
      );
    } else if (line.trim().startsWith('Bullet') || line.trim().startsWith('Item')) {
      style = style.copyWith(
        color: AmethystTheme.accentIndigo,
        fontWeight: FontWeight.bold,
      );
    }

    Widget textWidget = Text(line, style: style);

    if (bg != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: padding,
        margin: const EdgeInsets.symmetric(vertical: 1),
        child: textWidget,
      );
    }

    return Padding(
      padding: padding,
      child: textWidget,
    );
  }
}
