import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../providers/app_state.dart';
import '../widgets/glass_container.dart';

// Importação condicional para suportar web file picker
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ResumeView extends StatefulWidget {
  final AppState state;

  const ResumeView({super.key, required this.state});

  @override
  State<ResumeView> createState() => _ResumeViewState();
}

class _ResumeViewState extends State<ResumeView> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isDragging = false;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Carrega o preview se já existe um currículo
    if (widget.state.resumeInfo != null && widget.state.resumeInfo!['exists'] == true) {
      if (widget.state.resumePreview == null) {
        widget.state.loadResumePreview();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _pickFile() {
    final input = html.FileUploadInputElement()..accept = '.tex';
    input.click();

    input.onChange.listen((event) {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((event) {
          final bytes = reader.result as Uint8List;
          widget.state.uploadResume(bytes.toList(), file.name);
        });
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check, color: AmethystTheme.neonCyan),
            SizedBox(width: 8),
            Text('LaTeX copiado para a área de transferência!'),
          ],
        ),
        backgroundColor: AmethystTheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título da Página
        Text(
          'Meu Currículo LaTeX',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 28,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Faça upload do seu arquivo .tex para personalizar o sistema com seu currículo.',
          style: TextStyle(color: AmethystTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lado Esquerdo: Upload + Info
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    // Área de Upload
                    _buildUploadArea(state),
                    const SizedBox(height: 20),
                    // Card de Info do currículo atual
                    if (state.resumeInfo != null &&
                        state.resumeInfo!['exists'] == true)
                      _buildResumeInfoCard(state),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Lado Direito: Preview do código
              Expanded(
                flex: 5,
                child: _buildPreviewPane(state),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadArea(AppState state) {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      borderColor: _isDragging
          ? AmethystTheme.accentAmethyst.withOpacity(0.6)
          : state.isUploadingResume
              ? AmethystTheme.neonCyan.withOpacity(0.3)
              : const Color(0x1FA855F7),
      showGlow: _isDragging,
      child: DragTarget<Object>(
        onWillAcceptWithDetails: (_) {
          setState(() => _isDragging = true);
          return true;
        },
        onLeave: (_) => setState(() => _isDragging = false),
        onAcceptWithDetails: (_) => setState(() => _isDragging = false),
        builder: (context, candidateData, rejectedData) {
          if (state.isUploadingResume) {
            return _buildUploadProgress();
          }

          return InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone animado
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AmethystTheme.accentAmethyst.withOpacity(
                                0.08 + 0.07 * _glowController.value),
                            AmethystTheme.accentIndigo.withOpacity(
                                0.05 + 0.05 * _glowController.value),
                          ],
                        ),
                        border: Border.all(
                          color: AmethystTheme.accentAmethyst.withOpacity(
                              0.2 + 0.15 * _glowController.value),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AmethystTheme.accentAmethyst.withOpacity(
                                0.1 * _glowController.value),
                            blurRadius: 20 * _glowController.value,
                            spreadRadius: 2 * _glowController.value,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.upload_file_rounded,
                        color: AmethystTheme.accentAmethyst,
                        size: 40,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enviar Currículo LaTeX',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Clique para selecionar ou arraste seu arquivo .tex aqui',
                  style: TextStyle(
                    color: AmethystTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AmethystTheme.accentAmethyst.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AmethystTheme.accentAmethyst.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 16, color: AmethystTheme.accentAmethyst),
                      SizedBox(width: 8),
                      Text(
                        'Apenas arquivos .tex  •  Máx. 500KB',
                        style: TextStyle(
                          color: AmethystTheme.accentAmethyst,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Feedback de sucesso ou erro
                if (state.resumeUploadSuccess != null) ...[
                  const SizedBox(height: 20),
                  _buildFeedbackBanner(
                    state.resumeUploadSuccess!,
                    isError: false,
                    onDismiss: () => state.clearResumeMessages(),
                  ),
                ],
                if (state.resumeError != null) ...[
                  const SizedBox(height: 20),
                  _buildFeedbackBanner(
                    state.resumeError!,
                    isError: true,
                    onDismiss: () => state.clearResumeMessages(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: AmethystTheme.accentAmethyst,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Enviando e validando currículo...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Verificando sintaxe LaTeX e estrutura de seções',
          style: TextStyle(
            color: AmethystTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackBanner(String message,
      {required bool isError, VoidCallback? onDismiss}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? AmethystTheme.neonRed.withOpacity(0.08)
            : AmethystTheme.neonCyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? AmethystTheme.neonRed.withOpacity(0.3)
              : AmethystTheme.neonCyan.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AmethystTheme.neonRed : AmethystTheme.neonCyan,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color:
                    isError ? AmethystTheme.neonRed : AmethystTheme.neonCyan,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              iconSize: 16,
              icon: Icon(
                Icons.close,
                color: isError
                    ? AmethystTheme.neonRed.withOpacity(0.6)
                    : AmethystTheme.neonCyan.withOpacity(0.6),
              ),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }

  Widget _buildResumeInfoCard(AppState state) {
    final info = state.resumeInfo!;
    final sections = (info['sections_found'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final sizeKb = ((info['size_bytes'] ?? 0) / 1024).toStringAsFixed(1);
    final modifiedAt = info['modified_at'] ?? '';

    // Formata a data
    String formattedDate = '';
    try {
      final dt = DateTime.parse(modifiedAt);
      formattedDate =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      formattedDate = modifiedAt;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderColor: AmethystTheme.neonCyan.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AmethystTheme.neonCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined,
                    color: AmethystTheme.neonCyan, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info['filename'] ?? 'curriculo.tex',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$sizeKb KB  •  Atualizado em $formattedDate',
                      style: const TextStyle(
                        color: AmethystTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Botão para visualizar preview
              IconButton(
                tooltip: 'Visualizar código LaTeX',
                icon: Icon(
                  _showPreview ? Icons.visibility_off : Icons.visibility,
                  color: AmethystTheme.accentAmethyst,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _showPreview = !_showPreview);
                  if (_showPreview && state.resumePreview == null) {
                    state.loadResumePreview();
                  }
                },
              ),
            ],
          ),
          if (sections.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'SEÇÕES DETECTADAS',
              style: TextStyle(
                color: AmethystTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: sections.map((section) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AmethystTheme.accentAmethyst.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AmethystTheme.accentAmethyst.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 12, color: AmethystTheme.neonCyan),
                      const SizedBox(width: 6),
                      Text(
                        section,
                        style: const TextStyle(
                          color: AmethystTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewPane(AppState state) {
    if (state.isLoadingResume) {
      return const GlassContainer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AmethystTheme.accentAmethyst),
              SizedBox(height: 16),
              Text(
                'Carregando currículo...',
                style:
                    TextStyle(color: AmethystTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final preview = state.resumePreview;
    final hasResume = state.resumeInfo != null &&
        state.resumeInfo!['exists'] == true;

    if (!hasResume || preview == null || preview.isEmpty) {
      return GlassContainer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AmethystTheme.accentIndigo.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AmethystTheme.accentIndigo.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.article_outlined,
                    color: AmethystTheme.accentIndigo,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Preview do Currículo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasResume
                      ? 'Clique no ícone de olho no painel ao lado para visualizar o código LaTeX do seu currículo carregado.'
                      : 'Faça upload do seu arquivo .tex no painel ao lado para visualizar o conteúdo do seu currículo aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AmethystTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (!hasResume) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AmethystTheme.accentAmethyst.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AmethystTheme.accentAmethyst.withOpacity(0.15)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 Dica para seu currículo LaTeX',
                          style: TextStyle(
                            color: AmethystTheme.accentAmethyst,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Para melhor compatibilidade com o sistema de otimização, '
                          'estruture seu currículo com seções como:\\n'
                          '\\section{Experiência}, \\section{Habilidades}, '
                          '\\section{Educação} e \\section{Certificações}.',
                          style: TextStyle(
                            color: AmethystTheme.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Preview com código LaTeX
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.code, color: AmethystTheme.neonCyan, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Código LaTeX do Currículo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              CircleAvatar(
                backgroundColor: AmethystTheme.surface,
                radius: 18,
                child: IconButton(
                  iconSize: 16,
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: () => _copyToClipboard(preview),
                  tooltip: 'Copiar LaTeX',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF06040A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x33A855F7)),
              ),
              padding: const EdgeInsets.all(16),
              child: SelectionArea(
                child: SingleChildScrollView(
                  child: Text(
                    preview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AmethystTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
