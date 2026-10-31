import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Single access point to SQLite (restaurants + orders).
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  /// Screens listen to this and reload whenever data changes.
  final ValueNotifier<int> version = ValueNotifier(0);

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'fasterfood.db');
    return openDatabase(
      path,
      version: 2,
      // Needed so deleting a restaurant also deletes its orders.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE restaurants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            cuisine TEXT NOT NULL,
            delivery_fee REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            restaurant_id INTEGER NOT NULL,
            items TEXT NOT NULL,
            subtotal REAL NOT NULL,
            delivery_fee REAL NOT NULL,
            tip_percent INTEGER NOT NULL,
            status INTEGER NOT NULL,
            date INTEGER NOT NULL,
            FOREIGN KEY (restaurant_id) REFERENCES restaurants(id) ON DELETE CASCADE
          )
        ''');
        await _seed(db);
      },
      // Version 2: the demo restaurants got real names (and logos).
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.update('restaurants', {'name': 'Burger King'},
              where: 'name = ?', whereArgs: ['Burger Barn']);
          await db.update('restaurants', {'name': 'Taco Bell'},
              where: 'name = ?', whereArgs: ['Taco Town']);
        }
      },
    );
  }

  /// Demo data: three restaurants with two orders each.
  Future<void> _seed(Database db) async {
    final now = DateTime.now();

    Future<int> addRestaurant(String name, String cuisine, double fee) async {
      return await db.insert('restaurants', {
        'name': name,
        'cuisine': cuisine,
        'delivery_fee': fee,
      });
    }

    Future<void> addOrder(int rid, String items, double subtotal, double fee,
        int tip, OrderStatus status, int daysAgo) async {
      await db.insert('orders', {
        'restaurant_id': rid,
        'items': items,
        'subtotal': subtotal,
        'delivery_fee': fee,
        'tip_percent': tip,
        'status': status.index,
        'date': now.subtract(Duration(days: daysAgo)).millisecondsSinceEpoch,
      });
    }

    final burger = await addRestaurant('Burger King', 'American', 2.99);
    await addOrder(burger, 'Cheeseburger, Fries', 14.50, 2.99, 15,
        OrderStatus.delivered, 10);
    await addOrder(burger, 'Double Burger, Milkshake', 18.75, 2.99, 18,
        OrderStatus.delivered, 3);

    final sushi = await addRestaurant('Sushi Spot', 'Japanese', 3.99);
    await addOrder(sushi, 'Salmon Roll, Miso Soup', 21.00, 3.99, 20,
        OrderStatus.delivered, 8);
    await addOrder(sushi, 'Dragon Roll, Edamame', 16.50, 3.99, 15,
        OrderStatus.onTheWay, 0);

    final taco = await addRestaurant('Taco Bell', 'Mexican', 1.99);
    await addOrder(taco, '3 Tacos, Chips and Salsa', 12.25, 1.99, 15,
        OrderStatus.delivered, 6);
    await addOrder(taco, 'Burrito Bowl', 11.00, 1.99, 10,
        OrderStatus.preparing, 1);
  }

  void _changed() => version.value++;

  // ---------- Restaurants ----------
  Future<List<Restaurant>> restaurants() async {
    final db = await _database;
    final rows = await db.query('restaurants', orderBy: 'name COLLATE NOCASE');
    return rows.map(Restaurant.fromMap).toList();
  }

  Future<Restaurant?> restaurant(int id) async {
    final db = await _database;
    final rows =
        await db.query('restaurants', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Restaurant.fromMap(rows.first);
  }

  Future<void> saveRestaurant(Restaurant r) async {
    final db = await _database;
    if (r.id == null) {
      await db.insert('restaurants', r.toMap()..remove('id'));
    } else {
      await db.update('restaurants', r.toMap(),
          where: 'id = ?', whereArgs: [r.id]);
    }
    _changed();
  }

  /// Orders are removed automatically by the foreign key (ON DELETE CASCADE).
  Future<void> deleteRestaurant(int id) async {
    final db = await _database;
    await db.delete('restaurants', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<int> orderCountFor(int restaurantId) async {
    final db = await _database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) FROM orders WHERE restaurant_id = ?', [restaurantId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------- Orders ----------
  Future<List<Order>> orders({int? restaurantId}) async {
    final db = await _database;
    final rows = await db.query(
      'orders',
      where: restaurantId == null ? null : 'restaurant_id = ?',
      whereArgs: restaurantId == null ? null : [restaurantId],
      orderBy: 'date DESC',
    );
    return rows.map(Order.fromMap).toList();
  }

  Future<void> saveOrder(Order o) async {
    final db = await _database;
    if (o.id == null) {
      await db.insert('orders', o.toMap()..remove('id'));
    } else {
      await db.update('orders', o.toMap(), where: 'id = ?', whereArgs: [o.id]);
    }
    _changed();
  }

  Future<void> deleteOrder(int id) async {
    final db = await _database;
    await db.delete('orders', where: 'id = ?', whereArgs: [id]);
    _changed();
  }
}
