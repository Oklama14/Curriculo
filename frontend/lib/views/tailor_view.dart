import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../providers/app_state.dart';
import '../widgets/glass_container.dart';
import '../widgets/diff_viewer.dart';

class TailorView extends StatefulWidget {
  final AppState state;

  const TailorView({super.key, required this.state});

  @override
  State<TailorView> createState() => _TailorViewState();
}

class _MainLogCycle {
  final String text;
  final Duration delay;
  _MainLogCycle(this.text, this.delay);
}

class _TailorViewState extends State<TailorView> with SingleTickerProviderStateMixin {
  final TextEditingController _descController = TextEditingController();
  bool _tailorSkills = true;
  bool _compilePdf = true;
  int _activeResultTab = 0; // 0 = Diff View, 1 = LaTeX Code

  // Ciclo de mensagens de log no carregamento para feedback visual
  final List<_MainLogCycle> _logs = [
    _MainLogCycle('Carregando arquivo de currículo base (curriculo.tex)...', const Duration(milliseconds: 200)),
    _MainLogCycle('Analisando seções LaTeX: identificando experiências e competências...', const Duration(milliseconds: 1000)),
    _MainLogCycle('Iniciando comunicação segura com Google Gemini API...', const Duration(milliseconds: 2000)),
    _MainLogCycle('Processando otimização com Gemini (reescrevendo bullet points)...', const Duration(milliseconds: 3500)),
    _MainLogCycle('Gemini: Concluído! Validando conformidade com as regras anti-alucinação...', const Duration(milliseconds: 7000)),
    _MainLogCycle('Mesclando alterações e validando a sintaxe final do LaTeX...', const Duration(milliseconds: 8500)),
    _MainLogCycle('Chamando pdflatex para compilar novo currículo em formato PDF...', const Duration(milliseconds: 9500)),
    _MainLogCycle('Operação concluída com sucesso! Atualizando base local...', const Duration(milliseconds: 11000)),
  ];

  int _currentLogIndex = 0;
  List<String> _visibleLogs = [];

  @override
  void initState() {
    super.initState();
    _descController.text = widget.state.tailorInputDescription;
    _descController.addListener(() {
      widget.state.updateTailorInputDescription(_descController.text);
    });
  }

