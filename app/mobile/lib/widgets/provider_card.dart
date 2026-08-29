import 'package:flutter/material.dart';

import '../models/limits_response.dart';

/// One provider's card in the phone's 2-column grid. Shows only the single most-urgent resource by
/// default (highest utilization, or the first balance resource when the provider has none) — the rest
/// stay behind a tap-to-expand toggle. Mirrors the Mac's own curated quota-comparison view rather than
/// dumping every resource the Mac tracks.
class ProviderCard extends StatefulWidget {
  final ProviderLimits provider;

  const ProviderCard({super.key, required this.provider});

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final resources = widget.provider.resources.values.toList();
    final headline = _headlineResource(resources);
    final rest = headline == null
        ? const <ResourceLimit>[]
        : resources.where((r) => r != headline).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: rest.isEmpty ? null : () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.provider.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  if (widget.provider.plan != null)
                    Text(
                      widget.provider.plan!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                ],
              ),
              if (headline == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No data yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                )
              else ...[
                const SizedBox(height: 6),
                _resourceRow(headline),
                if (rest.isNotEmpty) _expandToggle(rest.length),
                if (_expanded) for (final resource in rest) _resourceRow(resource),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The one resource worth showing without a tap: the highest-utilization progress-style resource,
  /// or (when the provider only reports balances, e.g. OpenRouter) its first balance resource.
  ResourceLimit? _headlineResource(List<ResourceLimit> resources) {
    if (resources.isEmpty) return null;
    final progress = resources.where((r) => r.kind != 'balance').toList()
      ..sort((a, b) => (b.utilization ?? 0).compareTo(a.utilization ?? 0));
    return progress.isNotEmpty ? progress.first : resources.first;
  }

  Widget _expandToggle(int hiddenCount) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _expanded ? 'Show less' : '+$hiddenCount more',
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
          Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            size: 14,
            color: Colors.grey[500],
          ),
        ],
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

  /// Color is reserved for resources that actually need attention — a low or mid utilization stays
  /// neutral gray instead of competing for the eye with the ones that matter.
  Color _colorForUtilization(double utilization) {
    if (utilization >= 0.9) return Colors.red;
    if (utilization >= 0.7) return Colors.orange;
    return Colors.grey;
  }
}
