import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import '../services/profile_cache.dart';
import '../services/aquarium_api_service.dart';
import '../widgets/app_logo.dart';
import 'dart:async';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedIP();
  }

  _loadSavedIP() async {
    final ip = await ProfileCache.getDeviceIp();
    setState(() {
      _ipController.text = ip ?? '192.168.4.1';
    });
  }

  _saveIP() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid IP address')),
      );
      return;
    }

    // Validasi format IP address
    final ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    if (!ipRegex.hasMatch(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid IP address format (e.g. 192.168.1.100)',
          ),
        ),
      );
      return;
    }

    await ProfileCache.saveDeviceIp(ip);

    // Update the connection manager with the new base URL
    final connectionManager = Provider.of<ConnectionManager>(
      context,
      listen: false,
    );
    connectionManager.setIpAddress(ip);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('IP Address saved')));
  }

  // Format DateTime untuk tampilan yang lebih bagus
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionManager = Provider.of<ConnectionManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [AppLogo(size: 24), SizedBox(width: 8), Text('SLAB')],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Connection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ipController,
                      decoration: InputDecoration(
                        labelText: 'ESP32 IP Address',
                        hintText: 'e.g. 192.168.1.100',
                        helperText: 'Enter the IP address of your ESP32 device',
                        border: const OutlineInputBorder(),
                        suffixIcon:
                            connectionManager.isConnected
                                ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                                : const Icon(Icons.error, color: Colors.red),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16),

                    // Connection Information
                    Text(
                      'Connection Status: ${connectionManager.connectionStatus}',
                      style: TextStyle(
                        color:
                            connectionManager.isConnected
                                ? Colors.green
                                : Colors.red,
                      ),
                    ),

                    // Tampilkan waktu koneksi terakhir jika ada
                    if (connectionManager.lastSuccessfulConnection != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last Connection: ${_formatDateTime(connectionManager.lastSuccessfulConnection!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],

                    // Tampilkan statistik koneksi
                    const SizedBox(height: 16),
                    const Text(
                      'Connection Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uptime: ${connectionManager.connectionUptime}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Success Rate: ${connectionManager.pingSuccessRate}% (${connectionManager.successfulPings}/${connectionManager.totalPingAttempts})',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Connection Drops: ${connectionManager.connectionDrops}',
                      style: const TextStyle(fontSize: 13),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                          onPressed: _saveIP,
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Test Connection'),
                          onPressed: () {
                            connectionManager.setIpAddress(_ipController.text);
                          },
                        ),
                      ],
                    ),

                    // Tampilkan status retry jika sedang melakukan retry
                    if (!connectionManager.isConnected) ...[
                      const SizedBox(height: 8),
                      if (connectionManager.isRetrying) ...[
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Retrying connection (${connectionManager.retryCount}/5)...',
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ] else if (connectionManager.retryCount >= 5) ...[
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Connection failed after multiple attempts',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          onPressed: () {
                            connectionManager.resetAndRetry();
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Aquarium LED Controller'),
                    Text('Version 1.0.0'),
                    SizedBox(height: 8),
                    Text(
                      'This app controls the LED lighting system for your aquarium.',
                    ),
                  ],
                ),
              ),
            ),

            // Tambahan fitur diagnostik
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Diagnostic',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('Test Direct HTTP'),
                            onPressed: () {
                              _testDirectHttpConnection();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.info_outline),
                            label: const Text('Show Connection Details'),
                            onPressed: () {
                              _showConnectionDetails();
                            },
                          ),
                        ),
                      ],
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

  // Implementasi metode diagnostik
  Future<void> _testDirectHttpConnection() async {
    try {
      final ipAddress = _ipController.text;
      if (ipAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an IP address first')),
        );
        return;
      }

      final url = 'http://$ipAddress/api/ping';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Testing connection to $url...')));

      final http =
          Provider.of<AquariumApiService>(context, listen: false).client;
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connection successful: ${response.statusCode}, ${response.body.length} bytes received',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: ${e.toString()}')),
      );
    }
  }

  void _showConnectionDetails() {
    final connectionManager = Provider.of<ConnectionManager>(
      context,
      listen: false,
    );
    final ipAddress = connectionManager.ipAddress;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Connection Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Current IP: $ipAddress'),
                  Text('Status: ${connectionManager.connectionStatus}'),
                  Text('Success Rate: ${connectionManager.pingSuccessRate}%'),
                  Text(
                    'Connection Drops: ${connectionManager.connectionDrops}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'HTTP Connection:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('URL: http://$ipAddress/api/ping'),
                  const Text('Clear Text Allowed: YES (configured in app)'),
                  const SizedBox(height: 8),
                  const Text(
                    'Troubleshooting Tips:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '• Ensure both device and IoT controller are on same network',
                  ),
                  const Text('• Check if IP address is correct'),
                  const Text('• Try accessing the IP in browser'),
                  const Text('• Ensure firewall is not blocking connections'),
                  const Text(
                    '• Check network security settings on IoT controller',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
