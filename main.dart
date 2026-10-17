import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AccountingApp());
}

const Color appBlue = Color(0xFF2457C5);
const Color appBackground = Color(0xFFF5F7FC);

const Map<String, String> currencies = {
  'YER': 'ريال يمني',
  'SAR': 'ريال سعودي',
  'USD': 'دولار أمريكي',
};

String money(double amount, String currency) {
  final value = NumberFormat('#,##0.##', 'en_US').format(amount.abs());
  final sign = amount < 0 ? '-' : '';
  return '$sign$value ${currencies[currency] ?? currency}';
}

String dateText(DateTime date) {
  return DateFormat('yyyy/MM/dd').format(date);
}

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class Client {
  String id;
  String name;
  String phone;
  String note;

  Client({
    required this.id,
    required this.name,
    this.phone = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
      };

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id']?.toString() ?? newId(),
        name: json['name']?.toString() ?? 'بدون اسم',
        phone: json['phone']?.toString() ?? '',
        note: json['note']?.toString() ?? '',
      );
}

enum EntryType {
  debtToMe,
  debtToClient,
  received,
  paid,
}

extension EntryTypeLabel on EntryType {
  String get label {
    switch (this) {
      case EntryType.debtToMe:
        return 'لي عنده';
      case EntryType.debtToClient:
        return 'له عندي';
      case EntryType.received:
        return 'استلمت منه';
      case EntryType.paid:
        return 'دفعت له';
    }
  }

  double get effect {
    switch (this) {
      case EntryType.debtToMe:
        return 1;
      case EntryType.debtToClient:
        return -1;
      case EntryType.received:
        return -1;
      case EntryType.paid:
        return 1;
    }
  }
}

class TransactionEntry {
  String id;
  String clientId;
  double amount;
  String currency;
  EntryType type;
  String details;
  DateTime date;

  TransactionEntry({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.currency,
    required this.type,
    required this.details,
    required this.date,
  });

