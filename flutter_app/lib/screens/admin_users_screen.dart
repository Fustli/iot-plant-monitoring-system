import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../services/auth_provider.dart';
import '../services/api_client.dart';
import '../services/api_exceptions.dart';

/// Admin panel for user management
/// Only accessible by admin role
class AdminUsersScreen extends StatefulWidget {
  final bool embedded;

  const AdminUsersScreen({super.key, this.embedded = false});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _users = await _apiService.listAllUsers();
    } on ApiException catch (e) {
      _error = e.messageHu;
    } catch (e) {
      _error = 'Nem sikerült betölteni a felhasználókat';
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Felhasználó törlése'),
        content: Text(
            'Biztosan törölni szeretné ${user.username} felhasználót?\n\nEz a művelet nem visszavonható.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégsem'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteUser(user.id);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.username} torolve'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.messageHu),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleVerified(User user) async {
    try {
      await _apiService.updateUser(user.id, isVerified: !user.isVerified);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user.isVerified
                ? '${user.username} hitelesitese visszavonva'
                : '${user.username} hitelesitve'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.messageHu),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleActive(User user) async {
    try {
      await _apiService.updateUser(user.id, isActive: !user.isActive);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user.isActive
                ? '${user.username} deaktivalva'
                : '${user.username} aktivalva'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.messageHu),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Security check - only admin can access
    if (!authProvider.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text('Nincs jogosultsága ehhez az oldalhoz'),
        ),
      );
    }

    // Embedded mode - no scaffold, just body with FAB
    if (widget.embedded) {
      return Stack(
        children: [
          _buildBody(),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showAddUserDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person_add),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Felhasználók kezelése'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Újrapróbálás'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nincsenek felhasználók'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) => _buildUserCard(_users[index]),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Icon(
            _getRoleIcon(user.role),
            color: Colors.white,
          ),
        ),
        title: Text(
          user.username,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildRoleBadge(user.role),
                const SizedBox(width: 8),
                if (!user.isActive) _buildStatusBadge('Inaktiv', Colors.red),
                if (!user.isVerified)
                  _buildStatusBadge('Nem hitelesite', Colors.orange),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            switch (action) {
              case 'delete':
                _deleteUser(user);
                break;
              case 'verify':
                await _toggleVerified(user);
                break;
              case 'activate':
                await _toggleActive(user);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'verify',
              child: Row(
                children: [
                  Icon(
                    user.isVerified ? Icons.verified : Icons.verified_outlined,
                    color: user.isVerified ? Colors.grey : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(user.isVerified
                      ? 'Hitelesites visszavonas'
                      : 'Hitelesites'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'activate',
              child: Row(
                children: [
                  Icon(
                    user.isActive ? Icons.block : Icons.check_circle,
                    color: user.isActive ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(user.isActive ? 'Deaktivalas' : 'Aktivalas'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Torles', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getRoleColor(role).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.displayNameHu,
        style: TextStyle(
          fontSize: 12,
          color: _getRoleColor(role),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.manufacturer:
        return Colors.blue;
      case UserRole.consumer:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.manufacturer:
        return Icons.precision_manufacturing;
      case UserRole.consumer:
        return Icons.person;
    }
  }

  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final companyNameController = TextEditingController();
    UserRole selectedRole = UserRole.consumer;
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Új felhasználó'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Role selector
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Szerepkör *',
                      border: OutlineInputBorder(),
                    ),
                    items: UserRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Row(
                          children: [
                            Icon(_getRoleIcon(role), size: 20),
                            const SizedBox(width: 8),
                            Text(role.displayNameHu),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Felhasználónév *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kötelező mező';
                      }
                      if (value.length < 3) {
                        return 'Legalább 3 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kötelező mező';
                      }
                      if (!value.contains('@')) {
                        return 'Érvénytelen email cím';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Jelszó *',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kötelező mező';
                      }
                      if (value.length < 6) {
                        return 'Legalább 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Keresztnév',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Vezetéknév',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // Company name field - only shown for manufacturer role
                  if (selectedRole == UserRole.manufacturer) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Cég neve *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (selectedRole == UserRole.manufacturer &&
                            (value == null || value.isEmpty)) {
                          return 'Kötelező mező gyártóknál';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mégsem'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isLoading = true);
                        try {
                          await _apiService.registerUser(
                            username: usernameController.text.trim(),
                            email: emailController.text.trim(),
                            password: passwordController.text,
                            role: selectedRole.name,
                            firstName: firstNameController.text.isNotEmpty
                                ? firstNameController.text.trim()
                                : null,
                            lastName: lastNameController.text.isNotEmpty
                                ? lastNameController.text.trim()
                                : null,
                            companyName:
                                selectedRole == UserRole.manufacturer &&
                                        companyNameController.text.isNotEmpty
                                    ? companyNameController.text.trim()
                                    : null,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${usernameController.text} létrehozva'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadUsers();
                          }
                        } on ApiException catch (e) {
                          setDialogState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.messageHu),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Hiba: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Létrehozás'),
            ),
          ],
        ),
      ),
    );
  }
}
