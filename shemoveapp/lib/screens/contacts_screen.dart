import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';

class ContactsScreen extends StatefulWidget {
  final List<TrustedContact> contacts;
  final String emergencyMessageTemplate;
  final Function(String name, String phone, String relationship) onAddContact;
  final Function(String id) onRemoveContact;
  final Function(String id) onSetPrimary;
  final VoidCallback? onBack;

  const ContactsScreen({
    super.key,
    required this.contacts,
    required this.emergencyMessageTemplate,
    required this.onAddContact,
    required this.onRemoveContact,
    required this.onSetPrimary,
    this.onBack,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<String> _relationships = [
    'Sister',
    'Father',
    'Mother',
    'Partner',
    'Best Friend',
    'Brother',
    'Family',
    'Colleague',
    'Other',
  ];

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRel = 'Sister';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryViolet.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_add_rounded, color: AppColors.primaryViolet, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text('Add Trusted Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contact Full Name',
                          prefixIcon: Icon(Icons.person, size: 20),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Phone Number (+91...)',
                          prefixIcon: Icon(Icons.phone, size: 20),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      const Text('Relationship', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _relationships.map((rel) {
                          final isSel = selectedRel == rel;
                          return ChoiceChip(
                            label: Text(rel),
                            selected: isSel,
                            selectedColor: AppColors.primaryViolet,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : (isDark ? AppColors.textSecondary : Colors.black87),
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) setSheetState(() => selectedRel = rel);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            if (name.isNotEmpty && phone.isNotEmpty) {
                              Navigator.pop(ctx);
                              widget.onAddContact(name, phone, selectedRel);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryViolet,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Save to Trusted Circle', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(TrustedContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Trusted Contact?'),
        content: Text('Are you sure you want to remove ${contact.name} from your emergency guardian circle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onRemoveContact(contact.id);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Trusted Contacts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        backgroundColor: AppColors.primaryViolet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Info / Encrypted Broadcast Template Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryViolet.withValues(alpha: isDark ? 0.22 : 0.1),
                      isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primaryViolet.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, color: AppColors.primaryViolet, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Encrypted Distress Broadcast',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'If a check-in is missed or emergency is triggered, your primary guardians instantly receive this broadcast:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.midnightDarkBackground : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Text(
                        widget.emergencyMessageTemplate,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.electricLavender : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Contacts Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Guardian Circle',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.safeGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.contacts.length} Active',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.safeGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Contacts List
              if (widget.contacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.group_off_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      const Text(
                        'No Emergency Contacts Yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Add trusted friends or family members to receive instant SOS alerts during journeys.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.contacts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final contact = widget.contacts[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: contact.isPrimary
                              ? AppColors.primaryViolet.withValues(alpha: 0.6)
                              : (isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder),
                          width: contact.isPrimary ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: contact.isPrimary
                                ? AppColors.primaryViolet
                                : (isDark ? AppColors.midnightDarkSurfaceVariant : Colors.grey.shade300),
                            child: Text(
                              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: contact.isPrimary ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        contact.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (contact.isPrimary) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.warningAmber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.star, size: 10, color: AppColors.warningAmber),
                                            SizedBox(width: 2),
                                            Text(
                                              'PRIMARY',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.warningAmber,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${contact.relationship} • ${contact.phone}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!contact.isPrimary)
                                IconButton(
                                  icon: const Icon(Icons.star_border, color: AppColors.warningAmber),
                                  tooltip: 'Set as Primary Guardian',
                                  onPressed: () => widget.onSetPrimary(contact.id),
                                ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 20, color: isDark ? AppColors.textMuted : Colors.grey),
                                tooltip: 'Remove Contact',
                                onPressed: () => _showDeleteConfirmDialog(contact),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
