import 'package:flutter/material.dart';
import 'package:babushka_pressure/services/database_service.dart';
import 'package:babushka_pressure/models/user_profile.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = DatabaseService.instance.getUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите профиль'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final users = snapshot.data ?? [];
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: users.length + 1,
            itemBuilder: (context, index) {
              if (index == users.length) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: Colors.teal,
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                  elevation: 0,
                  color: Colors.grey[100],
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final nameController = TextEditingController();
                      final ageController = TextEditingController();
                      final targetSysController =
                          TextEditingController(text: '120');
                      final targetDiaController =
                          TextEditingController(text: '80');
                      String selectedIcon = 'male';
                      final result = await showDialog(
                        context: context,
                        builder: (context) => StatefulBuilder(
                          builder: (context, setState) {
                            return AlertDialog(
                              title: const Text('Добавить профиль'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Имя профиля',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: ageController,
                                      decoration: const InputDecoration(
                                        labelText: 'Возраст',
                                        hintText: 'Например: 70',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 16),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                          'Целевое давление (норма пользователя):',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: targetSysController,
                                            decoration: const InputDecoration(
                                                labelText: 'Сист.'),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextField(
                                            controller: targetDiaController,
                                            decoration: const InputDecoration(
                                                labelText: 'Диас.'),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Выберите пол:'),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.male),
                                          color: selectedIcon == 'male'
                                              ? Colors.blue
                                              : Colors.grey,
                                          onPressed: () => setState(
                                              () => selectedIcon = 'male'),
                                          iconSize: 40,
                                        ),
                                        const SizedBox(width: 20),
                                        IconButton(
                                          icon: const Icon(Icons.female),
                                          color: selectedIcon == 'female'
                                              ? Colors.blue
                                              : Colors.grey,
                                          onPressed: () => setState(
                                              () => selectedIcon = 'female'),
                                          iconSize: 40,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Отмена'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final name = nameController.text.trim();
                                    final ageStr = ageController.text.trim();
                                    if (name.isEmpty) return;

                                    final age = int.tryParse(ageStr) ?? 0;
                                    final targetSys = int.tryParse(
                                            targetSysController.text) ??
                                        120;
                                    final targetDia = int.tryParse(
                                            targetDiaController.text) ??
                                        80;

                                    Navigator.pop(context, {
                                      'name': name,
                                      'age': age,
                                      'targetSystolic': targetSys,
                                      'targetDiastolic': targetDia,
                                      'iconKey': selectedIcon,
                                      'colorValue': 0,
                                    });
                                  },
                                  child: const Text('Сохранить'),
                                ),
                              ],
                            );
                          },
                        ),
                      );

                      if (result != null) {
                        await DatabaseService.instance.insertUser(result);
                        setState(() {
                          _usersFuture = DatabaseService.instance.getUsers();
                        });
                      }
                    },
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 48, color: Colors.teal),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Добавить профиль',
                              style: TextStyle(color: Colors.teal),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final user = users[index];
              return Card(
                color: Colors.teal[400],
                child: InkWell(
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Редактировать'),
                            onTap: () async {
                              Navigator.pop(context);
                              final nameController =
                                  TextEditingController(text: user['name']);
                              final ageController = TextEditingController(
                                  text: (user['age'] ?? 0).toString());
                              final targetSysController = TextEditingController(
                                  text: (user['targetSystolic'] ?? 120)
                                      .toString());
                              final targetDiaController = TextEditingController(
                                  text: (user['targetDiastolic'] ?? 80)
                                      .toString());
                              String selectedIcon = user['iconKey'];
                              final result = await showDialog(
                                context: context,
                                builder: (context) => StatefulBuilder(
                                  builder: (context, setState) {
                                    return AlertDialog(
                                      title:
                                          const Text('Редактировать профиль'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: nameController,
                                              decoration: const InputDecoration(
                                                labelText: 'Имя профиля',
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            TextField(
                                              controller: ageController,
                                              decoration: const InputDecoration(
                                                labelText: 'Возраст',
                                                hintText: 'Например: 70',
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                            const SizedBox(height: 16),
                                            const Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                  'Целевое давление (норма пользователя):',
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller:
                                                        targetSysController,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText: 'Сист.'),
                                                    keyboardType:
                                                        TextInputType.number,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: TextField(
                                                    controller:
                                                        targetDiaController,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText: 'Диас.'),
                                                    keyboardType:
                                                        TextInputType.number,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            const Text('Выберите пол:'),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.male),
                                                  color: selectedIcon == 'male'
                                                      ? Colors.blue
                                                      : Colors.grey,
                                                  onPressed: () => setState(
                                                      () => selectedIcon =
                                                          'male'),
                                                  iconSize: 40,
                                                ),
                                                const SizedBox(width: 20),
                                                IconButton(
                                                  icon:
                                                      const Icon(Icons.female),
                                                  color:
                                                      selectedIcon == 'female'
                                                          ? Colors.blue
                                                          : Colors.grey,
                                                  onPressed: () => setState(
                                                      () => selectedIcon =
                                                          'female'),
                                                  iconSize: 40,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Отмена'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            final name =
                                                nameController.text.trim();
                                            final ageStr =
                                                ageController.text.trim();
                                            if (name.isEmpty) return;

                                            final age =
                                                int.tryParse(ageStr) ?? 0;
                                            final targetSys = int.tryParse(
                                                    targetSysController.text) ??
                                                120;
                                            final targetDia = int.tryParse(
                                                    targetDiaController.text) ??
                                                80;

                                            Navigator.pop(context, {
                                              'id': user['id'],
                                              'name': name,
                                              'age': age,
                                              'targetSystolic': targetSys,
                                              'targetDiastolic': targetDia,
                                              'iconKey': selectedIcon,
                                              'colorValue':
                                                  user['colorValue'] ?? 0,
                                            });
                                          },
                                          child: const Text('Сохранить'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );

                              if (result != null) {
                                await DatabaseService.instance.updateUser(
                                  UserProfile(
                                    id: user['id'],
                                    name: result['name'],
                                    age: result['age'],
                                    targetSystolic: result['targetSystolic'],
                                    targetDiastolic: result['targetDiastolic'],
                                    iconKey: result['iconKey'],
                                    colorValue: result['colorValue'],
                                  ),
                                );
                                setState(() {
                                  _usersFuture =
                                      DatabaseService.instance.getUsers();
                                });
                              }
                            },
                          ),
                          ListTile(
                            leading:
                                const Icon(Icons.delete, color: Colors.red),
                            title: const Text('Удалить',
                                style: TextStyle(color: Colors.red)),
                            onTap: () async {
                              Navigator.pop(context);
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Удалить профиль?'),
                                  content: const Text(
                                      'Все записи этого пользователя также будут удалены.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Отмена'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Удалить',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await DatabaseService.instance
                                    .deleteUser(user['id']);
                                setState(() {
                                  _usersFuture =
                                      DatabaseService.instance.getUsers();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  onTap: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/home',
                      arguments: user['id'],
                    );
                  },
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          user['iconKey'] == 'male' ? Icons.male : Icons.female,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${user['age'] ?? 0} лет • Цель: ${user['targetSystolic'] ?? 120}/${user['targetDiastolic'] ?? 80}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
