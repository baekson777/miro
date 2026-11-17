enum Difficulty {
  /// 11×11 — shortest ranked / practice tier.
  veryEasy(label: '매우 쉬움', size: 11),

  /// 15×15
  easy(label: '쉬움', size: 15),

  /// 21×21
  normal(label: '중간', size: 21),

  /// 27×27
  hard(label: '어려움', size: 27),

  /// 33×33
  veryHard(label: '매우 어려움', size: 33);

  const Difficulty({required this.label, required this.size});

  final String label;
  final int size;
}
