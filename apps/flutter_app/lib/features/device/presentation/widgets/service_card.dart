import 'package:flutter/material.dart';
import 'package:flutter_app/core/fixture/fixture.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/text_styles.dart';
import 'package:flutter_app/features/device/domain/operation.dart';
import 'package:flutter_app/features/device/domain/service_group.dart';
import 'package:flutter_app/features/device/presentation/widgets/operation_row.dart';

/// One service: its name and UUID, then one row per (characteristic, operation).
class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.group});

  final ServiceGroup group;

  @override
  Widget build(BuildContext context) {
    final name = Fixture.nameOf(group.uuid);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name != null) Text(name, style: Theme.of(context).textTheme.titleSmall),
                Text(group.uuid, style: AppTextStyles.mono.copyWith(fontSize: 12, color: context.appColors.muted)),
              ],
            ),
          ),
          for (final key in group.chars)
            for (final op in Operation.of(key.properties)) OperationRow(charKey: key, operation: op),
        ],
      ),
    );
  }
}
