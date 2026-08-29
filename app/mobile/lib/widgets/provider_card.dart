import 'package:flutter/material.dart';

import '../models/limits_response.dart';

/// One provider's card in the phone's 2-column grid. Deliberately compact — a phone column is
/// roughly half a Mac popover's width, so labels sit above their bar/value instead of beside it,
/// and everything truncates rather than wrapping.
class ProviderCard extends StatelessWidget {
  final ProviderLimits provider;

  const ProviderCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    provider.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (provider.plan != null)
                  Text(
                    provider.plan!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
              ],
            ),
            if (provider.resources.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'No data yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              )
            else ...[
              const SizedBox(height: 6),
              for (final resource in provider.resources.values)
                _resourceRow(resource),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resourceRow(ResourceLimit resource) {
    if (resource.kind == 'balance') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                resource.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Text(
              '${_formatNumber(resource.available)} ${resource.unit}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      );
    }

    final utilization = (resource.utilization ?? 0).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: utilization,
                    minHeight: 5,
                    backgroundColor: Colors.grey.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation(
                      _colorForUtilization(utilization),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _resourceValueLabel(resource),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _resourceValueLabel(ResourceLimit resource) {
    if (resource.unit == 'percent' && resource.used != null) {
      return '${resource.used!.round()}%';
    }
    if (resource.remaining != null) {
      return '${_formatNumber(resource.remaining)} ${resource.unit}';
    }
    return resource.unit;
  }

  String _formatNumber(double? value) {
    if (value == null) return '—';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  Color _colorForUtilization(double utilization) {
    if (utilization >= 0.9) return Colors.red;
    if (utilization >= 0.7) return Colors.orange;
    return Colors.green;
  }
}
