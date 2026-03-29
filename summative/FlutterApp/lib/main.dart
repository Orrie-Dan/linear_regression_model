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
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5EE0B2),
          secondary: Color(0xFF8B94A7),
          surface: Color(0xFF20222A),
          error: Color(0xFFFF6B6B),
        ),
        scaffoldBackgroundColor: const Color(0xFF111318),
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
  static const String baseUrl = 'https://linear-regression-model-cmw6.onrender.com';
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF292C34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF343843)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF5EE0B2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _controllers[spec.key],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: spec.label,
                hintText: spec.hint,
                labelStyle: const TextStyle(color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white38),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF191C22),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2C2F38)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart Air Control',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AQI prediction dashboard',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242832),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'Home status\nNight mode',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF242832),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.menu, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Card(
                elevation: 0,
                color: const Color(0xFF1A1E25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: Color(0xFF2C2F38)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 700 ? 2 : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _specs.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.9,
                        ),
                        itemBuilder: (context, index) => _buildField(_specs[index]),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5EE0B2),
                    foregroundColor: const Color(0xFF0F1618),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
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
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: _errorText == null ? const Color(0xFF1A1E25) : const Color(0xFF342124),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: _errorText == null ? const Color(0xFF2C2F38) : const Color(0xFF5F3237),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _isLoading
                      ? const Text(
                          'Calculating prediction...',
                          style: TextStyle(color: Colors.white70),
                        )
                      : _errorText != null
                          ? Text(
                              _errorText!,
                              style: TextStyle(
                                color: Colors.red.shade200,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : _resultText != null
                              ? Text(
                                  _resultText!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: Color(0xFF5EE0B2),
                                  ),
                                )
                              : const Text(
                                  'Prediction result will appear here.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Endpoint: $baseUrl$pathToPredict',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
