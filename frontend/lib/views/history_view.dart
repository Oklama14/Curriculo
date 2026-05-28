import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../providers/app_state.dart';
import '../models/history_model.dart';
import '../widgets/glass_container.dart';
import '../widgets/diff_viewer.dart';
import '../services/api_service.dart';

class HistoryView extends StatefulWidget {
  final AppState state;

  const HistoryView({super.key, required this.state});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  HistoryItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    // Seleciona a primeira execução por padrão, se existir
    if (widget.state.history.isNotEmpty) {
      _selectedItem = widget.state.history.first;
    }
  }

  @override
  void didUpdateWidget(covariant HistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o selecionado for nulo mas houver itens no histórico, seleciona o primeiro
    if (_selectedItem == null && widget.state.history.isNotEmpty) {
      _selectedItem = widget.state.history.first;
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

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hasHistory = state.history.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título da Aba
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Histórico de Otimizações',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore e baixe versões anteriores de currículos otimizados pela inteligência artificial.',
                  style: TextStyle(color: AmethystTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AmethystTheme.accentAmethyst),
              onPressed: () => state.loadHistory(),
              tooltip: 'Atualizar Histórico',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Painel Principal
        Expanded(
          child: state.isLoadingHistory
              ? const Center(
                  child: CircularProgressIndicator(color: AmethystTheme.accentAmethyst),
                )
              : !hasHistory
                  ? _buildEmptyState()
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lado Esquerdo: Lista de Execuções
                        Expanded(
                          flex: 3,
                          child: _buildHistoryList(state),
                        ),
                        const SizedBox(width: 24),
                        // Lado Direito: Detalhes
                        Expanded(
                          flex: 5,
                          child: _buildDetailsPane(),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return GlassContainer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_toggle_off, color: AmethystTheme.textMuted, size: 56),
              const SizedBox(height: 24),
              const Text(
                'Nenhum Histórico Encontrado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Você ainda não executou o otimizador para nenhuma vaga. Acesse a aba "Resume Tailoring" para começar!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AmethystTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(AppState state) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        itemCount: state.history.length,
        itemBuilder: (context, index) {
          final item = state.history[index];
          final isSelected = _selectedItem?.id == item.id;
          
          // Formata data e hora
          String dateStr = '';
          String timeStr = '';
          try {
            final dt = DateTime.parse(item.timestamp).toLocal();
            dateStr = DateFormat('dd/MM/yyyy').format(dt);
            timeStr = DateFormat('HH:mm').format(dt);
          } catch (_) {
            dateStr = item.timestamp;
          }

          // Trecho do texto da vaga
          final excerpt = item.jobDescription.length > 60
              ? '${item.jobDescription.substring(0, 60)}...'
              : item.jobDescription;

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                selected: isSelected,
                title: Text(
                  excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AmethystTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 11,
                        color: isSelected ? AmethystTheme.accentAmethyst : AmethystTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: isSelected ? AmethystTheme.textPrimary.withOpacity(0.8) : AmethystTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 11,
                        color: isSelected ? AmethystTheme.accentAmethyst : AmethystTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isSelected ? AmethystTheme.textPrimary.withOpacity(0.8) : AmethystTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.arrow_forward_ios, size: 14, color: AmethystTheme.accentAmethyst)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedItem = item;
                  });
                },
              ),
              if (item != state.history.last)
                const Divider(color: Color(0x11A855F7), height: 1),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailsPane() {
    if (_selectedItem == null) {
      return const GlassContainer(
        child: Center(
          child: Text(
            'Selecione uma otimização no menu lateral para visualizar seus detalhes.',
            style: TextStyle(color: AmethystTheme.textSecondary),
          ),
        ),
      );
    }

    final item = _selectedItem!;
    
    // Converte os caminhos do backend se forem caminhos relativos de static assets
    final apiService = ApiService();
    final pdfUrlResolved = apiService.resolveUrl(item.pdfUrl);
    final texUrlResolved = apiService.resolveUrl(item.texUrl);

    // Formata timestamp
    String fullDateTime = '';
    try {
      final dt = DateTime.parse(item.timestamp).toLocal();
      fullDateTime = DateFormat("dd 'de' MMMM 'de' yyyy 'às' HH:mm:ss", 'pt_BR').format(dt);
    } catch (_) {
      fullDateTime = item.timestamp;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da Execução
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código da Execução: ${item.id.substring(0, 8)}...',
                      style: const TextStyle(
                        color: AmethystTheme.accentAmethyst,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullDateTime,
                      style: const TextStyle(color: AmethystTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Botões de Ação
              if (texUrlResolved.isNotEmpty)
                IconButton(
                  tooltip: 'Baixar Código LaTeX (.tex)',
                  icon: const Icon(Icons.code, color: AmethystTheme.textSecondary),
                  onPressed: () => _launchUrl(texUrlResolved),
                ),
              if (pdfUrlResolved.isNotEmpty)
                IconButton(
                  tooltip: 'Baixar Currículo PDF (.pdf)',
                  icon: const Icon(Icons.picture_as_pdf, color: AmethystTheme.neonCyan),
                  onPressed: () => _launchUrl(pdfUrlResolved),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Painel de Downloads
          if (pdfUrlResolved.isNotEmpty || texUrlResolved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                children: [
                  if (pdfUrlResolved.isNotEmpty)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: AmethystTheme.glowShadow(AmethystTheme.neonCyan, radius: 8, opacity: 0.15),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AmethystTheme.neonCyan,
                            foregroundColor: const Color(0xFF020E1A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => _launchUrl(pdfUrlResolved),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download, size: 16),
                              SizedBox(width: 8),
                              Text('BAIXAR PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (pdfUrlResolved.isNotEmpty && texUrlResolved.isNotEmpty) const SizedBox(width: 12),
                  if (texUrlResolved.isNotEmpty)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0x33A855F7)),
                        ),
                        onPressed: () => _launchUrl(texUrlResolved),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.code, size: 16),
                            SizedBox(width: 8),
                            Text('BAIXAR TEX'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Seções Sanfonadas (Tabs para Descrição da Vaga e Diff)
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: AmethystTheme.accentAmethyst,
                    labelColor: Colors.white,
                    unselectedLabelColor: AmethystTheme.textSecondary,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(text: 'Visualizar Diff'),
                      Tab(text: 'Descrição da Vaga'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Diff Viewer
                        DiffViewer(diffText: item.diff),
                        // Tab 2: Descrição da Vaga
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF06040A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x22A855F7)),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: SelectionArea(
                            child: SingleChildScrollView(
                              child: Text(
                                item.jobDescription,
                                style: const TextStyle(
                                  color: AmethystTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
