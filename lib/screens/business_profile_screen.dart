import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/invoice.dart';
import '../providers/settings_provider.dart';
import '../providers/invoice_provider.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _revenueController;
  late TextEditingController _termsLabelController;
  late TextEditingController _signatureLabelController;
  late TextEditingController _termsContentController;
  late TextEditingController _managerPinController;
  String? _logoPath;
  String? _signaturePath;
  String _selectedCurrency = '\u20B5';
  late SignatureController _signatureController;
  bool _isSigning = false;
  late PdfTemplate _selectedTemplate;
  late PaymentGateway _selectedGateway;
  late TextEditingController _publicKeyController;
  late TextEditingController _secretKeyController;
  bool _isPaymentEnabled = false;
  bool _isLiveMode = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final biz = settings.businessInfo;
    _nameController = TextEditingController(text: biz?.name);
    _emailController = TextEditingController(text: biz?.email);
    _phoneController = TextEditingController(text: biz?.phone);
    _addressController = TextEditingController(text: biz?.address);
    _revenueController = TextEditingController(text: biz?.revenueGoal.toString());
    _termsLabelController = TextEditingController(text: biz?.pdfTermsLabel ?? 'TERMS & CONDITIONS');
    _signatureLabelController = TextEditingController(text: biz?.pdfSignatureLabel ?? 'Authorized Signature');
    _termsContentController = TextEditingController(text: biz?.terms);
    _managerPinController = TextEditingController(text: biz?.managerPin ?? '1234');
    _logoPath = biz?.logoPath;
    _signaturePath = biz?.signaturePath;
    _selectedCurrency = biz?.currency ?? '\u20B5';
    _selectedTemplate = biz?.pdfTemplate ?? PdfTemplate.sidebar;
    _selectedGateway = biz?.paymentGateway ?? PaymentGateway.none;
    _publicKeyController = TextEditingController(text: biz?.gatewayPublicKey);
    _secretKeyController = TextEditingController(text: biz?.gatewaySecretKey);
    _isPaymentEnabled = biz?.isPaymentEnabled ?? false;
    _isLiveMode = biz?.isLiveMode ?? false;
    
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: const Color(0xFF1E3A8A),
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _revenueController.dispose();
    _termsLabelController.dispose();
    _signatureLabelController.dispose();
    _termsContentController.dispose();
    _managerPinController.dispose();
    _publicKeyController.dispose();
    _secretKeyController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLogo) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final file = File(image.path);
      final sizeInBytes = await file.length();
      final sizeInMb = sizeInBytes / (1024 * 1024);

      if (sizeInMb > 1.5) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image is too large (>1.5MB). This may slow down PDF generation. Please use a smaller image.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        if (isLogo) {
          _logoPath = image.path;
        } else {
          _signaturePath = image.path;
        }
      });
    }
  }

  void _save() async {
    try {
      if (_formKey.currentState!.validate()) {
        // Admin check for sensitive business info
        final settingsProvider = context.read<SettingsProvider>();
        final provider = context.read<InvoiceProvider>();
        if (provider.activeStaff != null) {
          final passController = TextEditingController();
          final authorized = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Admin Authorization'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Only Admin can update Business Profile & Currency. Enter Admin Password:'),
                  const SizedBox(height: 16),
                  TextField(controller: passController, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Password')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                TextButton(
                  onPressed: () {
                    final managerPin = settingsProvider.businessInfo?.managerPin ?? '1234';
                    Navigator.pop(context, passController.text == managerPin);
                  }, 
                  child: const Text('AUTHORIZE')
                ),
              ],
            ),
          );
          if (authorized != true) return;
          if (!mounted) return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Row(children: [CircularProgressIndicator(strokeWidth: 2, color: Colors.white), SizedBox(width: 12), Text('Syncing profile to cloud...')]), duration: Duration(seconds: 10))
        );

        final info = BusinessInfo(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          logoPath: _logoPath,
          signaturePath: _signaturePath,
          revenueGoal: double.tryParse(_revenueController.text) ?? 0.0,
          currency: _selectedCurrency,
          terms: _termsContentController.text,
          pdfTermsLabel: _termsLabelController.text,
          pdfSignatureLabel: _signatureLabelController.text,
          pdfTemplate: _selectedTemplate,
          managerPin: _managerPinController.text,
          paymentGateway: _selectedGateway,
          gatewayPublicKey: _publicKeyController.text,
          gatewaySecretKey: _secretKeyController.text,
          isPaymentEnabled: _isPaymentEnabled,
          isLiveMode: _isLiveMode,
        );
        
        await settingsProvider.updateBusinessInfo(info);
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fix the errors in the form'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _exportInvoicesToCSV() async {
    try {
      final invoiceProvider = context.read<InvoiceProvider>();
      if (invoiceProvider.activeStaff != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admin can export data')));
        return;
      }
      final invoices = invoiceProvider.invoices;
      
      if (invoices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No invoices to export')));
        return;
      }

      List<List<dynamic>> rows = [];
      // Header
      rows.add(['Invoice ID', 'Date', 'Client', 'Amount', 'Paid', 'Status']);
      
      for (var inv in invoices) {
        rows.add([
          inv.id,
          inv.date.toString().split(' ')[0],
          inv.clientInfo.name,
          inv.total.toStringAsFixed(2),
          inv.amountPaid.toStringAsFixed(2),
          inv.isEstimate ? 'Estimate' : (inv.amountPaid >= inv.total ? 'Paid' : 'Unpaid'),
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/invoices_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      if (!mounted) return;
      await Share.shareXFiles([XFile(path)], text: 'Exported Invoices CSV');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _backupData() async {
    try {
      final invoiceProvider = context.read<InvoiceProvider>();
      final settingsProvider = context.read<SettingsProvider>();
      
      Map<String, dynamic> backup = {
        'version': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'businessInfo': settingsProvider.businessInfo?.toMap(),
        'customers': invoiceProvider.customers.map((e) => e.toMap()).toList(),
        'products': invoiceProvider.products.map((e) => e.toMap()).toList(),
        'invoices': invoiceProvider.invoices.map((e) => e.toMap()).toList(),
      };

      String jsonString = json.encode(backup);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/docara_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path);
      await file.writeAsString(jsonString);

      if (!mounted) return;
      await Share.shareXFiles([XFile(path)], text: 'Docara POS Backup File');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _restoreData() async {
    // Admin check for data restoration
    final provider = context.read<InvoiceProvider>();
    if (provider.activeStaff != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admin can restore backups')));
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (!mounted) return;

      if (result != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        
        if (!mounted) return;
        
        Map<String, dynamic> data = json.decode(content);

        if (!data.containsKey('version')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid backup file')));
          return;
        }

        final invoiceProvider = context.read<InvoiceProvider>();
        final settingsProvider = context.read<SettingsProvider>();

        // Restore Business Info
        if (data.containsKey('businessInfo')) {
          settingsProvider.updateBusinessInfo(BusinessInfo.fromMap(data['businessInfo']));
        }
        
        // Restore Invoices/Products/Customers
        invoiceProvider.loadFromBackup(data);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restoration successful!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Business Profile', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _pickImage(true),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: ClipOval(
                          child: _logoPath != null
                            ? (_logoPath!.startsWith('http')
                                ? Image.network(_logoPath!, fit: BoxFit.cover)
                                : (File(_logoPath!).existsSync()
                                    ? Image.file(File(_logoPath!), fit: BoxFit.cover)
                                    : Container(color: Colors.grey[50], child: Icon(Icons.add_a_photo_outlined, color: Colors.grey[400], size: 30))))
                            : Container(
                                color: Colors.grey[50],
                                child: Icon(Icons.add_a_photo_outlined, color: Colors.grey[400], size: 30),
                              ),
                        ),
                      ),
                    ),
                    if (_logoPath != null && File(_logoPath!).existsSync())
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _logoPath = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildCustomField('Business Name', _nameController, Icons.business_outlined, isRequired: true),
              _buildCustomField('Business Email', _emailController, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              _buildCustomField('Business Phone', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
              _buildCustomField('Business Address', _addressController, Icons.location_on_outlined, maxLines: 2),
              
              const SizedBox(height: 8),
              const Text('Default Currency', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildCurrencyDropdown(),
 
              _buildCustomField('Monthly Revenue Goal', _revenueController, Icons.radar, keyboardType: TextInputType.number),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 20),
                child: Text('Target revenue to track on your dashboard', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
              
              const Text('PDF Customization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const Text('Change the layout and labels on your PDF documents.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 16),
              
              const Text('Invoice Template', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildTemplateOption(PdfTemplate.sidebar, 'Sidebar', 'Modern')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTemplateOption(PdfTemplate.classic, 'Classic', 'Traditional')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTemplateOption(PdfTemplate.minimalist, 'Minimal', 'Clean')),
                ],
              ),
              const SizedBox(height: 24),

              _buildCustomField('Terms & Conditions Label', _termsLabelController, Icons.label_important_outline),
              _buildCustomField('Terms & Conditions Content', _termsContentController, Icons.description_outlined, maxLines: 3),
              _buildCustomField('Authorized Signature Label', _signatureLabelController, Icons.drive_file_rename_outline),
              
              const SizedBox(height: 8),
 
              const Text('Business Signature', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const Text('This signature will appear on all your documents.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 16),
              _buildSectionHeader('PDF & Security Settings'),
              const SizedBox(height: 16),
              _buildCustomField('Manager PIN', _managerPinController, Icons.lock_outline, keyboardType: TextInputType.number, isRequired: true),
              const SizedBox(height: 16),
              _buildSignatureBox(),
 
              const SizedBox(height: 40),
              _buildSectionHeader('Payment Integration (SaaS)'),
              const Text('Connect your payment gateway to accept card and mobile money payments directly.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 16),
              
              const Text('Payment Provider', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildGatewayDropdown(),
              const SizedBox(height: 20),

              if (_selectedGateway != PaymentGateway.none) ...[
                _buildCustomField('Gateway Public Key', _publicKeyController, Icons.vpn_key_outlined),
                _buildCustomField('Gateway Secret Key', _secretKeyController, Icons.lock_person_outlined, isPassword: true),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Enable Payments', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Allow customers to pay via gateway', style: TextStyle(fontSize: 11)),
                        value: _isPaymentEnabled,
                        onChanged: (val) => setState(() => _isPaymentEnabled = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Live Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Switch between Test and Real money', style: TextStyle(fontSize: 11)),
                        value: _isLiveMode,
                        onChanged: (val) => setState(() => _isLiveMode = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              const SizedBox(height: 40),
              _buildActionButton(Icons.download_outlined, 'Export Invoices to CSV', _exportInvoicesToCSV),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildActionButton(Icons.cloud_upload_outlined, 'Back Up', _backupData, isHalf: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildActionButton(Icons.cloud_download_outlined, 'Restore', _restoreData, isHalf: true, color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('SAVE PROFILE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
      ),
    );
  }
  Widget _buildCustomField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, int maxLines = 1, bool isRequired = false, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            obscureText: isPassword,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF1E293B), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            ),
            validator: (v) {
              if (isRequired && (v == null || v.isEmpty)) {
                return 'Field required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCurrency,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: <String>['\u20B5', '\$', '\u00A3', '\u20AC', '\u20A6'].map((val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_outlined, color: Color(0xFF1E293B), size: 20),
                  const SizedBox(width: 12),
                  Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedCurrency = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildGatewayDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PaymentGateway>(
          value: _selectedGateway,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: PaymentGateway.values.map((val) {
            return DropdownMenuItem<PaymentGateway>(
              value: val,
              child: Row(
                children: [
                  Icon(
                    val == PaymentGateway.none ? Icons.money_off_outlined : Icons.account_balance_outlined, 
                    color: const Color(0xFF1E293B), 
                    size: 20
                  ),
                  const SizedBox(width: 12),
                  Text(val.name.toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedGateway = val);
            }
          },
        ),
      ),
    );
  }

  Future<void> _saveSignature() async {
    if (_signatureController.isNotEmpty) {
      final image = await _signatureController.toPngBytes();
      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(path);
        await file.writeAsBytes(image);
        setState(() {
          _signaturePath = path;
          _isSigning = false;
        });
      }
    }
  }

  Widget _buildSignatureBox() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (_isSigning)
              Signature(
                controller: _signatureController,
                backgroundColor: Colors.white,
                height: 220,
              )
            else if (_signaturePath != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _signaturePath!.startsWith('http')
                      ? Image.network(_signaturePath!, fit: BoxFit.contain)
                      : (File(_signaturePath!).existsSync()
                          ? Image.file(File(_signaturePath!), fit: BoxFit.contain)
                          : const SizedBox.shrink()),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_note, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    const Text('No signature yet', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            
            // Buttons Overlay
            Positioned(
              bottom: 10,
              right: 10,
              child: Row(
                children: [
                  if (_isSigning) ...[
                    IconButton(
                      onPressed: () => _signatureController.clear(),
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      tooltip: 'Clear',
                    ),
                    IconButton(
                      onPressed: _saveSignature,
                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                      tooltip: 'Save Signature',
                    ),
                  ] else ...[
                    if (_signaturePath != null)
                      IconButton(
                        onPressed: () => setState(() => _signaturePath = null),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete Signature',
                      ),
                    IconButton(
                      onPressed: () => setState(() => _isSigning = true),
                      icon: Icon(Icons.edit_outlined, color: Colors.indigo[900]),
                      tooltip: 'Sign',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateOption(PdfTemplate template, String title, String subtitle) {
    final isSelected = _selectedTemplate == template;
    return GestureDetector(
      onTap: () => setState(() => _selectedTemplate = template),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A).withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey[200]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(
              _getTemplateIcon(template),
              color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey[400],
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getTemplateIcon(PdfTemplate template) {
    switch (template) {
      case PdfTemplate.sidebar: return Icons.view_sidebar_outlined;
      case PdfTemplate.classic: return Icons.view_headline_outlined;
      case PdfTemplate.minimalist: return Icons.notes_outlined;
    }
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {bool isHalf = false, Color? color}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color ?? const Color(0xFF1E3A8A)),
      label: Text(label, style: TextStyle(color: color ?? const Color(0xFF1E3A8A), fontWeight: FontWeight.w600, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
      ),
    );
  }
}
