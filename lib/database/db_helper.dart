import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:contacts_service/contacts_service.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'emergency_contacts.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        displayName TEXT,
        phoneNumber TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE emergency_contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        displayName TEXT,
        phoneNumber TEXT
      )
    ''');
  }

  Future<void> insertInitialContacts(List<Contact> contacts) async {
    final db = await database;

    for (var contact in contacts) {
      await db.insert(
        'contacts',
        {
          'displayName': contact.displayName,
          'phoneNumber': contact.phones?.isNotEmpty == true
              ? contact.phones!.first.value
              : '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getStoredContacts() async {
    final db = await database;
    return await db.query('contacts');
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final db = await database;
    return await db.query('emergency_contacts');
  }

  Future<void> insertEmergencyContact(Contact contact) async {
    final db = await database;
    await db.insert(
      'emergency_contacts',
      {
        'displayName': contact.displayName,
        'phoneNumber': contact.phones?.first.value ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteEmergencyContact(String phoneNumber) async {
    final db = await database;
    await db.delete(
      'emergency_contacts',
      where: 'phoneNumber = ?',
      whereArgs: [phoneNumber],
    );
  }
}
