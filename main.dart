import 'package:flutter/material.dart';

void main() {
  runApp(const AccountingApp());
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دفتر الحسابات Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class Transaction {
  final String client;
  final double amount;
  final String currency;
  final String details;
  final bool isGive;

  Transaction({
    required this.client,
    required this.amount,
    required this.currency,
    required this.details,
    required this.isGive,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _clients = [];
  final List<Transaction> _transactions = [];

  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  String _selectedCurrency = 'دولار';
  String? _selectedClient;

  void _addClient() {
    final name = _clientController.text.trim();
    if (name.isNotEmpty && !_clients.contains(name)) {
      setState(() {
        _clients.add(name);
        _selectedClient = name;
        _clientController.clear();
      });
    }
  }

  void _addTransaction(bool isGive) {
    if (_selectedClient == null || _amountController.text.isEmpty) return;

    final double? amount = double.tryParse(_amountController.text);
    if (amount == null) return;

    setState(() {
      _transactions.insert(
        0,
        Transaction(
          client: _selectedClient!,
          amount: amount,
          currency: _selectedCurrency,
          details: _detailsController.text.isEmpty ? 'بدون تفاصيل' : _detailsController.text,
          isGive: isGive,
        ),
      );
      _amountController.clear();
      _detailsController.clear();
    });
  }

  double get _totalBalance {
    double total = 0;
    for (var t in _transactions) {
      if (t.isGive) {
        total += t.amount;
      } else {
        total -= t.amount;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دفتر الحسابات Pro', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.indigo,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إضافة شخص / حساب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _clientController,
                              decoration: const InputDecoration(labelText: 'اسم الشخص'),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _addClient,
                            child: const Text('إضافة'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تسجيل عملية', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('اختر الحساب'),
                              value: _selectedClient,
                              items: _clients.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) => setState(() => _selectedClient = val),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<String>(
                            value: _selectedCurrency,
                            items: ['دولار', 'سعودي', 'محلي']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedCurrency = val!),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _detailsController,
                        decoration: const InputDecoration(labelText: 'التفاصيل / البيان'),
                      ),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'المبلغ'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () => _addTransaction(true),
                              child: const Text('له (+)', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => _addTransaction(false),
                              child: const Text('عليه (-)', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Text(
                'إجمالي الصافي: ${_totalBalance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          t.isGive ? Icons.arrow_upward : Icons.arrow_downward,
                          color: t.isGive ? Colors.green : Colors.red,
                        ),
                        title: Text('${t.client} - ${t.amount} ${t.currency}'),
                        subtitle: Text('${t.details} | ${t.isGive ? "له (+)" : "عليه (-)"}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _transactions.removeAt(index);
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
