import 'package:flutter/material.dart';
import '../../data/notifiers.dart';
import '../../general_files/color_hex.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  // Localized texts for Privacy Policy
  static const Map<String, Map<String, String>> _localizedContent = {
    'English': {
      'title': 'PRIVACY POLICY',
      'intro_title': '1. Introduction',
      'intro_desc': 'Welcome to Heka. We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and protect your information when you use our application.',
      'collect_title': '2. Data Collection',
      'collect_desc': 'We collect information you provide, such as your name, email address, and profile details during account creation. We also process images of hieroglyphs uploaded or captured using the camera for translation.',
      'use_title': '3. How We Use Your Data',
      'use_desc': 'Your data is used to provide accurate translation services, maintain your personal search/translation history, allow bookmarking, secure your account, and improve the translation models.',
      'security_title': '4. Camera & Image Security',
      'security_desc': 'Images processed for translations are sent securely to our servers. We do not store your raw photos permanently, and they are processed solely for performing optical character recognition and translation.',
      'rights_title': '5. Your Rights & Consent',
      'rights_desc': 'You can view, edit, or delete your profile information at any time. By using this app, you consent to the collection and processing of your data as outlined in this Privacy Policy.',
      'contact_title': '6. Contact Us',
      'contact_desc': 'If you have any questions or suggestions about our Privacy Policy, do not hesitate to contact us at support@heka-app.com.',
    },
    'Arabic': {
      'title': 'سياسة الخصوصية',
      'intro_title': '١. مقدمة',
      'intro_desc': 'مرحباً بك في هيكا. نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. توضح سياسة الخصوصية هذه كيفية جمع معلوماتك واستخدامها وحمايتها عند استخدام تطبيقنا.',
      'collect_title': '٢. جمع البيانات',
      'collect_desc': 'نقوم بجمع المعلومات التي تقدمها، مثل اسمك وبريدك الإلكتروني وتفاصيل ملفك الشخصي أثناء إنشاء الحساب. نقوم أيضاً بمعالجة صور الرموز الهيروغليفية التي تم تحميلها أو التقاطها باستخدام الكاميرا للترجمة.',
      'use_title': '٣. كيف نستخدم بياناتك',
      'use_desc': 'تُستخدم بياناتك لتقديم خدمات ترجمة دقيقة، والاحتفاظ بسجل البحث/الترجمة الشخصي الخاص بك، والسماح بالإشارات المرجعية، وتأمين حسابك، وتحسين نماذج الترجمة.',
      'security_title': '٤. أمان الكاميرا والصور',
      'security_desc': 'يتم إرسال الصور المعالجة للترجمة بشكل آمن إلى خوادمنا. نحن لا نخزن صورك الأصلية بشكل دائم، ويتم معالجتها فقط لإجراء التعرف البصري على الحروف والترجمة.',
      'rights_title': '٥. حقوقك وموافقتك',
      'rights_desc': 'يمكنك عرض معلومات ملفك الشخصي أو تعديلها أو حذفها في أي وقت. باستخدام هذا التطبيق، فإنك توافق على جمع بياناتك ومعالجتها كما هو موضح في سياسة الخصوصية هذه.',
      'contact_title': '٦. اتصل بنا',
      'contact_desc': 'إذا كان لديك أي أسئلة أو اقتراحات حول سياسة الخصوصية الخاصة بنا، فلا تتردد في الاتصال بنا على support@heka-app.com.',
    },
    'Italian': {
      'title': 'INFORMATIVA SULLA PRIVACY',
      'intro_title': '1. Introduzione',
      'intro_desc': 'Benvenuto in Heka. Rispettiamo la tua privacy e ci impegniamo a proteggere i tuoi dati personali. Questa informativa spiega come raccogliamo, utilizziamo e proteggiamo le tue informazioni.',
      'collect_title': '2. Raccolta Dati',
      'collect_desc': "Raccogliamo le informazioni fornite, come nome, indirizzo email e dettagli del profilo durante la creazione dell'account. Elaboriamo anche le immagini dei geroglifici caricate o acquisite per la traduzione.",
      'use_title': '3. Come Utilizziamo i Dati',
      'use_desc': 'I tuoi dati vengono utilizzati per fornire servizi di traduzione accurati, mantenere la cronologia delle ricerche, consentire il salvataggio dei preferiti, proteggere il tuo account e migliorare i modelli.',
      'security_title': '4. Sicurezza della Fotocamera e Immagini',
      'security_desc': 'Le immagini elaborate per le traduzioni vengono inviate in modo sicuro ai nostri server. Non memorizziamo in modo permanente le tue foto originali, che vengono elaborate esclusivamente per la traduzione.',
      'rights_title': '5. Diritti e Consenso',
      'rights_desc': 'Puoi visualizzare, modificare o eliminare le informazioni del tuo profilo in qualsiasi momento. Utilizzando l\'app, acconsenti alla raccolta e al trattamento dei dati descritti in questa informativa.',
      'contact_title': '6. Contattaci',
      'contact_desc': 'Se hai domande o suggerimenti sulla nostra Informativa sulla privacy, non esitare a contattarci all\'indirizzo support@heka-app.com.',
    },
    'German': {
      'title': 'DATENSCHUTZERKLÄRUNG',
      'intro_title': '1. Einführung',
      'intro_desc': 'Willkommen bei Heka. Wir respektieren Ihre Privatsphäre und verpflichten uns, Ihre persönlichen Daten zu schützen. Diese Datenschutzerklärung erklärt, wie wir Ihre Informationen sammeln, verwenden und schützen.',
      'collect_title': '2. Datenerhebung',
      'collect_desc': 'Wir sammeln Informationen, die Sie angeben, wie Name, E-Mail-Adresse und Profildetails bei der Kontoerstellung. Wir verarbeiten auch Bilder von Hieroglyphen, die zur Übersetzung hochgeladen oder aufgenommen wurden.',
      'use_title': '3. Verwendung Ihrer Daten',
      'use_desc': 'Ihre Daten werden verwendet, um genaue Übersetzungsdienste bereitzustellen, Ihren Suchverlauf zu verwalten, Lesezeichen zu ermöglichen, Ihr Konto zu sichern und die Übersetzungsmodelle zu verbessern.',
      'security_title': '4. Kamera- und Bildsicherheit',
      'security_desc': 'Für Übersetzungen verarbeitete Bilder werden sicher an unsere Server gesendet. Wir speichern Ihre Originalfotos nicht dauerhaft; sie werden ausschließlich zur Zeichenerkennung und Übersetzung verarbeitet.',
      'rights_title': '5. Ihre Rechte & Einwilligung',
      'rights_desc': 'Sie können Ihre Profilinformationen jederzeit einsehen, bearbeiten oder löschen. Durch die Nutzung der App stimmen Sie der Erfassung und Verarbeitung Ihrer Daten gemäß dieser Datenschutzerklärung zu.',
      'contact_title': '6. Kontaktieren Sie uns',
      'contact_desc': 'Wenn Sie Fragen oder Anregungen zu unserer Datenschutzerklärung haben, zögern Sie nicht, uns unter support@heka-app.com zu kontaktieren.',
    },
    'Spanish': {
      'title': 'POLÍTICA DE PRIVACIDAD',
      'intro_title': '1. Introducción',
      'intro_desc': 'Bienvenido a Heka. Respetamos su privacidad y nos comprometemos a proteger sus datos personales. Esta política de privacidad explica cómo recopilamos, usamos y protegemos su información.',
      'collect_title': '2. Recopilación de Datos',
      'collect_desc': 'Recopilamos la información que proporciona, como su nombre, dirección de correo electrónico y detalles del perfil. También procesamos imágenes de jeroglíficos cargadas o capturadas para su traducción.',
      'use_title': '3. Cómo Usamos sus Datos',
      'use_desc': 'Sus datos se utilizan para proporcionar servicios de traducción precisos, mantener su historial de búsqueda, permitir marcadores, proteger su cuenta y mejorar los modelos de traducción.',
      'security_title': '4. Seguridad de la Cámara e Imagen',
      'security_desc': 'Las imágenes procesadas para las traducciones se envían de forma segura a nuestros servidores. No almacenamos sus fotos originales de forma permanente; se procesan únicamente para la traducción.',
      'rights_title': '5. Sus Derechos y Consentimiento',
      'rights_desc': 'Puede ver, editar o eliminar la información de su perfil en cualquier momento. Al usar esta aplicación, acepta la recopilación y el procesamiento de sus datos como se detalla en esta Política de Privacidad.',
      'contact_title': '6. Contáctenos',
      'contact_desc': 'Si tiene alguna pregunta o sugerencia sobre nuestra Política de Privacidad, no dude en contactarnos en support@heka-app.com.',
    },
    'Russian': {
      'title': 'ПОЛИТИКА КОНФИДЕНЦИАЛЬНОСТИ',
      'intro_title': '1. Введение',
      'intro_desc': 'Добро пожаловать в Heka. Мы уважаем вашу конфиденциальность и стремимся защищать ваши персональные данные. Эта политика конфиденциальности объясняет, как мы собираем, используем и защищаем вашу информацию.',
      'collect_title': '2. Сбор данных',
      'collect_desc': 'Мы собираем предоставленную вами информацию, такую как имя, адрес электронной почты и данные профиля. Мы также обрабатываем загруженные или снятые на камеру изображения иероглифов для перевода.',
      'use_title': '3. Использование данных',
      'use_desc': 'Ваши данные используются для предоставления точных услуг перевода, ведения вашей истории поиска, сохранения закладок, защиты учетной записи и улучшения моделей перевода.',
      'security_title': '4. Безопасность камеры и изображений',
      'security_desc': 'Изображения, обрабатываемые для перевода, безопасно отправляются на наши серверы. Мы не храним ваши исходные фотографии постоянно; они обрабатываются исключительно для распознавания и перевода.',
      'rights_title': '5. Ваши права и согласие',
      'rights_desc': 'Вы можете просматривать, изменять или удалять информацию своего профиля в любое время. Используя это приложение, вы соглашаетесь на сбор и обработку ваших данных, как описано в этой политике.',
      'contact_title': '6. Связаться с нами',
      'contact_desc': 'Если у вас есть какие-либо вопросы или предложения относительно нашей Политики конфиденциальности, свяжитесь с нами по адресу support@heka-app.com.',
    },
    'Polish': {
      'title': 'POLITYKA PRYWATNOŚCI',
      'intro_title': '1. Wprowadzenie',
      'intro_desc': 'Witamy w Heka. Szanujemy Twoją prywatność i zobowiązujemy się do ochrony Twoich danych osobowych. Niniejsza polityka prywatności wyjaśnia, jak zbieramy, wykorzystujemy i chronimy Twoje informacje.',
      'collect_title': '2. Zbieranie Danych',
      'collect_desc': 'Zbieramy informacje, które podajesz, takie jak imię, adres e-mail i dane profilu podczas tworzenia konta. Przetwarzamy również zdjęcia hieroglifów przesłane lub zrobione aparatem do tłumaczenia.',
      'use_title': '3. Jak Wykorzystujemy Dane',
      'use_desc': 'Twoje dane są wykorzystywane do świadczenia dokładnych usług tłumaczeniowych, prowadzenia historii wyszukiwania, umożliwiania dodawania zakładek, zabezpieczania konta i ulepszania modeli tłumaczeń.',
      'security_title': '4. Bezpieczeństwo Aparatu i Zdjęć',
      'security_desc': 'Zdjęcia przetwarzane na potrzeby tłumaczeń są bezpiecznie przesyłane na nasze serwery. Nie przechowujemy Twoich oryginalnych zdjęć na stałe – są one przetwarzane wyłącznie w celu rozpoznawania znaków i tłumaczenia.',
      'rights_title': '5. Twoje Prawa i Zgoda',
      'rights_desc': 'Możesz w każdej chwili przeglądać, edytować lub usuwać dane swojego profilu. Korzystając z tej aplikacji, wyrażasz zgodę na zbieranie i przetwarzanie Twoich danych zgodnie z niniejszą Polityką prywatności.',
      'contact_title': '6. Kontakt z Nami',
      'contact_desc': 'Jeśli masz jakiekolwiek pytania lub sugestie dotyczące naszej Polityki prywatności, skontaktuj się z nami pod adresem support@heka-app.com.',
    }
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: selectedLanguageNotifier,
      builder: (context, language, _) {
        final content = _localizedContent[language] ?? _localizedContent['English']!;
        return ValueListenableBuilder<bool>(
          valueListenable: isDarkModeNotifier,
          builder: (context, isDarkMode, _) {
            final backgroundColor = isDarkMode
                ? Temple_Background_Dark
                : Temple_Background_Light;
            final cardColor = isDarkMode ? Temple_Card_Dark : Temple_Card_Light;
            final textColor = isDarkMode ? Temple_White : Temple_Black;

            Widget buildSection(String title, String body) {
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Temple_Gold.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Temple_Gold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: getAppFontFamily(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: getAppFontFamily(),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  content['title']!.toUpperCase(),
                  style: TextStyle(
                    color: Temple_Gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFamily: getAppFontFamily(),
                  ),
                ),
                centerTitle: true,
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      buildSection(content['intro_title']!, content['intro_desc']!),
                      buildSection(content['collect_title']!, content['collect_desc']!),
                      buildSection(content['use_title']!, content['use_desc']!),
                      buildSection(content['security_title']!, content['security_desc']!),
                      buildSection(content['rights_title']!, content['rights_desc']!),
                      buildSection(content['contact_title']!, content['contact_desc']!),
                      const SizedBox(height: 100), // Space for bottom navigation
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
