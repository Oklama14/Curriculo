import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../models/history_model.dart';
import '../widgets/glass_container.dart';

class ApplyView extends StatefulWidget {
  final AppState state;
  const ApplyView({super.key, required this.state});

  @override
  State<ApplyView> createState() => _ApplyViewState();
}

class _ApplyViewState extends State<ApplyView> {
  HistoryItem? _selectedHistoryItem;
  bool _isPreparing = false;

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

  Future<void> _prepareApply() async {
    final job = widget.state.applyJob;
    if (job == null || _selectedHistoryItem == null) return;

    setState(() {
      _isPreparing = true;
    });

    final success = await widget.state.prepareApplication(
      jobUrl: job.url,
      tailorRunId: _selectedHistoryItem!.id,
    );

    setState(() {
      _isPreparing = false;
    });

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.state.applyError ?? 'Erro ao preparar candidatura.'),
          backgroundColor: AmethystTheme.neonRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final job = state.applyJob;

    if (job == null) {
      return _buildNoJobSelected(state);
    }

    final prepareResponse = state.lastApplyPrepareResponse;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button & Title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AmethystTheme.accentAmethyst),
                    onPressed: () {
                      state.setTab(4); // Volta para vagas coletadas
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Candidatura Semi-Automática',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Vaga Info Card
              GlassContainer(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.work_rounded, color: AmethystTheme.accentIndigo, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.title,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AmethystTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                job.company,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AmethystTheme.accentAmethyst,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      job.url,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AmethystTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Etapa 1: Selecionar Currículo Otimizado
              if (prepareResponse == null) ...[
                Text(
                  '1. Escolha a versão do currículo otimizado',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (state.history.isEmpty) ...[
                  GlassContainer(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AmethystTheme.accentAmethyst, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Você ainda não otimizou nenhum currículo no histórico.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Para prosseguir, otimize seu currículo usando o botão de adaptar na aba de vagas coletadas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AmethystTheme.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            state.selectJobForTailoring(job.description);
                          },
                          child: const Text('IR PARA OTIMIZAÇÃO (TAILOR)'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  GlassContainer(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selecione a execução de tailoring que você deseja utilizar para esta candidatura:',
                          style: TextStyle(color: AmethystTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<HistoryItem>(
                          value: _selectedHistoryItem,
                          hint: const Text('Selecione uma otimização...'),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          dropdownColor: AmethystTheme.surface,
                          items: state.history.map((item) {
                            // Formata a data
                            final dateStr = item.timestamp.split('T')[0];
                            final preview = item.jobDescription.length > 50 
                                ? '${item.jobDescription.substring(0, 50)}...' 
                                : item.jobDescription;
                            return DropdownMenuItem<HistoryItem>(
                              value: item,
                              child: Text('$dateStr - $preview', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedHistoryItem = val;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        if (_selectedHistoryItem != null)
                          _buildSelectedRunPreview(_selectedHistoryItem!),
                        const SizedBox(height: 32),
                        if (_isPreparing)
                          const Center(child: CircularProgressIndicator(color: AmethystTheme.accentAmethyst))
                        else
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: AmethystTheme.accentGradient,
                            ),
                            child: ElevatedButton(
                              onPressed: _selectedHistoryItem == null ? null : _prepareApply,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                              ),
                              child: const Text('PREPARAR CANDIDATURA'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Etapa 2: Checklist e Ações
                Text(
                  '2. Checklist de candidatura preparada!',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                GlassContainer(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checklist items
                      ...(prepareResponse['checklist'] as List<dynamic>).map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.toString(),
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 32),
                      const Divider(color: Color(0x22A855F7), height: 1),
                      const SizedBox(height: 32),

                      // Botões de Candidatura
                      Text(
                        'Ações Disponíveis',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          // Botão Baixar PDF
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AmethystTheme.accentAmethyst.withOpacity(0.5)),
                              ),
                              child: OutlinedButton.icon(
                                onPressed: prepareResponse['pdf_url'] == null || prepareResponse['pdf_url'].isEmpty
                                    ? null
                                    : () => _launchUrl(prepareResponse['pdf_url']),
                                icon: const Icon(Icons.file_download_rounded, color: AmethystTheme.accentAmethyst),
                                label: const Text(
                                  'BAIXAR CURRÍCULO PDF',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Botão Abrir Vaga
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: AmethystTheme.accentGradient,
                                boxShadow: AmethystTheme.glowShadow(
                                  AmethystTheme.accentAmethyst,
                                  radius: 12,
                                  opacity: 0.3,
                                ),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => _launchUrl(prepareResponse['apply_url']),
                                icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                                label: const Text(
                                  'ABRIR VAGA NO LINKEDIN',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Dica/Instrução
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AmethystTheme.accentAmethyst.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AmethystTheme.accentAmethyst.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AmethystTheme.accentAmethyst),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Dica: Baixe o PDF primeiro para tê-lo em mãos. Quando o LinkedIn abrir a vaga, basta iniciar o fluxo de candidatura e arrastar o arquivo.',
                                style: TextStyle(fontSize: 13, color: AmethystTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedHistoryItem = null;
                            });
                            state.resetApplyState();
                          },
                          child: const Text(
                            'Escolher outro currículo ou recomeçar',
                            style: TextStyle(color: AmethystTheme.accentAmethyst),
                          ),
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

  Widget _buildNoJobSelected(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Candidatar-se',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Selecione uma das vagas coletadas abaixo para iniciar o processo de candidatura semi-automática.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              if (state.jobs.isEmpty)
                GlassContainer(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.work_off_outlined, color: AmethystTheme.accentAmethyst, size: 64),
                        const SizedBox(height: 24),
                        const Text(
                          'Nenhuma vaga coletada ainda.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Vá para a aba Vagas Coletadas e insira o link de uma vaga da Gupy ou LinkedIn.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AmethystTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            state.setTab(4); // Vai para vagas
                          },
                          child: const Text('BUSCAR VAGAS'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.jobs.length,
                  itemBuilder: (context, index) {
                    final job = state.jobs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            const Icon(Icons.work_outline_rounded, color: AmethystTheme.accentIndigo, size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    job.company,
                                    style: const TextStyle(color: AmethystTheme.accentAmethyst, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                state.selectJobForApply(job);
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('CANDIDATAR-SE'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedRunPreview(HistoryItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AmethystTheme.bgPrimary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x11A855F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalhes do Currículo Selecionado:',
            style: TextStyle(fontWeight: FontWeight.bold, color: AmethystTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AmethystTheme.accentIndigo),
              const SizedBox(width: 6),
              Text(
                'Data: ${item.timestamp.split('T')[0]}',
                style: const TextStyle(fontSize: 13, color: AmethystTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Vaga Alvo Original da adaptação:',
            style: TextStyle(color: AmethystTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            item.jobDescription.length > 120 
                ? '${item.jobDescription.substring(0, 120)}...' 
                : item.jobDescription,
            style: const TextStyle(fontSize: 12, color: AmethystTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
