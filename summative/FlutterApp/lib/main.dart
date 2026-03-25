import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AQI Predictor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const PredictPage(),
    );
  }
}

class _FieldSpec {
  const _FieldSpec({
    required this.key,
    required this.label,
    required this.hint,
    required this.min,
    required this.max,
  });

  final String key; // Must match FastAPI aliases (e.g., "PM2.5")
  final String label; // What the user sees
  final String hint; // Range hint for the user
  final double min;
  final double max;
}

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  // Update these to match your deployed FastAPI service.
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String pathToPredict = '/predict';

  static const List<_FieldSpec> _specs = [
    _FieldSpec(key: 'PM2.5', label: 'PM2.5', hint: '0 - 1000', min: 0.0, max: 1000.0),
    _FieldSpec(key: 'PM10', label: 'PM10', hint: '0 - 1000', min: 0.0, max: 1000.0),
    _FieldSpec(key: 'NO', label: 'NO', hint: '0 - 500', min: 0.0, max: 500.0),
    _FieldSpec(key: 'NO2', label: 'NO2', hint: '0 - 500', min: 0.0, max: 500.0),
    _FieldSpec(key: 'NH3', label: 'NH3', hint: '0 - 500', min: 0.0, max: 500.0),
    _FieldSpec(key: 'SO2', label: 'SO2', hint: '0 - 500', min: 0.0, max: 500.0),
    _FieldSpec(key: 'CO', label: 'CO', hint: '0 - 100', min: 0.0, max: 100.0),
    _FieldSpec(key: 'O3', label: 'O3', hint: '0 - 500', min: 0.0, max: 500.0),
    _FieldSpec(key: 'Benzene', label: 'Benzene', hint: '0 - 200', min: 0.0, max: 200.0),
    _FieldSpec(key: 'City_encoded', label: 'City_encoded', hint: '1 - 100', min: 1.0, max: 100.0),
  ];

  final Map<String, TextEditingController> _controllers = {
    for (final s in _specs) s.key: TextEditingController(),
  };

  bool _isLoading = false;
  String? _resultText;
  String? _errorText;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _predict() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _resultText = null;
    });

    try {
      final missingKeys = <String>[];
      final values = <String, double>{};

      for (final spec in _specs) {
        final raw = _controllers[spec.key]?.text.trim() ?? '';
        if (raw.isEmpty) {
          missingKeys.add(spec.key);
          continue;
        }

        final parsed = double.tryParse(raw);
        if (parsed == null) {
          setState(() {
            _errorText = 'Invalid number for ${spec.label}.';
            _isLoading = false;
          });
          return;
        }

        if (parsed < spec.min || parsed > spec.max) {
          setState(() {
            _errorText = 'Invalid range for ${spec.label}: expected ${spec.min} - ${spec.max}, got $parsed';
            _isLoading = false;
          });
          return;
        }

        values[spec.key] = parsed;
      }

      if (missingKeys.isNotEmpty) {
        missingKeys.sort();
        setState(() {
          _errorText = 'Missing value(s): ${missingKeys.join(', ')}';
          _isLoading = false;
        });
        return;
      }

      final uri = Uri.parse('$baseUrl$pathToPredict');
      final payload = values; // Keys must match API aliases.

      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final predicted = decoded['predicted_aqi'];
        setState(() {
          _resultText = predicted == null ? 'Prediction returned empty result.' : 'Predicted AQI: $predicted';
        });
      } else {
        String message = 'Request failed with status ${response.statusCode}.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
            message = decoded['detail'].toString();
          }
        } catch (_) {
          // Keep generic message.
        }

        setState(() {
          _errorText = message;
        });
      }
    } catch (e) {
      setState(() {
        _errorText = 'Network error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildField(_FieldSpec spec) {
    return TextFormField(
      controller: _controllers[spec.key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: spec.label,
        hintText: spec.hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AQI Predictor'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter pollutant values within the allowed ranges, then press Predict.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 700 ? 2 : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _specs.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 3,
                        ),
                        itemBuilder: (context, index) => _buildField(_specs[index]),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isLoading ? null : _predict,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Predict'),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                elevation: 1,
                color: _errorText == null ? Colors.white : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _isLoading
                      ? const Text('Calculating prediction...')
                      : _errorText != null
                          ? Text(
                              _errorText!,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : _resultText != null
                              ? Text(
                                  _resultText!,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                )
                              : const Text(
                                  'Prediction result will appear here.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Endpoint: $baseUrl$pathToPredict',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
