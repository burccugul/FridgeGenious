import 'package:flutter/material.dart';
import 'package:flutter_application/services/notification_service.dart';

class NotificationTestPage extends StatelessWidget {
  const NotificationTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Testi'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final notificationService = NotificationService();
                await notificationService.sendTestNotification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test bildirimi gönderildi')),
                );
              },
              child: const Text('Test Bildirimi Gönder'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final notificationService = NotificationService();
                await notificationService.scheduleNotificationInTwoMinutes(
                  id: 2,
                  title: '2 Dakika Sonra',
                  body: 'Bu bildirim 2 dakika sonra gösterilecek.',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('2 dakika sonra bildirim planlandı')),
                );
              },
              child: const Text('2 Dakika Sonra Bildirim Planla'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final notificationService = NotificationService();
                await notificationService.scheduleNotificationAtSpecificTime(
                  id: 3,
                  title: 'Günlük Bildirim',
                  body: 'Bu bildirim her gün gösterilecek.',
                  hour: 19, // Saat 9'da (doğru değer)
                  minute: 11, // 0 dakika (doğru değer)
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Günlük bildirim saat 9:00 için planlandı')),
                );
              },
              child: const Text('Günlük Bildirim Planla (9:00)'),
            ),
          ],
        ),
      ),
    );
  }
}
/*import 'package:flutter/material.dart';
import 'package:flutter_application/services/notification_service.dart';
import 'dart:developer' as developer;

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({Key? key}) : super(key: key);

  @override
  _NotificationTestPage createState() => _NotificationTestPage();
}

class _NotificationTestPage extends State<NotificationTestPage> {
  final NotificationService _notificationService = NotificationService();
  String _status = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    developer.log("SendNotificationPage initState çağrıldı");
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    developer.log("_initializeNotifications çağrıldı");
    try {
      await _notificationService.initialize();
      developer.log("Bildirim servisi başarıyla başlatıldı");

      // Bildirimlerin etkin olup olmadığını kontrol et
      bool isEnabled = await _notificationService.areNotificationsEnabled();
      developer.log("Bildirimler etkin mi: $isEnabled");

      setState(() {
        _status =
            "Bildirim servisi hazır (Bildirimler ${isEnabled ? 'etkin' : 'devre dışı'})";
      });
    } catch (e) {
      developer.log("Bildirim servisi başlatma hatası: $e", error: e);
      setState(() {
        _status = "Hata: $e";
      });
    }
  }

  Future<void> _sendNotificationNow() async {
    developer.log("_sendNotificationNow çağrıldı");
    setState(() {
      _isLoading = true;
      _status = "Bildirim gönderiliyor...";
    });

    try {
      // Bildirimlerin etkin olduğundan emin ol
      bool isEnabled = await _notificationService.areNotificationsEnabled();
      developer.log("Bildirimler etkin mi: $isEnabled");

      if (!isEnabled) {
        developer.log("Bildirimler devre dışı, etkinleştiriliyor...");
        await _notificationService.setNotificationsEnabled(true);
      }

      // Anlık bir bildirim gönder
      developer.log("showNotification çağrılıyor...");
      await _notificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch % 10000, // Benzersiz ID için
        title: "Fridge Genius",
        body:
            "Bu bir test bildirimidir! Saat: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}",
        payload: "test_notification",
      );

      developer.log("Bildirim başarıyla gönderildi");
      setState(() {
        _status = "Bildirim başarıyla gönderildi!";
      });
    } catch (e) {
      developer.log("Bildirim hatası: $e", error: e);
      setState(() {
        _status = "Bildirim gönderilemedi: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirim Gönder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _sendNotificationNow,
              child: Text('Hemen Bildirim Gönder'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
            SizedBox(height: 30),
            _isLoading
                ? CircularProgressIndicator()
                : Text(
                    _status,
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
            SizedBox(height: 20),
            // Bildirimleri kontrol butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    developer.log("Bildirimleri etkinleştirme butonu tıklandı");
                    await _notificationService.setNotificationsEnabled(true);
                    bool isEnabled =
                        await _notificationService.areNotificationsEnabled();
                    setState(() {
                      _status =
                          "Bildirimler ${isEnabled ? 'etkinleştirildi' : 'etkinleştirilemedi'}";
                    });
                  },
                  child: Text('Bildirimleri Etkinleştir'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    bool isEnabled =
                        await _notificationService.areNotificationsEnabled();
                    setState(() {
                      _status =
                          "Bildirimler şu anda ${isEnabled ? 'etkin' : 'devre dışı'}";
                    });
                  },
                  child: Text('Bildirim Durumu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
*/
