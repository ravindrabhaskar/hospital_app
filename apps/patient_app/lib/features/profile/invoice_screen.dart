import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/save_file/save_file.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pdf_viewer.dart';
import '../../core/widgets/state_views.dart';
import '../../models/billing.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

/// `/payments/:id/invoice`: the tax invoice rendered in-app (§32) with a
/// PDF view and share/download.
class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key, required this.paymentId});
  final String paymentId;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  bool _sharing = false;

  String _fileName(Invoice i) => 'invoice-${i.number.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '-')}.pdf';

  Future<void> _share(Invoice i) async {
    final subject = context.l10n.invoiceNo(i.number);
    setState(() => _sharing = true);
    try {
      final bytes = await ref.read(paymentRepositoryProvider).invoicePdf(widget.paymentId);
      await saveOrShareFile(bytes: bytes, fileName: _fileName(i), mimeType: 'application/pdf', subject: subject);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = ref.watch(invoiceProvider(widget.paymentId));
    return Scaffold(
      appBar: AppBar(title: Text(l.invoice)),
      body: AsyncView<Invoice>(
        value: v,
        onRetry: () => ref.invalidate(invoiceProvider(widget.paymentId)),
        data: (i) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [InvoiceView(invoice: i)],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openPdf(
                          context,
                          title: l.invoiceNo(i.number),
                          fileName: _fileName(i),
                          load: () => ref.read(paymentRepositoryProvider).invoicePdf(widget.paymentId),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(l.viewPdf),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _sharing ? null : () => _share(i),
                        icon: _sharing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(kIsWeb ? Icons.download_outlined : Icons.ios_share),
                        label: Text(kIsWeb ? l.download : l.share),
                      ),
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

class InvoiceView extends StatelessWidget {
  const InvoiceView({super.key, required this.invoice});
  final Invoice invoice;

  String _amt(num v) => money(v);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final i = invoice;
    final muted = TextStyle(color: context.textMuted, fontSize: 12.5);
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null)),
              Text(value,
                  style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 17 : 14)),
            ],
          ),
        );
    return CcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(l.taxInvoice, style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Text(l.invoiceNo(i.number), style: muted),
                    Text(fmtDate(context, i.issuedAt), style: muted),
                  ],
                ),
              ),
              Icon(Icons.receipt_long_outlined, color: context.brand, size: 32),
            ],
          ),
          const SizedBox(height: Space.md),
          const Divider(),
          const SizedBox(height: Space.sm),
          Text(l.soldBy, style: muted),
          Text(i.sellerLegalName, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (i.sellerAddress.isNotEmpty) Text(i.sellerAddress, style: muted),
          if (i.sellerGstin != null && i.sellerGstin!.isNotEmpty) Text('GSTIN: ${i.sellerGstin}', style: muted),
          const SizedBox(height: Space.md),
          Text(l.billedTo, style: muted),
          Text(i.billedToName, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (i.billedToPhone.isNotEmpty) Text(i.billedToPhone, style: muted),
          const SizedBox(height: Space.md),
          const Divider(),
          for (final line in i.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.description),
                        Text(
                          [
                            if (line.sacCode != null && line.sacCode!.isNotEmpty) 'SAC ${line.sacCode}',
                            l.taxRateLabel('${line.taxRate}'),
                          ].join(' · '),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  Text(_amt(line.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const Divider(),
          row(l.subtotal, _amt(i.subtotal)),
          row(l.tax, _amt(i.tax)),
          row(l.totalAmount, _amt(i.total), bold: true),
          if (i.refundedAmount > 0) row(l.refundedLabel, '− ${_amt(i.refundedAmount)}'),
          const SizedBox(height: Space.sm),
          Text(l.invoiceFooter, style: muted),
        ],
      ),
    );
  }
}