  double get signedAmount => amount * type.effect;

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientId': clientId,
        'amount': amount,
        'currency': currency,
        'type': type.name,
        'details': details,
        'date': date.toIso8601String(),
      };

  factory TransactionEntry.fromJson(Map<String, dynamic> json) {
    return TransactionEntry(
      id: json['id']?.toString() ?? newId(),
      clientId: json['clientId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'YER',
      type: EntryType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => EntryType.debtToMe,
      ),
      details: json['details']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دفتر الحسابات',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: appBlue),
        scaffoldBackgroundColor: appBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: appBlue,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String clientsKey = 'accounting_clients_v2';
  static const String entriesKey = 'accounting_entries_v2';

  final List<Client> clients = [];
  final List<TransactionEntry> entries = [];

  bool loading = true;
  int selectedTab = 0;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedClients = prefs.getString(clientsKey);
      final savedEntries = prefs.getString(entriesKey);

      if (savedClients != null) {
        final decoded = jsonDecode(savedClients) as List;
        clients.addAll(
          decoded.map(
            (item) => Client.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
      }

      if (savedEntries != null) {
        final decoded = jsonDecode(savedEntries) as List;
        entries.addAll(
          decoded.map(
            (item) => TransactionEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        message('تعذر قراءة بعض البيانات المحفوظة.');
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        clientsKey,
        jsonEncode(clients.map((c) => c.toJson()).toList()),
      );

      await prefs.setString(
        entriesKey,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      message('تعذر حفظ البيانات على الهاتف.');
    }
  }

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  double balance(String clientId, String currency) {
    return entries
        .where(
          (e) =>
              e.clientId == clientId &&
              e.currency == currency,
        )
        .fold(0.0, (sum, e) => sum + e.signedAmount);
  }

  double totalBalance(String currency) {
    return entries
        .where((e) => e.currency == currency)
        .fold(0.0, (sum, e) => sum + e.signedAmount);
  }

  Future<void> addClient() async {
    final result = await showDialog<Client>(
      context: context,
      builder: (_) => const ClientDialog(),
    );

    if (result == null) return;

    final duplicate = clients.any(
      (c) => c.name.trim().toLowerCase() ==
          result.name.trim().toLowerCase(),
    );

    if (duplicate) {
      message('يوجد حساب بهذا الاسم بالفعل.');
      return;
    }

    setState(() => clients.insert(0, result));
    await saveData();
  }

  Future<void> editClient(Client client) async {
    final result = await showDialog<Client>(
      context: context,
      builder: (_) => ClientDialog(existing: client),
    );

    if (result == null) return;

    setState(() {
      client.name = result.name;
      client.phone = result.phone;
      client.note = result.note;
    });

    await saveData();
  }

  Future<void> addEntry({String? clientId}) async {
    if (clients.isEmpty) {
      message('أضف حسابًا أولًا.');
      await addClient();
      if (clients.isEmpty) return;
    }

    final result = await showDialog<TransactionEntry>(
      context: context,
      builder: (_) => EntryDialog(
        clients: clients,
        initialClientId: clientId,
      ),
    );

    if (result == null) return;

    setState(() => entries.insert(0, result));
    await saveData();
  }

  Future<void> editEntry(TransactionEntry oldEntry) async {
    final result = await showDialog<TransactionEntry>(
      context: context,
      builder: (_) => EntryDialog(
        clients: clients,
        existing: oldEntry,
      ),
    );

    if (result == null) return;

    final index = entries.indexWhere((e) => e.id == oldEntry.id);

    if (index == -1) return;

    setState(() => entries[index] = result);
    await saveData();
  }

  Future<void> deleteEntry(TransactionEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المعاملة'),
        content: const Text(
          'هل تريد حذف هذه المعاملة؟ سيُعاد حساب الرصيد تلقائيًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      entries.removeWhere((e) => e.id == entry.id);
    });

    await saveData();
  }

  Future<void> deleteClient(Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'سيؤدي الحذف إلى إزالة الحساب وجميع معاملاته من هذا الجهاز.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      clients.removeWhere((c) => c.id == client.id);
      entries.removeWhere((e) => e.clientId == client.id);
    });

    await saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'دفتر الحسابات',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: () => addEntry(),
              tooltip: 'إضافة معاملة',
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: selectedTab,
                children: [
                  dashboard(),
                  clientsPage(),
                  transactionsPage(),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: selectedTab == 1
              ? addClient
              : selectedTab == 2
                  ? () => addEntry()
                  : addClient,
          icon: Icon(
            selectedTab == 2 ? Icons.add : Icons.person_add_alt_1,
          ),
          label: Text(
            selectedTab == 2 ? 'معاملة جديدة' : 'حساب جديد',
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedTab,
          onDestinationSelected: (value) {
            setState(() => selectedTab = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'الحسابات',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'المعاملات',
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [appBlue, Color(0xFF4779E6)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مرحبًا بك في دفتر حساباتك',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Text(
                '${clients.length} حساب',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${entries.length} معاملة مسجلة',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: addClient,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('إضافة حساب'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: appBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => addEntry(),
                      icon: const Icon(Icons.add_card),
                      label: const Text('معاملة جديدة'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: appBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'الأرصدة حسب العملة',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...currencies.entries.map((currency) {
          final total = totalBalance(currency.key);

          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: appBlue.withValues(alpha: 0.10),
                  child: const Icon(Icons.account_balance_wallet, color: appBlue),
                ),
                title: Text(currency.value),
                subtitle: const Text('صافي الرصيد المسجل'),
                trailing: SizedBox(
                  width: 135,
                  child: Text(
                    money(total, currency.key),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: total >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        const Text(
          'أحدث المعاملات',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          emptyBox('لا توجد معاملات', 'أضف حسابًا ثم سجّل أول معاملة.')
        else
          ...entries.take(5).map(entryCard),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget clientsPage() {
    final filtered = clients.where((client) {
      final q = searchText.trim().toLowerCase();
      return q.isEmpty ||
          client.name.toLowerCase().contains(q) ||
          client.phone.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            onChanged: (value) => setState(() => searchText = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث عن حساب أو رقم هاتف',
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? emptyBox('لا توجد حسابات', 'اضغط على زر حساب جديد.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final client = filtered[index];
                    final count = entries
                        .where((e) => e.clientId == client.id)
                        .length;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: appBlue.withValues(alpha: 0.10),
                          child: Text(
                            client.name.isEmpty ? '?' : client.name[0],
                            style: const TextStyle(
                              color: appBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          client.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${client.phone.isEmpty ? 'بدون رقم هاتف' : client.phone} • $count معاملة',
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => openClient(client),
                        onLongPress: () => clientMenu(client),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> clientMenu(Client client) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل الحساب'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'حذف الحساب',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit') await editClient(client);
    if (action == 'delete') await deleteClient(client);
  }

  void openClient(Client client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientDetailsPage(
          client: client,
          entries: entries,
          balanceFor: (currency) => balance(client.id, currency),
          onAdd: () => addEntry(clientId: client.id),
          onEditClient: () => editClient(client),
          onEditEntry: editEntry,
          onDeleteEntry: deleteEntry,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget transactionsPage() {
    if (entries.isEmpty) {
      return emptyBox(
        'لا توجد معاملات',
        'اضغط على زر معاملة جديدة لتسجيل أول حركة مالية.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => entryCard(entries[index]),
    );
  }

  Widget entryCard(TransactionEntry entry) {
    final matching = clients.where((c) => c.id == entry.clientId);
    final clientName = matching.isEmpty ? 'حساب محذوف' : matching.first.name;
    final positive = entry.signedAmount >= 0;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (positive ? Colors.green : Colors.red).withValues(alpha: 0.10),
          child: Icon(
            entry.type == EntryType.received || entry.type == EntryType.paid
                ? Icons.payments_outlined
                : Icons.swap_horiz,
            color: positive ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          '$clientName • ${entry.type.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${dateText(entry.date)}${entry.details.isEmpty ? '' : ' • ${entry.details}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 125,
          child: Text(
            money(entry.signedAmount, entry.currency),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: positive ? Colors.green : Colors.red,
            ),
          ),
        ),
        onTap: () => entryMenu(entry),
      ),
    );
  }

  Future<void> entryMenu(TransactionEntry entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل المعاملة'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'حذف المعاملة',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit') await editEntry(entry);
    if (action == 'delete') await deleteEntry(entry);
  }

  Widget emptyBox(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 58,
              color: appBlue.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class ClientDialog extends StatefulWidget {
  final Client? existing;

  const ClientDialog({super.key, this.existing});

  @override
  State<ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<ClientDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController noteController;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.existing?.name ?? '');
    phoneController = TextEditingController(text: widget.existing?.phone ?? '');
    noteController = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(
          widget.existing == null ? 'إضافة حساب جديد' : 'تعديل الحساب',
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'اسم الشخص *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'اكتب اسم الشخص'
                          : null,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              Navigator.pop(
                context,
                Client(
                  id: widget.existing?.id ?? newId(),
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  note: noteController.text.trim(),
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class EntryDialog extends StatefulWidget {
  final List<Client> clients;
  final String? initialClientId;
  final TransactionEntry? existing;

  const EntryDialog({
    super.key,
    required this.clients,
    this.initialClientId,
    this.existing,
  });

  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  final formKey = GlobalKey<FormState>();

  late String clientId;
  late String currency;
  late EntryType type;
  late DateTime date;

  late final TextEditingController amountController;
  late final TextEditingController detailsController;

  @override
  void initState() {
    super.initState();

    clientId = widget.existing?.clientId ??
        widget.initialClientId ??
        widget.clients.first.id;

    currency = widget.existing?.currency ?? 'YER';
    type = widget.existing?.type ?? EntryType.debtToMe;
    date = widget.existing?.date ?? DateTime.now();

    amountController = TextEditingController(
      text: widget.existing?.amount.toString() ?? '',
    );

    detailsController = TextEditingController(
      text: widget.existing?.details ?? '',
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );

    if (picked != null) setState(() => date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(
          widget.existing == null ? 'تسجيل معاملة' : 'تعديل المعاملة',
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: clientId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الحساب'),
                    items: widget.clients
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => clientId = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<EntryType>(
                    value: type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'نوع المعاملة',
                    ),
                    items: EntryType.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: currency,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'العملة'),
                    items: currencies.entries
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.key,
                            child: Text(item.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => currency = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ *',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').trim().replaceAll(',', '.'),
                      );

                      if (parsed == null || parsed <= 0) {
                        return 'أدخل مبلغًا أكبر من صفر';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'البيان / التفاصيل',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text('التاريخ: ${dateText(date)}'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              final amount = double.parse(
                amountController.text.trim().replaceAll(',', '.'),
              );

              Navigator.pop(
                context,
                TransactionEntry(
                  id: widget.existing?.id ?? newId(),
                  clientId: clientId,
                  amount: amount,
                  currency: currency,
                  type: type,
                  details: detailsController.text.trim(),
                  date: date,
                ),
              );
            },
            child: const Text('حفظ المعاملة'),
          ),
        ],
      ),
    );
  }
}

class ClientDetailsPage extends StatefulWidget {
  final Client client;
  final List<TransactionEntry> entries;
  final double Function(String currency) balanceFor;
  final VoidCallback onAdd;
  final VoidCallback onEditClient;
  final Future<void> Function(TransactionEntry) onEditEntry;
  final Future<void> Function(TransactionEntry) onDeleteEntry;

  const ClientDetailsPage({
    super.key,
    required this.client,
    required this.entries,
    required this.balanceFor,
    required this.onAdd,
    required this.onEditClient,
    required this.onEditEntry,
    required this.onDeleteEntry,
  });

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final clientEntries = widget.entries
        .where((entry) => entry.clientId == widget.client.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.client.name),
          actions: [
            IconButton(
              onPressed: widget.onEditClient,
              tooltip: 'تعديل الحساب',
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: widget.onAdd,
          icon: const Icon(Icons.add),
          label: const Text('إضافة معاملة'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.client.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.client.phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(widget.client.phone),
                      ),
                    if (widget.client.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(widget.client.note),
                      ),
                    const Divider(height: 26),
                    const Text(
                      'الرصيد حسب العملة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...currencies.entries.map((unit) {
                      final value = widget.balanceFor(unit.key);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(unit.value),
                            Flexible(
                              child: Text(
                                money(value, unit.key),
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: value >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'كشف الحساب (${clientEntries.length} معاملة)',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (clientEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('لا توجد معاملات لهذا الحساب بعد.'),
                ),
              )
            else
              ...clientEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        '${entry.type.label} • ${money(entry.amount, entry.currency)}',
                      ),
                      subtitle: Text(
                        '${dateText(entry.date)}'
                        '${entry.details.isEmpty ? '' : '\n${entry.details}'}',
                      ),
                      isThreeLine: entry.details.isNotEmpty,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'edit') {
                            await widget.onEditEntry(entry);
                          }

                          if (action == 'delete') {
                            await widget.onDeleteEntry(entry);
                          }

                          if (mounted) setState(() {});
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('تعديل'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('حذف'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
