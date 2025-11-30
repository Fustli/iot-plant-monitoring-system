import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../services/auth_provider.dart';
import '../services/api_client.dart';
import '../services/api_exceptions.dart';
import '../services/localization_service.dart';

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
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteUser(User user) async {
    final localization = context.read<LocalizationProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localization.tr('admin_delete_user')),
        content: Text(localization
            .tr('admin_delete_user_confirm')
            .replaceAll('{name}', user.username)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localization.tr('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(localization.tr('common_delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteUser(user.id);
        _loadUsers();
        if (mounted) {
          final loc = context.read<LocalizationProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc
                  .tr('admin_user_deleted')
                  .replaceAll('{name}', user.username)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
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
        final loc = context.read<LocalizationProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user.isVerified
                ? loc
                    .tr('admin_user_unverified')
                    .replaceAll('{name}', user.username)
                : loc
                    .tr('admin_user_verified')
                    .replaceAll('{name}', user.username)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
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
        final loc = context.read<LocalizationProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user.isActive
                ? loc
                    .tr('admin_user_deactivated')
                    .replaceAll('{name}', user.username)
                : loc
                    .tr('admin_user_activated')
                    .replaceAll('{name}', user.username)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final localization = context.watch<LocalizationProvider>();

    // Security check - only admin can access
    if (!authProvider.isAdmin) {
      return Scaffold(
        body: Center(
          child: Text(localization.tr('error_no_permission')),
        ),
      );
    }

    // Embedded mode - no scaffold, just body with FAB
    if (widget.embedded) {
      return Stack(
        children: [
          _buildBody(localization),
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
        title: Text(localization.tr('admin_users')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _buildBody(localization),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildBody(LocalizationProvider localization) {
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
              child: Text(localization.tr('common_retry')),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(localization.tr('admin_no_users')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) =>
            _buildUserCard(_users[index], localization),
      ),
    );
  }

  Widget _buildUserCard(User user, LocalizationProvider localization) {
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
                if (!user.isActive)
                  _buildStatusBadge(
                      localization.tr('admin_inactive'), Colors.red),
                if (!user.isVerified)
                  _buildStatusBadge(
                      localization.tr('admin_not_verified'), Colors.orange),
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
          itemBuilder: (context) {
            final loc = context.read<LocalizationProvider>();
            return [
              PopupMenuItem(
                value: 'verify',
                child: Row(
                  children: [
                    Icon(
                      user.isVerified
                          ? Icons.verified
                          : Icons.verified_outlined,
                      color: user.isVerified ? Colors.grey : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(user.isVerified
                        ? loc.tr('admin_revoke_verify')
                        : loc.tr('admin_verify')),
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
                    Text(user.isActive
                        ? loc.tr('admin_deactivate')
                        : loc.tr('admin_activate')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(loc.tr('common_delete'),
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ];
          },
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
    final loc = context.read<LocalizationProvider>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(loc.tr('admin_new_user')),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Role selector
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: loc.tr('admin_role'),
                      border: const OutlineInputBorder(),
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
                    decoration: InputDecoration(
                      labelText: loc.tr('admin_username'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc.tr('admin_required_field');
                      }
                      if (value.length < 3) {
                        return loc
                            .tr('admin_min_chars')
                            .replaceAll('{count}', '3');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: loc.tr('admin_email'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc.tr('admin_required_field');
                      }
                      if (!value.contains('@')) {
                        return loc.tr('admin_invalid_email');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: loc.tr('admin_password'),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc.tr('admin_required_field');
                      }
                      if (value.length < 6) {
                        return loc
                            .tr('admin_min_chars')
                            .replaceAll('{count}', '6');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: firstNameController,
                    decoration: InputDecoration(
                      labelText: loc.tr('admin_first_name'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lastNameController,
                    decoration: InputDecoration(
                      labelText: loc.tr('admin_last_name'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  // Company name field - only shown for manufacturer role
                  if (selectedRole == UserRole.manufacturer) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: companyNameController,
                      decoration: InputDecoration(
                        labelText: loc.tr('admin_company_name'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (selectedRole == UserRole.manufacturer &&
                            (value == null || value.isEmpty)) {
                          return loc.tr('admin_required_manufacturer');
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
              child: Text(loc.tr('common_cancel')),
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
                                content: Text(loc
                                    .tr('admin_user_created')
                                    .replaceAll(
                                        '{name}', usernameController.text)),
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
                                content: Text(e.message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${loc.tr('common_error')}: $e'),
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
                  : Text(loc.tr('common_create')),
            ),
          ],
        ),
      ),
    );
  }
}
