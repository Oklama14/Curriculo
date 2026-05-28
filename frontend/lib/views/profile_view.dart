import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/glass_container.dart';

class ProfileView extends StatefulWidget {
  final AppState state;
  const ProfileView({super.key, required this.state});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _linkedinController;
  late final TextEditingController _gupyController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.state.profileName ?? '');
    _linkedinController = TextEditingController(text: widget.state.linkedinUrl ?? '');
    _gupyController = TextEditingController(text: widget.state.gupyUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _linkedinController.dispose();
    _gupyController.dispose();
    super.dispose();
  }

  String? _validateLinkedIn(String? value) {
    if (value == null || value.isEmpty) return null;
    final val = value.trim();
    if (!val.startsWith('http://') && !val.startsWith('https://')) {
      return 'A URL deve começar com http:// ou https://';
    }
    if (!val.contains('linkedin.com/')) {
      return 'URL do LinkedIn inválida. Ex: https://linkedin.com/in/seu-perfil';
    }
    return null;
  }

  String? _validateGupy(String? value) {
    if (value == null || value.isEmpty) return null;
    final val = value.trim();
    if (!val.startsWith('http://') && !val.startsWith('https://')) {
      return 'A URL deve começar com http:// ou https://';
    }
    if (!val.contains('gupy.io') && !val.contains('gupi.io')) {
      return 'URL da Gupy inválida. Ex: https://empresa.gupy.io';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final success = await widget.state.updateUserProfile(
      name: _nameController.text.trim(),
      linkedinUrl: _linkedinController.text.trim(),
      gupyUrl: _gupyController.text.trim(),
    );

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: success ? AmethystTheme.neonCyan : AmethystTheme.neonRed,
              ),
              const SizedBox(width: 8),
              Text(
                success 
                    ? 'Perfil atualizado com sucesso!' 
                    : 'Erro ao atualizar perfil: ${widget.state.profileError ?? "desconhecido"}',
              ),
            ],
          ),
          backgroundColor: AmethystTheme.surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hasLinkedIn = state.linkedinUrl != null && state.linkedinUrl!.isNotEmpty;
    final hasGupy = state.gupyUrl != null && state.gupyUrl!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configurações de Perfil',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Gerencie suas contas de candidatura e informações básicas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              
              // Perfil Card
              GlassContainer(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info Header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AmethystTheme.accentAmethyst.withOpacity(0.2),
                            backgroundImage: state.photoUrl != null && state.photoUrl!.isNotEmpty
                                ? NetworkImage(state.photoUrl!)
                                : null,
                            child: state.photoUrl == null || state.photoUrl!.isEmpty
                                ? const Icon(Icons.person, size: 40, color: AmethystTheme.accentAmethyst)
                                : null,
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.profileName ?? 'Usuário',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state.profileEmail ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AmethystTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Divider(color: Color(0x22A855F7), height: 1),
                      const SizedBox(height: 32),
                      
                      // Status Section
                      Text(
                        'Status de Integração',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatusBadge(
                            title: 'LinkedIn',
                            isActive: hasLinkedIn,
                          ),
                          const SizedBox(width: 16),
                          _buildStatusBadge(
                            title: 'Gupy',
                            isActive: hasGupy,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Form fields
                      Text(
                        'Nome Completo',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Seu nome completo',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'URL do LinkedIn',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _linkedinController,
                        validator: _validateLinkedIn,
                        decoration: const InputDecoration(
                          hintText: 'https://linkedin.com/in/seu-perfil',
                          prefixIcon: Icon(Icons.link, size: 20),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'URL do Perfil Gupy',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _gupyController,
                        validator: _validateGupy,
                        decoration: const InputDecoration(
                          hintText: 'https://perfil.gupy.io ou https://empresa.gupy.io',
                          prefixIcon: Icon(Icons.link, size: 20),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Save button
                      if (_isSaving)
                        const Center(child: CircularProgressIndicator(color: AmethystTheme.accentAmethyst))
                      else
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: AmethystTheme.accentGradient,
                            boxShadow: AmethystTheme.glowShadow(
                              AmethystTheme.accentAmethyst,
                              radius: 12.0,
                              opacity: 0.3,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            child: const Text('SALVAR CONFIGURAÇÕES'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge({required String title, required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive 
            ? AmethystTheme.neonCyan.withOpacity(0.08) 
            : AmethystTheme.accentAmethyst.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive 
              ? AmethystTheme.neonCyan.withOpacity(0.3) 
              : AmethystTheme.accentAmethyst.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.warning_amber_rounded,
            color: isActive ? AmethystTheme.neonCyan : AmethystTheme.accentAmethyst,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$title: ${isActive ? "Configurado" : "Pendente"}',
            style: TextStyle(
              color: isActive ? AmethystTheme.neonCyan : AmethystTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
