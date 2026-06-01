import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/models/payroll_model.dart';

class PdfService {
  static Future<pw.Document> _buildPayslipDocument(Payroll payroll) async {
    final pdf = pw.Document();
    pw.Font? baseFont;
    pw.Font? boldFont;

    try {
      baseFont = await PdfGoogleFonts.notoSansRegular();
      boldFont = await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      // Fallback to default PDF fonts when web/network blocks Google fonts.
      // In fallback mode we render currency as "NGN" to avoid missing glyph errors.
    }

    final supportsNairaSymbol = baseFont != null && boldFont != null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: (baseFont != null && boldFont != null)
            ? pw.ThemeData.withFont(base: baseFont, bold: boldFont)
            : null,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#008751'),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ROIPAYROLL',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'PAYSLIP',
                      style: const pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Employee Information',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildInfoRow('Name:', payroll.employeeName),
                    _buildInfoRow('Employee ID:', payroll.employeeId),
                    _buildInfoRow(
                      'Period:',
                      '${_getMonthName(payroll.month)} ${payroll.year}',
                    ),
                    _buildInfoRow('Date:', _formatDate(payroll.processedDate)),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EARNINGS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#008751'),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildAmountRow(
                      'Basic Salary',
                      payroll.basicSalary,
                      supportsNairaSymbol: supportsNairaSymbol,
                    ),
                    _buildAmountRow(
                      'Allowances',
                      payroll.allowances,
                      supportsNairaSymbol: supportsNairaSymbol,
                    ),
                    pw.Divider(thickness: 2),
                    _buildAmountRow(
                      'Gross Salary',
                      payroll.grossSalary,
                      bold: true,
                      supportsNairaSymbol: supportsNairaSymbol,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DEDUCTIONS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildAmountRow(
                      'PAYE Tax',
                      payroll.paye,
                      supportsNairaSymbol: supportsNairaSymbol,
                    ),
                    _buildAmountRow(
                      'Pension (8%)',
                      payroll.pension,
                      supportsNairaSymbol: supportsNairaSymbol,
                    ),
                    _buildAmountRow(
                      'NHF (2.5%)',
                      payroll.nhf,
                      supportsNairaSymbol: supportsNairaSymbol,
                    ),
                    if (payroll.loanDeduction > 0)
                      _buildAmountRow(
                        'Loan Deduction',
                        payroll.loanDeduction,
                        supportsNairaSymbol: supportsNairaSymbol,
                      ),
                    if (payroll.otherDeductions - payroll.loanDeduction > 0)
                      _buildAmountRow(
                        'Other Deductions',
                        payroll.otherDeductions - payroll.loanDeduction,
                        supportsNairaSymbol: supportsNairaSymbol,
                      ),
                    pw.Divider(thickness: 2),
                    _buildAmountRow(
                      'Total Deductions',
                      payroll.totalDeductions,
                      bold: true,
                      supportsNairaSymbol: supportsNairaSymbol,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                margin: const pw.EdgeInsets.symmetric(horizontal: 20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#008751'),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(10),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'NET PAY',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      _formatCurrencyForPdf(
                        payroll.netSalary,
                        supportsNairaSymbol: supportsNairaSymbol,
                      ),
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Center(
                  child: pw.Text(
                    'This is a computer-generated payslip and does not require a signature.',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<List<int>> generatePayslipBytes(Payroll payroll) async {
    final pdf = await _buildPayslipDocument(payroll);
    return pdf.save();
  }

  static Future<void> generatePayslip(Payroll payroll) async {
    final pdf = await _buildPayslipDocument(payroll);

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'Payslip_${payroll.employeeName}_${payroll.month}_${payroll.year}.pdf',
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(value),
        ],
      ),
    );
  }

  static pw.Widget _buildAmountRow(
    String label,
    double amount, {
    bool bold = false,
    bool supportsNairaSymbol = true,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            _formatCurrencyForPdf(
              amount,
              supportsNairaSymbol: supportsNairaSymbol,
            ),
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCurrencyForPdf(
    double amount, {
    required bool supportsNairaSymbol,
  }) {
    final formatted = CurrencyFormatter.formatNaira(amount);
    if (supportsNairaSymbol) return formatted;
    return formatted.replaceFirst('?', 'NGN ');
  }

  static String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
