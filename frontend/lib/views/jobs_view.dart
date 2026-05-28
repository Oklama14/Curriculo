import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../providers/app_state.dart';
import '../models/job_model.dart';
import '../widgets/glass_container.dart';

class JobsView extends StatefulWidget {
  final AppState state;

  const JobsView({super.key, required this.state});

  @override
  State<JobsView> createState() => _JobsViewState();
}

class _JobsViewState extends State<JobsView> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
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

  Future<void> _triggerScraping(AppState state) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final result = await state.scrapeJob(url);
    if (result != null) {
      _urlController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AmethystTheme.neonCyan),
                const SizedBox(width: 8),
                Text('Vaga "${result.title}" extraída e salva com sucesso!'),
              ],
            ),
            backgroundColor: AmethystTheme.surface,
          ),
        );
      }
    } else {
      if (mounted && state.scrapeError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: AmethystTheme.neonRed),
                const SizedBox(width: 8),
                Expanded(child: Text(state.scrapeError!)),
              ],
            ),
            backgroundColor: AmethystTheme.surface,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    
    // Filtro de Busca
    final filteredJobs = state.jobs.where((job) {
      final query = _searchQuery.toLowerCase();
      return job.title.toLowerCase().contains(query) ||
          job.company.toLowerCase().contains(query) ||
          job.description.toLowerCase().contains(query);
    }).toList();

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
                  'Vagas Coletadas',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gerencie as vagas salvas ou insira URLs do LinkedIn/Gupy para extrair detalhes.',
                  style: TextStyle(color: AmethystTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AmethystTheme.accentAmethyst),
              onPressed: () => state.loadJobs(),
              tooltip: 'Atualizar Vagas',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Barra de Importação por URL
        _buildImportBar(state),
        const SizedBox(height: 24),

        // Barra de Pesquisa
        _buildSearchBar(),
        const SizedBox(height: 16),

        // Lista de Vagas
        Expanded(
          child: state.isLoadingJobs
              ? const Center(
                  child: CircularProgressIndicator(color: AmethystTheme.accentAmethyst),
                )
              : filteredJobs.isEmpty
                  ? _buildEmptyState()
                  : _buildJobsGrid(filteredJobs, state),
        ),
      ],
    );
  }

  Widget _buildImportBar(AppState state) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: AmethystTheme.accentAmethyst.withOpacity(0.15),
      child: Row(
        children: [
          const Icon(Icons.link, color: AmethystTheme.accentAmethyst),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _urlController,
              enabled: !state.isScraping,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Cole aqui a URL da vaga (ex: gupy.io ou linkedin.com/jobs)...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _triggerScraping(state),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: state.isScraping ? null : () => _triggerScraping(state),
              child: state.isScraping
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('EXTRAIR VAGA'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      decoration: InputDecoration(
        hintText: 'Pesquise por cargo, empresa ou palavra-chave...',
        prefixIcon: const Icon(Icons.search, color: AmethystTheme.textSecondary, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AmethystTheme.textSecondary, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.work_off_outlined, color: AmethystTheme.textMuted, size: 48),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'Nenhuma vaga cadastrada.' : 'Nenhuma vaga corresponde à sua busca.',
            style: const TextStyle(color: AmethystTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsGrid(List<ScrapedJob> jobs, AppState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decide número de colonas de acordo com a largura da tela
        final int columns = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 800
                ? 2
                : 1;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.45,
          ),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            
            // Formata data de coleta
            String dateStr = '';
            try {
              dateStr = DateFormat('dd/MM/yyyy').format(job.extractedAt.toLocal());
            } catch (_) {
              dateStr = job.extractedAt.toString();
            }

            return GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título da Vaga e Empresa
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              job.company,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AmethystTheme.accentAmethyst,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Ver link original',
                        icon: const Icon(Icons.open_in_new, size: 16, color: AmethystTheme.textSecondary),
                        onPressed: () => _launchUrl(job.url),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0x11A855F7), height: 16),
                  
                  // Prévia da Descrição
                  Expanded(
                    child: Text(
                      job.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AmethystTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Rodapé do Card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Data
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 10, color: AmethystTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: const TextStyle(color: AmethystTheme.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                      // Ações
                      Row(
                        children: [
                          // ADAPTAR
                          SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                backgroundColor: AmethystTheme.accentIndigo.withOpacity(0.2),
                                side: const BorderSide(color: const Color(0x336366F1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: () => state.selectJobForTailoring(job.description),
                              child: const Row(
                                children: [
                                  Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('ADAPTAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // CANDIDATAR
                          SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                backgroundColor: AmethystTheme.accentAmethyst.withOpacity(0.2),
                                side: const BorderSide(color: const Color(0x33A855F7)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: () => state.selectJobForApply(job),
                              child: const Row(
                                children: [
                                  Icon(Icons.send_rounded, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('CANDIDATAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
