import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const CurrencyConverterApp());
}

class CurrencyConverterApp extends StatefulWidget {
  const CurrencyConverterApp({super.key});

  @override
  _CurrencyConverterAppState createState() => _CurrencyConverterAppState();
}

class _CurrencyConverterAppState extends State<CurrencyConverterApp> {
  ThemeMode themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency Converter',
      themeMode: themeMode,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: CurrencyConverterPage(
        onThemeToggle: (isDark) {
          setState(() {
            themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
          });
        },
      ),
    );
  }
}

class CurrencyConverterPage extends StatefulWidget {
  final Function(bool) onThemeToggle;

  const CurrencyConverterPage({super.key, required this.onThemeToggle});

  @override
  _CurrencyConverterPageState createState() => _CurrencyConverterPageState();
}

class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
  String fromCurrency = "USD";
  String toCurrency = "EUR";
  double amount = 1.0;
  double result = 0.0;
  bool isLoading = false;
  bool isDarkMode = false;

  final List<String> currencies = [
    "USD",
    "EUR",
    "GBP",
    "INR",
    "AUD",
    "CAD",
    "JPY",
    "ZAR"
  ];
  final TextEditingController amountController = TextEditingController();

  List<FlSpot> chartData = [];
  Map<String, double> exchangeRatesCache = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadCachedRates();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      fromCurrency = prefs.getString('fromCurrency') ?? "USD";
      toCurrency = prefs.getString('toCurrency') ?? "EUR";
      amount = prefs.getDouble('amount') ?? 1.0;
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      widget.onThemeToggle(isDarkMode);
      amountController.text = amount.toString();
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fromCurrency', fromCurrency);
    await prefs.setString('toCurrency', toCurrency);
    await prefs.setDouble('amount', amount);
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  Future<void> _loadCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRates = prefs.getString('exchangeRates');
    if (cachedRates != null) {
      setState(() {
        exchangeRatesCache = Map<String, double>.from(jsonDecode(cachedRates));
      });
    }
  }

  Future<void> _cacheRates(Map<String, double> rates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('exchangeRates', jsonEncode(rates));
  }

  Future<void> convertCurrency() async {
    setState(() {
      isLoading = true;
    });

    const String apiKey = "e4715bca43fee02a023cd88c";
    final Uri url = Uri.parse(
        "https://v6.exchangerate-api.com/v6/$apiKey/latest/$fromCurrency");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = Map<String, dynamic>.from(data['conversion_rates'])
            .map((key, value) => MapEntry(key, (value as num).toDouble()));

        setState(() {
          exchangeRatesCache = rates;
          result = amount * rates[toCurrency]!;
          chartData = _generateChartData(rates);
        });
        await _cacheRates(rates);
      } else {
        throw Exception('Failed to fetch conversion rates');
      }
    } catch (e) {
      if (exchangeRatesCache.isNotEmpty) {
        setState(() {
          result = amount * exchangeRatesCache[toCurrency]!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Using cached rates: ${e.toString()}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<FlSpot> _generateChartData(Map<String, double> rates) {
    final randomKeys = rates.keys.take(7).toList();
    return List.generate(randomKeys.length, (index) {
      return FlSpot(index.toDouble(), rates[randomKeys[index]]!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter'),
        actions: [
          Switch(
            value: isDarkMode,
            onChanged: (value) {
              setState(() {
                isDarkMode = value;
                widget.onThemeToggle(isDarkMode);
                _savePreferences();
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
              onChanged: (value) {
                setState(() {
                  amount = double.tryParse(value) ?? 0.0;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                DropdownButton<String>(
                  value: fromCurrency,
                  onChanged: (newValue) {
                    setState(() {
                      fromCurrency = newValue!;
                    });
                  },
                  items: currencies
                      .map<DropdownMenuItem<String>>(
                          (currency) => DropdownMenuItem(
                                value: currency,
                                child: Text(currency),
                              ))
                      .toList(),
                ),
                const Icon(Icons.arrow_forward),
                DropdownButton<String>(
                  value: toCurrency,
                  onChanged: (newValue) {
                    setState(() {
                      toCurrency = newValue!;
                    });
                  },
                  items: currencies
                      .map<DropdownMenuItem<String>>(
                          (currency) => DropdownMenuItem(
                                value: currency,
                                child: Text(currency),
                              ))
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: convertCurrency,
              child: const Text('Convert'),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : Text(
                    result == 0
                        ? 'Enter details to convert'
                        : '$amount $fromCurrency = $result $toCurrency',
                    style: const TextStyle(fontSize: 18),
                  ),
            const SizedBox(height: 20),
            if (chartData.isNotEmpty)
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartData,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
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
