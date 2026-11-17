import 'dart:convert';

class HajjStage {
  final String id;
  final String category; // Tawaf, Sa'i, Wukuf, Jamarat, Pengumuman
  final String title;
  final String instruction;
  final String? arabicText;
  final String? latinText;
  final String? translation;

  HajjStage({
    required this.id,
    required this.category,
    required this.title,
    required this.instruction,
    this.arabicText,
    this.latinText,
    this.translation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'instruction': instruction,
      'arabicText': arabicText,
      'latinText': latinText,
      'translation': translation,
    };
  }

  factory HajjStage.fromMap(Map<String, dynamic> map) {
    return HajjStage(
      id: map['id'] ?? '',
      category: map['category'] ?? '',
      title: map['title'] ?? '',
      instruction: map['instruction'] ?? '',
      arabicText: map['arabicText'],
      latinText: map['latinText'],
      translation: map['translation'],
    );
  }

  String toJson() => json.encode(toMap());

  factory HajjStage.fromJson(String source) => HajjStage.fromMap(json.decode(source));

  // Daftar Tahapan Standar Haji / Umrah
  static List<HajjStage> get defaultStages => [
    // TAWAF
    HajjStage(
      id: 'tawaf_1',
      category: 'Tawaf',
      title: 'Tawaf - Putaran ke-1',
      instruction: 'Mulai sejajar Hajar Aswad, lambaikan tangan kanan sambil bertakbir.',
      arabicText: 'بِسْمِ اللَّهِ وَاللَّهُ أَكْبَرُ',
      latinText: 'Bismillahi wallahu akbar.',
      translation: 'Dengan nama Allah, dan Allah Maha Besar.',
    ),
    HajjStage(
      id: 'tawaf_2',
      category: 'Tawaf',
      title: 'Tawaf - Putaran ke-2',
      instruction: 'Jaga barisan rombongan, rapatkan langkah dan terus berdzikir.',
      arabicText: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      latinText: 'Rabbana atina fid-dunya hasanah wa fil-akhirati hasanah wa qina \'adzaban-nar.',
      translation: 'Ya Tuhan kami, berilah kami kebaikan di dunia dan kebaikan di akhirat, dan lindungilah kami dari siksa neraka.',
    ),
    HajjStage(
      id: 'tawaf_3',
      category: 'Tawaf',
      title: 'Tawaf - Putaran ke-3',
      instruction: 'Tetap dekat dengan rombongan, perhatikan aba-aba ketua.',
      arabicText: 'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلاَ إِلَهَ إِلاَّ اللَّهُ وَاللَّهُ أَكْبَرُ',
      latinText: 'Subhanallah walhamdulillah wa la ilaha illallah wallahu akbar.',
      translation: 'Maha Suci Allah, segala puji bagi Allah, tiada tuhan selain Allah, dan Allah Maha Besar.',
    ),
    HajjStage(
      id: 'tawaf_4',
      category: 'Tawaf',
      title: 'Tawaf - Putaran ke-4',
      instruction: 'Perbanyak istighfar dan mohon ampunan untuk keluarga.',
      arabicText: 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ',
      latinText: 'Astaghfirullahal-\'adzim wa atubu ilaih.',
      translation: 'Aku memohon ampunan kepada Allah Yang Maha Agung dan aku bertaubat kepada-Nya.',
    ),
    HajjStage(
      id: 'tawaf_5',
      category: 'Tawaf',
      title: 'Tawaf - Putaran ke-5',
      instruction: 'Antara Rukun Yamani dan Hajar Aswad baca doa sapu jagat.',
      arabicText: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      latinText: 'Rabbana atina fid-dunya hasanah...',
      translation: 'Ya Tuhan kami, berilah kami kebaikan di dunia dan akhirat.',
    ),
    HajjStage(
      id: 'tawaf_6',
      category: 'Tawaf',
      title: 'Tawaf - Putaran ke-6',
      instruction: 'Tetap tenang jangan saling dorong, jaga fisik.',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ',
      latinText: 'Allahumma inni as-alukal-\'afwa wal-\'afiyah.',
      translation: 'Ya Allah, sesungguhnya aku memohon kepada-Mu maaf dan keselamatan.',
    ),
    HajjStage(
      id: 'tawaf_7',
      category: 'Tawaf',
      title: 'Tawaf - Putaran ke-7 (Terakhir)',
      instruction: 'Putaran terakhir. Bersiap keluar pelan-pelan menuju belakang Maqam Ibrahim.',
      arabicText: 'اللَّهُمَّ حَجًّا مَبْرُورًا وَذَنْبًا مَغْفُورًا وَسَعْيًا مَشْكُورًا',
      latinText: 'Allahumma hajjan mabrura wa dzanban maghfura wa sa\'yan masykura.',
      translation: 'Ya Allah jadikanlah haji yang mabrur, dosa yang diampuni, dan usaha yang disyukuri.',
    ),

    // SA'I
    HajjStage(
      id: 'sai_1',
      category: 'Sa\'i',
      title: 'Sa\'i - Menuju Marwah (Putaran 1)',
      instruction: 'Berjalan dari Bukit Safa menuju Marwah. Laki-laki lari-lari kecil di lampu hijau.',
      arabicText: 'إِنَّ الصَّفَا وَالْمَرْوَةَ مِنْ شَعَائِرِ اللَّهِ',
      latinText: 'Innas-Safa wal-Marwata min sya\'a-irillah.',
      translation: 'Sesungguhnya Safa dan Marwah adalah sebagian dari syiar-syiar Allah.',
    ),
    HajjStage(
      id: 'sai_2',
      category: 'Sa\'i',
      title: 'Sa\'i - Menuju Safa (Putaran 2)',
      instruction: 'Berjalan dari Bukit Marwah kembali menuju Safa.',
      arabicText: 'رَبِّ اغْفِرْ وَارْحَمْ وَتَجَاوَزْ عَمَّا تَعْلَمْ إِنَّكَ أَنْتَ الأَعَزُّ الأَكْرَمُ',
      latinText: 'Rabbighfir warham wa tajawaz \'amma ta\'lam...',
      translation: 'Ya Tuhanku, ampuni, rahmati dan maafkanlah apa yang Engkau ketahui.',
    ),
    HajjStage(
      id: 'sai_7',
      category: 'Sa\'i',
      title: 'Sa\'i - Putaran ke-7 (Selesai)',
      instruction: 'Putaran terakhir selesai di Bukit Marwah. Bersiap untuk Tahallul (potong rambut).',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي هَدَانَا لِهَذَا',
      latinText: 'Alhamdulillahil-ladzi hadana lihadza.',
      translation: 'Segala puji bagi Allah yang telah menunjukkan kami kepada ini.',
    ),

    // RUKUN & ARAFAH / MINA
    HajjStage(
      id: 'wukuf_arafah',
      category: 'Arafah & Mina',
      title: 'Wukuf di Arafah',
      instruction: 'Waktu mustajab doa. Perbanyak dzikir, istighfar, dan doa pribadi di dalam tenda.',
      arabicText: 'لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      latinText: 'La ilaha illallah wahdahu la syarika lah, lahul-mulku wa lahul-hamdu wa huwa \'ala kulli syai-in qadir.',
      translation: 'Tiada tuhan selain Allah yang Maha Esa, tiada sekutu bagi-Nya. Bagi-Nya segala kerajaan dan pujian...',
    ),
    HajjStage(
      id: 'jamarat',
      category: 'Arafah & Mina',
      title: 'Melempar Jamarat',
      instruction: 'Pegang batu kerikil dengan tangan kanan. Lontar 7 butir satu per satu sambil bertakbir.',
      arabicText: 'بِسْمِ اللَّهِ، اللَّهُ أَكْبَرُ رَغْمًا لِلشَّيْطَانِ وَرِضًا لِلرَّحْمَنِ',
      latinText: 'Bismillahi, Allahu Akbar raghman lisy-syaithani wa ridhan lir-Rahman.',
      translation: 'Dengan nama Allah, Allah Maha Besar, merendahkan setan dan mencari ridha Ar-Rahman.',
    ),

    // DARURAT / KUMPUL
    HajjStage(
      id: 'kumpul_darurat',
      category: 'Instruksi',
      title: 'PERHATIAN: Kumpul di Titik Temu',
      instruction: 'Semua jamaah harap berhenti, jangan panik, dan segera mendekat ke arah bendera / ketua rombongan.',
      arabicText: null,
      latinText: null,
      translation: null,
    ),
  ];
}
