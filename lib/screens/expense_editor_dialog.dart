import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import 'package:uuid/uuid.dart';

class ExpenseEditorDialog extends StatefulWidget {
  final Expense? existingExpense;
  const ExpenseEditorDialog({super.key, this.existingExpense});

  @override
  State<ExpenseEditorDialog> createState() => _ExpenseEditorDialogState();
}

class _ExpenseEditorDialogState extends State<ExpenseEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late ExpenseCategory _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.existingExpense?.amount.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.existingExpense?.description ?? '');
    _category = widget.existingExpense?.category ?? ExpenseCategory.other;
    _date = widget.existingExpense?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingExpense == null ? 'Add Expense' : 'Edit Expense'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₵ '),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ExpenseCategory.values.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()));
                }).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final expense = Expense(
                id: widget.existingExpense?.id ?? const Uuid().v4(),
                date: _date,
                amount: double.parse(_amountController.text),
                description: _descriptionController.text,
                category: _category,
              );
              Navigator.pop(context, expense);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
