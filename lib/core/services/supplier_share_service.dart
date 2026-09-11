import 'package:url_launcher/url_launcher.dart';
import '../../models/supplier.dart';

final class SupplierShareService {
  const SupplierShareService();

  Future<void> sendViaWhatsApp(Iterable<Supplier> suppliers) async {
    final contacts = suppliers.map(_format).join('\n');
    final text = 'Supplier contacts\n\n$contacts';
    final uri = Uri.https('wa.me', '/', {'text': text});
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('WhatsApp could not be opened on this device.');
    }
  }

  String _format(Supplier supplier) {
    final phones = supplier.phoneNumbers.join(', ');
    final address = supplier.businessAddress.trim();
    final category = supplier.category.trim();
    final parts = <String>['${supplier.fullName}: $phones'];
    if (category.isNotEmpty) parts.add(category);
    if (address.isNotEmpty) parts.add(address);
    return parts.join(' • ');
  }
}
