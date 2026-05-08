import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product_info.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'etiket_scans.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        brand TEXT,
        size TEXT,
        price REAL,
        scannedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE daily_specials(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        market TEXT,
        name TEXT,
        size TEXT,
        price REAL,
        fetchedAt TEXT
      )
    ''');
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_specials(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          market TEXT,
          name TEXT,
          size TEXT,
          price REAL,
          fetchedAt TEXT
        )
      ''');
    }
  }

  Future<void> insertScan(ProductInfo product) async {
    final db = await database;
    await db.insert(
      'scans',
      {
        'name': product.name,
        'brand': product.brand,
        'size': product.size,
        'price': product.price,
        'scannedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> cacheDailySpecials(List<ProductInfo> specials) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('daily_specials');
      for (final special in specials) {
        await txn.insert('daily_specials', {
          'market': special.brand,
          'name': special.name,
          'size': special.size,
          'price': special.price,
          'fetchedAt': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<ProductInfo>> getCachedDailySpecials() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T').first;
    final rows = await db.query(
      'daily_specials',
      where: 'date(fetchedAt) = ?',
      whereArgs: [today],
      orderBy: 'id ASC',
      limit: 5,
    );

    return rows.map((row) {
      return ProductInfo(
        name: row['name'] as String,
        brand: row['market'] as String,
        size: row['size'] as String,
        price: (row['price'] as num).toDouble(),
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentScans() async {
    final db = await database;
    return db.query('scans', orderBy: 'scannedAt DESC', limit: 20);
  }
}
