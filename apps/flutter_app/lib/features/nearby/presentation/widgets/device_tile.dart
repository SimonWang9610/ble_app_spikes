import 'package:flutter/material.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.name, required this.detail, required this.onTap, this.trailing});

  final String name;
  final String detail;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name.isEmpty ? '(no name)' : name),
      subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [if (trailing != null) Text(trailing!), const Icon(Icons.chevron_right)],
      ),
      onTap: onTap,
    );
  }
}
