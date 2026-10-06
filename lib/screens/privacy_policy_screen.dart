import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final bool isFirstTime;
  final VoidCallback? onAccepted;

  const PrivacyPolicyScreen({
    super.key,
    this.isFirstTime = false,
    this.onAccepted,
  });

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  void _loadStatus() async {
    final storage = await LocalStorageService.getInstance();
    if (mounted) {
      setState(() {
        _accepted = storage.isPrivacyPolicyAccepted;
      });
    }
  }

  void _handleAccept() async {
    final storage = await LocalStorageService.getInstance();
    await storage.setPrivacyPolicyAccepted(true);
    if (widget.onAccepted != null) {
      widget.onAccepted!();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gizlilik Politikası & Kullanım Şartları',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Icon & Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _accepted ? Colors.green.withValues(alpha: 0.1) : theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _accepted ? Icons.verified_user_rounded : Icons.security_rounded,
                            color: _accepted ? Colors.green : theme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NevGenç Veri Güvenliği',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Gizlilik Politikası ve Kullanım Şartları',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section 1: Yerel Depolama Kullanımı
                    _buildSectionCard(
                      context,
                      title: '1. Cihaz İçi Yerel Depolama (Local Storage)',
                      icon: Icons.sd_card_rounded,
                      content:
                          'NevGenç uygulaması, kullanıcı deneyiminizi ve çevrimdışı (offline) çalışma hızınızı artırmak amacıyla bazı uygulama verilerini cihazınızın yerel depolama alanında (SharedPreferences / Cache) saklar. Oturum bilgileriniz ise cihazınızın şifreli anahtarlığında (iOS Keychain / Android Keystore) korunur. Yerel depolanan veriler cihazınız dışına izniniz olmaksızın aktarılmaz.',
                    ),
                    const SizedBox(height: 16),

                    // Section 2: İzinler ve Veri Güvenliği
                    _buildSectionCard(
                      context,
                      title: '2. İzinler ve Veri Gizliliği',
                      icon: Icons.lock_outline_rounded,
                      content:
                          'Uygulamamız temel işlevleri için ağ erişimi (INTERNET) ve bildirim (POST_NOTIFICATIONS) izinlerinin yanı sıra; profil/gönderi görseli seçebilmeniz için kamera ve galeri, kampüs haritası ve yakınımdaki etkinlikler gibi özellikler için ise konum (GPS) iznini talep eder. Bu izinler yalnızca ilgili özelliği kullandığınızda etkindir, istediğiniz zaman cihaz ayarlarından geri alabilirsiniz ve hassas kişisel verileriniz üçüncü taraflarla paylaşılmaz.',
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Çevrimdışı Önbellek
                    _buildSectionCard(
                      context,
                      title: '3. Çevrimdışı Önbellekleme',
                      icon: Icons.cloud_off_rounded,
                      content:
                          'Uygulamamızda gezindiğiniz gönderiler ve haberler, internet bağlantınız olmadığında da hızlı erişim sağlayabilmeniz için cihazınızın yerel önbelleğinde saklanır. Dilediğiniz an Ayarlar menüsünden önbelleği temizleyebilirsiniz.',
                    ),
                    const SizedBox(height: 16),

                    // Section 4: İletişim & Haklarınız
                    _buildSectionCard(
                      context,
                      title: '4. Kullanıcı Hakları ve İletişim',
                      icon: Icons.contact_support_outlined,
                      content:
                          'Verilerinizin silinmesini talep etme veya yerel depolamayı temizleme hakkınız saklıdır. Sorularınız için destek ekibimizle iletişime geçebilirsiniz.',
                    ),
                    const SizedBox(height: 16),

                    // Section 5: Kullanım Şartları (App Store Kural 1.2)
                    _buildSectionCard(
                      context,
                      title: '5. Kullanım Şartları ve Topluluk Kuralları',
                      icon: Icons.gavel_rounded,
                      content:
                          'NevGenç\'te nefret söylemi, taciz, tehdit, müstehcenlik, şiddet, ayrımcılık, yanıltıcı veya yasa dışı içerik ile kötüye kullanıcı davranışlarına KESİNLİKLE tolerans gösterilmez. '
                          'Uygunsuz bir gönderiyi menüdeki "Şikayet Et" ile bildirebilir, "Topluluğu Engelle" ile akışınızdan kaldırabilirsiniz. '
                          'Şikayetler en geç 24 saat içinde incelenir; kurallara aykırı içerik kaldırılır ve ihlal eden hesaplar uygulamadan çıkarılır. '
                          'Uygulamayı kullanarak bu şartları kabul etmiş olursunuz.',
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _handleAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: Text(
                    widget.isFirstTime
                        ? 'Okudum, Anladım ve Kabul Ediyorum'
                        : 'Kabul Et ve Devam Et',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String content,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
