class UserProfile {
  final int? id;
  final String name;
  final int age;
  final int targetSystolic;
  final int targetDiastolic;
  final String iconKey; // Для хранения названия иконки
  final int colorValue;

  UserProfile({
    this.id,
    required this.name,
    required this.age,
    this.targetSystolic = 120,
    this.targetDiastolic = 80,
    required this.iconKey,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'targetSystolic': targetSystolic,
        'targetDiastolic': targetDiastolic,
        'iconKey': iconKey,
        'colorValue': colorValue,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'],
        name: map['name'],
        age: map['age'] ?? 0,
        targetSystolic: map['targetSystolic'] ?? 120,
        targetDiastolic: map['targetDiastolic'] ?? 80,
        iconKey: map['iconKey'],
        colorValue: map['colorValue'],
      );
}
