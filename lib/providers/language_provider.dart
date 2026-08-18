import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageItem {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const LanguageItem({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}

const supportedLanguages = [
  LanguageItem(code: 'en', name: 'English', nativeName: 'English (US)', flag: '🇺🇸'),
  LanguageItem(code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸'),
  LanguageItem(code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷'),
  LanguageItem(code: 'de', name: 'German', nativeName: 'Deutsch', flag: '🇩🇪'),
  LanguageItem(code: 'ar', name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦'),
  LanguageItem(code: 'pt', name: 'Portuguese', nativeName: 'Português', flag: '🇧🇷'),
  LanguageItem(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili', flag: '🇰🇪'),
  LanguageItem(code: 'ha', name: 'Hausa', nativeName: 'Harshen Hausa', flag: '🇳🇬'),
  LanguageItem(code: 'yo', name: 'Yoruba', nativeName: 'Èdè Yorùbá', flag: '🇳🇬'),
];

const Map<String, Map<String, String>> _translations = {
  'en': {
    'app_name': 'MurihSpace',
    'wallet': 'Financial & Escrow Hub',
    'recent_calls': 'Recent Calls',
    'devices': 'Devices & Active Sessions',
    'saved_messages': 'Saved Messages & Notes',
    'chat_folders': 'Chat Folders',
    'appearance': 'Appearance & Themes',
    'language': 'Language & Translation',
    'brand_deals': 'Creator Hub & Brand Deals',
    'vendor_store': 'Vendor Store & Inventory',
    'community_guidelines': 'Community Guidelines & Policies',
    'security': 'Security & App Lock',
  },
  'es': {
    'app_name': 'MurihSpace',
    'wallet': 'Centro Financiero y de Garantía',
    'recent_calls': 'Llamadas Recientes',
    'devices': 'Dispositivos y Sesiones Activas',
    'saved_messages': 'Mensajes Guardados y Notas',
    'chat_folders': 'Carpetas de Chat',
    'appearance': 'Apariencia y Temas',
    'language': 'Idioma y Traducción',
    'brand_deals': 'Centro de Creadores y Ofertas',
    'vendor_store': 'Tienda de Vendedores e Inventario',
    'community_guidelines': 'Directrices de la Comunidad',
    'security': 'Seguridad y Bloqueo',
  },
  'fr': {
    'app_name': 'MurihSpace',
    'wallet': 'Portefeuille & Sequestre',
    'recent_calls': 'Appels Récents',
    'devices': 'Appareils & Sessions Actives',
    'saved_messages': 'Messages Enregistrés',
    'chat_folders': 'Dossiers de Discussion',
    'appearance': 'Apparence & Thèmes',
    'language': 'Langue & Traduction',
    'brand_deals': 'Hub Créateurs & Contrats',
    'vendor_store': 'Boutique Vendeur & Stocks',
    'community_guidelines': 'Règles de la Communauté',
    'security': 'Sécurité & Verrouillage',
  },
  'ar': {
    'app_name': 'موري الفضاء',
    'wallet': 'المركز المالي والضمان',
    'recent_calls': 'المكالمات الأخيرة',
    'devices': 'الأجهزة والجلسات النشطة',
    'saved_messages': 'الرسائل والملاحظات المحفوظة',
    'chat_folders': 'مجلدات الدردشة',
    'appearance': 'المظهر والسمات',
    'language': 'اللغة والترجمة',
    'brand_deals': 'مركز المنشئين وصفقات العلامات التجارية',
    'vendor_store': 'متجر البائع والمخزون',
    'community_guidelines': 'إرشادات وسياسات المجتمع',
    'security': 'الأمان وقفل التطبيق',
  },
  'sw': {
    'app_name': 'MurihSpace',
    'wallet': 'Kituo cha Fedha na Escrow',
    'recent_calls': 'Simu za Hivi Karibuni',
    'devices': 'Vifaa na Vipindi Halisi',
    'saved_messages': 'Ujumbe Uliohifadhiwa',
    'chat_folders': 'Folda za Mazungumzo',
    'appearance': 'Muonekano na Mandhari',
    'language': 'Lugha na Tafsiri',
    'brand_deals': 'Kituo cha Waumbaji na Mikataba',
    'vendor_store': 'Duka la Muuzaji na Inbentari',
    'community_guidelines': 'Miongozo ya Jamii na Sera',
    'security': 'Ulinzi na Kufuli cha Programu',
  },
  'ha': {
    'app_name': 'MurihSpace',
    'wallet': 'Cibiyar Kudade da Escrow',
    'recent_calls': 'Kiraye-Kiraye na Baya-Bayan Nan',
    'devices': 'Na\'urori da Tattara Bayanai',
    'saved_messages': 'Sakonni da Aka Ajiye',
    'chat_folders': 'Jakar Hirarraki',
    'appearance': 'Chanjin Siffa da Launi',
    'language': 'Harshe da Fassarar Harshe',
    'brand_deals': 'Cibiyar Masu Sana\'a',
    'vendor_store': 'Shagon Mai Siyarwa',
    'community_guidelines': 'Dokokin Al\'umma',
    'security': 'Tsaro da Kulle Aikace-Aikace',
  },
  'yo': {
    'app_name': 'MurihSpace',
    'wallet': 'Ibudo Iṣuna & Escrow',
    'recent_calls': 'Àwọn Ipe Titun',
    'devices': 'Àwọn Ẹrọ & Awọn Akoko Ti N Ṣiṣẹ',
    'saved_messages': 'Àwọn Atunṣe Ti A Ti Penpe',
    'chat_folders': 'Àwọn Aapata Sọ̀rọ̀',
    'appearance': 'Iritsí & Àwọn Àwọ̀',
    'language': 'Èdè & Itumọ̀ Èdè',
    'brand_deals': 'Ibudo Awọn Olustẹda',
    'vendor_store': 'Stoo Onibara & Awọn Ọja',
    'community_guidelines': 'Àwọn Ilana Àwùjọ',
    'security': 'Aabo & Tiipa App',
  },
};

class LanguageState {
  final LanguageItem currentLanguage;

  LanguageState({
    this.currentLanguage = const LanguageItem(code: 'en', name: 'English', nativeName: 'English (US)', flag: '🇺🇸'),
  });

  String tr(String key) {
    return _translations[currentLanguage.code]?[key] ?? _translations['en']?[key] ?? key;
  }

  LanguageState copyWith({LanguageItem? currentLanguage}) {
    return LanguageState(currentLanguage: currentLanguage ?? this.currentLanguage);
  }
}

class LanguageNotifier extends Notifier<LanguageState> {
  @override
  LanguageState build() {
    return LanguageState();
  }

  void setLanguage(LanguageItem item) {
    state = state.copyWith(currentLanguage: item);
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, LanguageState>(LanguageNotifier.new);
