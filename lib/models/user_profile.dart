class UserProfile {
  final int? id;
  final String name;
  final int age;
  final String iconKey; // Для хранения названия иконки
  final int colorValue;

  UserProfile({
    this.id,
    required this.name,
    required this.age,
    required this.iconKey,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'iconKey': iconKey,
        'colorValue': colorValue,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'],
        name: map['name'],
        age: map['age'] ?? 0,
        iconKey: map['iconKey'],
        colorValue: map['colorValue'],
      );
}
