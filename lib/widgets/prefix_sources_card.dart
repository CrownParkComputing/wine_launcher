import 'package:flutter/material.dart';
import 'package:wine_launcher/models/prefix_url.dart';

class PrefixSourcesCard extends StatelessWidget {
  final List<PrefixUrl> prefixUrls;
  final Function(PrefixUrl) onCreatePrefix;
  final Map<String, double> downloadProgress;
  final Map<String, String> downloadStatus;

  const PrefixSourcesCard({
    super.key,
    required this.prefixUrls,
    required this.onCreatePrefix,
    required this.downloadProgress,
    required this.downloadStatus,
  });

  Color _getTypeColor(bool isProton) {
    return isProton ? Colors.purple.shade50 : Colors.blue.shade50;
  }

  Color _getTypeTextColor(bool isProton) {
    return isProton ? Colors.purple.shade900 : Colors.blue.shade900;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.source, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Available Prefix Sources',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...prefixUrls.map((prefix) => Card(
              color: _getTypeColor(prefix.isProton),
              child: ListTile(
                title: Text(prefix.title),
                subtitle: Text(
                  prefix.isProton ? 'Proton' : 'Wine',
                  style: TextStyle(
                    color: _getTypeTextColor(prefix.isProton),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: downloadProgress.containsKey(prefix.url) 
                    ? null 
                    : () => onCreatePrefix(prefix),
                  child: const Text('Create Prefix'),
                ),
              ),
            )),
            if (prefixUrls.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.warning_amber, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No prefix sources available.\nAdd them in Settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}