  @override
  void didUpdateWidget(covariant TailorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.tailorInputDescription != _descController.text) {
      _descController.text = widget.state.tailorInputDescription;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _simulateLogs() async {
    _currentLogIndex = 0;
    _visibleLogs = [];
    
    while (widget.state.isTailoring && _currentLogIndex < _logs.length) {
      final logItem = _logs[_currentLogIndex];
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted || !widget.state.isTailoring) break;
      
      setState(() {
        _visibleLogs.add('>>> ${logItem.text}');
        _currentLogIndex++;
      });
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível abrir o link: $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir link: $e')),
        );
      }
    }
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
          'TailorCV_ACSing Workspace',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 28,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Adapte as informações do seu currículo LaTeX original à vaga desejada instantaneamente.',
          style: TextStyle(color: AmethystTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // Split Layout
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lado Esquerdo: Formulário
              Expanded(
                flex: 4,
                child: _buildInputForm(state),
              ),
              const SizedBox(width: 24),
              // Lado Direito: Resultados / Logs
              Expanded(
                flex: 5,
                child: _buildOutputPane(state),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputForm(AppState state) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Descrição da Vaga de Emprego',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _descController,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Cole aqui a descrição completa da vaga (requisitos, escopo, qualificações)...',
              ),
              style: const TextStyle(
                color: AmethystTheme.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Switches de configuração
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Otimizar Habilidades', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Ajusta keywords de competências', style: TextStyle(fontSize: 11, color: AmethystTheme.textSecondary)),
                  value: _tailorSkills,
                  onChanged: state.isTailoring
                      ? null
                      : (val) {
                          setState(() {
                            _tailorSkills = val ?? true;
                          });
                        },
                  contentPadding: EdgeInsets.zero,
                  activeColor: AmethystTheme.accentAmethyst,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Compilar PDF', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Gera PDF compilado por LaTeX', style: TextStyle(fontSize: 11, color: AmethystTheme.textSecondary)),
                  value: _compilePdf,
                  onChanged: state.isTailoring
                      ? null
                      : (val) {
                          setState(() {
                            _compilePdf = val ?? true;
                          });
                        },
                  contentPadding: EdgeInsets.zero,
                  activeColor: AmethystTheme.accentAmethyst,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Botão de Envio
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: !state.isTailoring && _descController.text.trim().isNotEmpty
                    ? AmethystTheme.glowShadow(AmethystTheme.accentAmethyst, radius: 12, opacity: 0.3)
                    : null,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onPressed: state.isTailoring || _descController.text.trim().isEmpty
                    ? null
                    : () {
                        _simulateLogs();
                        state.runTailor(
                          jobDescription: _descController.text,
                          tailorSkills: _tailorSkills,
                          compilePdf: _compilePdf,
                        );
                      },
                child: state.isTailoring
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('OTIMIZANDO CURRÍCULO...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 18),
                          SizedBox(width: 10),
                          Text('OTIMIZAR COM GEMINI'),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPane(AppState state) {
    if (state.isTailoring) {
      return _buildLoadingConsole();
    }

    if (state.tailorError != null) {
      return _buildErrorConsole(state.tailorError!);
    }

    if (state.lastTailorResponse != null) {
      return _buildResultsConsole(state.lastTailorResponse!);
    }

    // Estado Inativo
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
                  color: AmethystTheme.accentAmethyst.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: AmethystTheme.accentAmethyst.withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: AmethystTheme.accentAmethyst,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Workspace Ocioso',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Preencha os detalhes da vaga de emprego no painel ao lado e clique em "Otimizar com Gemini" para visualizar as reescritas sem alucinação e fazer download do seu currículo LaTeX compilado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AmethystTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingConsole() {
    return GlassContainer(
      borderColor: AmethystTheme.accentAmethyst.withOpacity(0.3),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AmethystTheme.accentAmethyst,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Processamento em Andamento...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AmethystTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF06040A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x22A855F7)),
              ),
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: _visibleLogs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _visibleLogs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AmethystTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorConsole(String error) {
    return GlassContainer(
      borderColor: AmethystTheme.neonRed.withOpacity(0.3),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AmethystTheme.neonRed),
              const SizedBox(width: 12),
              const Text(
                'Falha na Otimização',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F070B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AmethystTheme.neonRed.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text(
                  error,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AmethystTheme.neonRed,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  widget.state.loadAll();
                });
              },
              child: const Text('Limpar Erro'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildResultsConsole(Map<String, dynamic> response) {
    final diff = response['diff'] ?? '';
    final tex = response['tex_content'] ?? '';
    final pdfUrl = response['pdf_url'] ?? '';
    final texUrl = response['tex_url'] ?? '';
    final errors = response['errors'] as List<dynamic>? ?? [];

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com botões de download
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resultados Gerados',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text('Compilado com sucesso via LaTeX', style: TextStyle(fontSize: 11, color: AmethystTheme.neonCyan)),
                ],
              ),
              const Spacer(),
              if (texUrl.isNotEmpty)
                IconButton(
                  tooltip: 'Baixar Código LaTeX (.tex)',
                  icon: const Icon(Icons.code, color: AmethystTheme.textSecondary),
                  onPressed: () => _launchUrl(texUrl),
                ),
              if (pdfUrl.isNotEmpty)
                IconButton(
                  tooltip: 'Baixar Currículo PDF (.pdf)',
                  icon: const Icon(Icons.picture_as_pdf, color: AmethystTheme.neonCyan),
                  onPressed: () => _launchUrl(pdfUrl),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Se houver avisos não fatais
          if (errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aviso: ${errors.join(", ")}',
                        style: const TextStyle(color: Colors.amber, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Toggle de abas: Diff vs LaTeX
          Row(
            children: [
              _buildTabButton(0, 'Visualizar Modificações (Diff)'),
              const SizedBox(width: 8),
              _buildTabButton(1, 'Código LaTeX Modificado'),
            ],
          ),
          const SizedBox(height: 16),

          // Visualização do Conteúdo
          Expanded(
            child: _activeResultTab == 0
                ? DiffViewer(diffText: diff)
                : Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF06040A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x33A855F7)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: SelectionArea(
                          child: SingleChildScrollView(
                            child: Text(
                              tex,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: AmethystTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: CircleAvatar(
                          backgroundColor: AmethystTheme.surface,
                          radius: 18,
                          child: IconButton(
                            iconSize: 16,
                            icon: const Icon(Icons.copy, color: Colors.white),
                            onPressed: () => _copyToClipboard(tex),
                            tooltip: 'Copiar LaTeX',
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Botões Principais de Ação no Rodapé do Console
          Row(
            children: [
              if (pdfUrl.isNotEmpty)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AmethystTheme.glowShadow(AmethystTheme.neonCyan, radius: 10, opacity: 0.2),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AmethystTheme.neonCyan,
                        foregroundColor: const Color(0xFF020E1A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _launchUrl(pdfUrl),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download, size: 16),
                          SizedBox(width: 8),
                          Text('BAIXAR CURRÍCULO PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (pdfUrl.isNotEmpty && texUrl.isNotEmpty) const SizedBox(width: 12),
              if (texUrl.isNotEmpty)
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0x44A855F7)),
                    ),
                    onPressed: () => _launchUrl(texUrl),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code, size: 16),
                        SizedBox(width: 8),
                        Text('BAIXAR CÓDIGO TEX'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int tabIndex, String label) {
    final isSelected = _activeResultTab == tabIndex;
    return InkWell(
      onTap: () {
        setState(() {
          _activeResultTab = tabIndex;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AmethystTheme.accentAmethyst.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AmethystTheme.accentAmethyst.withOpacity(0.4) : const Color(0x11A855F7),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AmethystTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
