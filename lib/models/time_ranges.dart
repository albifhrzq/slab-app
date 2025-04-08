class TimeRanges {
  final int morningStart;
  final int middayStart;
  final int eveningStart;
  final int nightStart;

  TimeRanges({
    required this.morningStart,
    required this.middayStart,
    required this.eveningStart,
    required this.nightStart,
  });

  factory TimeRanges.fromJson(Map<String, dynamic> json) {
    return TimeRanges(
      morningStart: json['morningStart'] ?? 6,
      middayStart: json['middayStart'] ?? 12,
      eveningStart: json['eveningStart'] ?? 18,
      nightStart: json['nightStart'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'morningStart': morningStart,
      'middayStart': middayStart,
      'eveningStart': eveningStart,
      'nightStart': nightStart,
    };
  }

  TimeRanges copyWith({
    int? morningStart,
    int? middayStart,
    int? eveningStart,
    int? nightStart,
  }) {
    return TimeRanges(
      morningStart: morningStart ?? this.morningStart,
      middayStart: middayStart ?? this.middayStart,
      eveningStart: eveningStart ?? this.eveningStart,
      nightStart: nightStart ?? this.nightStart,
    );
  }
}
