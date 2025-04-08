class Profile {
  final int royalBlue;
  final int blue;
  final int uv;
  final int violet;
  final int red;
  final int green;
  final int white;

  Profile({
    required this.royalBlue,
    required this.blue,
    required this.uv,
    required this.violet,
    required this.red,
    required this.green,
    required this.white,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      royalBlue: json['royalBlue'] ?? 0,
      blue: json['blue'] ?? 0,
      uv: json['uv'] ?? 0,
      violet: json['violet'] ?? 0,
      red: json['red'] ?? 0,
      green: json['green'] ?? 0,
      white: json['white'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'royalBlue': royalBlue,
      'blue': blue,
      'uv': uv,
      'violet': violet,
      'red': red,
      'green': green,
      'white': white,
    };
  }

  Profile copyWith({
    int? royalBlue,
    int? blue,
    int? uv,
    int? violet,
    int? red,
    int? green,
    int? white,
  }) {
    return Profile(
      royalBlue: royalBlue ?? this.royalBlue,
      blue: blue ?? this.blue,
      uv: uv ?? this.uv,
      violet: violet ?? this.violet,
      red: red ?? this.red,
      green: green ?? this.green,
      white: white ?? this.white,
    );
  }
}
