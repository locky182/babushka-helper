class UserProfile {
  final int? id;
  final String name;
  final String iconKey; // Для хранения названия иконки
  final int colorValue;

  UserProfile(
      {this.id,
      required this.name,
      required this.iconKey,
      required this.colorValue});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'colorValue': colorValue,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'],
        name: map['name'],
        iconKey: map['iconKey'],
        colorValue: map['colorValue'],
      );
}
