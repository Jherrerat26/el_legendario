import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> cargarMenuElLegendario(BuildContext context) async {
    final db = FirebaseFirestore.instance;
    
    // 1. VERIFICAR SI YA EXISTEN DATOS PARA NO DUPLICAR
    var check = await db.collection('productos').limit(1).get();
    if (check.docs.isNotEmpty) {
      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ ERROR: La base de datos ya tiene productos. Borra todo desde Firebase o hazlo manualmente para evitar duplicados."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          )
        );
      }
      return;
    }

    final batch = db.batch();

    // ======================================================
    // 1. CREAR INSUMOS (INVENTARIO UNIFICADO)
    // ======================================================
    Map<String, Map<String, dynamic>> insumos = {
      // PROTEÍNAS
      'Carne Desmechada': {'unidad': 'Porción', 'minimo': 30},
      'Pollo Desmechado': {'unidad': 'Porción', 'minimo': 30},
      'Cerdo Desmechado': {'unidad': 'Porción', 'minimo': 30},
      'Carne Trozo (Chuzo)': {'unidad': 'Porción', 'minimo': 20},
      'Pollo Trozo (Chuzo)': {'unidad': 'Porción', 'minimo': 20},
      'Cerdo Trozo (Chuzo)': {'unidad': 'Porción', 'minimo': 20},
      'Carne de Res 150g': {'unidad': 'Unidad', 'minimo': 20},
      'Carne de Res 300g': {'unidad': 'Unidad', 'minimo': 10},
      'Pechuga 300g': {'unidad': 'Unidad', 'minimo': 10},
      'Lomo de Cerdo 300g': {'unidad': 'Unidad', 'minimo': 10},
      'Punta Gorda 300g': {'unidad': 'Unidad', 'minimo': 10},
      'Churrasco 300g': {'unidad': 'Unidad', 'minimo': 10},

      // EMBUTIDOS
      'Butifarra': {'unidad': 'Unidad', 'minimo': 30},
      'Chorizo': {'unidad': 'Unidad', 'minimo': 30},
      'Salchicha Suiza': {'unidad': 'Unidad', 'minimo': 30},
      'Salchicha Ranchera': {'unidad': 'Unidad', 'minimo': 30},
      'Salchicha Tradicional': {'unidad': 'Unidad', 'minimo': 50},
      'Tocineta': {'unidad': 'Porción', 'minimo': 40},
      'Chorichuzo': {'unidad': 'Unidad', 'minimo': 20},

      // PANES Y BASES
      'Pan Brioche Perro': {'unidad': 'Unidad', 'minimo': 40},
      'Pan Brioche Hamburguesa': {'unidad': 'Unidad', 'minimo': 40},
      'Bollo de Maíz': {'unidad': 'Unidad', 'minimo': 20},
      'Arepa': {'unidad': 'Unidad', 'minimo': 20},

      // ACOMPAÑANTES
      'Papas a la Francesa': {'unidad': 'Porción', 'minimo': 50},
      'Papa Ripio': {'unidad': 'Porción', 'minimo': 50},
      'Queso Costeño': {'unidad': 'Porción', 'minimo': 50},
      'Queso Mozzarella': {'unidad': 'Loncha', 'minimo': 50},
      'Queso Amarillo': {'unidad': 'Loncha', 'minimo': 30},
      'Queso Gratinado': {'unidad': 'Porción', 'minimo': 30},
      'Lechuga': {'unidad': 'Porción', 'minimo': 30},
      'Maíz Desgranado': {'unidad': 'Porción', 'minimo': 30},
      'Ensalada': {'unidad': 'Porción', 'minimo': 20},
      'Salsa de la Casa': {'unidad': 'Porción', 'minimo': 100},
      'Salsa Tártara': {'unidad': 'Porción', 'minimo': 50},

      // BEBIDAS
      'Coca Cola Personal': {'unidad': 'Unidad', 'minimo': 24},
      'Coca Cola 1.25L': {'unidad': 'Unidad', 'minimo': 10},
      'Quatro Personal': {'unidad': 'Unidad', 'minimo': 24},
      'Quatro 1.5L': {'unidad': 'Unidad', 'minimo': 10},
      'Agua Manzana Personal': {'unidad': 'Unidad', 'minimo': 24},
      'Agua Manzana 1.5L': {'unidad': 'Unidad', 'minimo': 10},
      'Kola Román': {'unidad': 'Unidad', 'minimo': 24},
      'Ginger': {'unidad': 'Unidad', 'minimo': 12},
      'Soda': {'unidad': 'Unidad', 'minimo': 12},
      'Botella de Agua': {'unidad': 'Unidad', 'minimo': 24},
      'Jugo Hit': {'unidad': 'Unidad', 'minimo': 24},
      'Limonada Natural': {'unidad': 'Vaso', 'minimo': 20},
      'Limonada Cerezada': {'unidad': 'Vaso', 'minimo': 20},
      'Aguila Light': {'unidad': 'Unidad', 'minimo': 24},
      'Coronita': {'unidad': 'Unidad', 'minimo': 24},
    };

    Map<String, String> idInsumos = {};

    // Crear Insumos
    for (var entry in insumos.entries) {
      var ref = db.collection('inventario').doc();
      batch.set(ref, {
        'nombre': entry.key,
        'stock': 0.0,
        'minimo': double.parse(entry.value['minimo'].toString()),
        'unidad': entry.value['unidad']
      });
      idInsumos[entry.key] = ref.id;
    }

    // Función para armar recetas
    List<Map<String, dynamic>> receta(Map<String, double> ingredientes) {
      List<Map<String, dynamic>> resultado = [];
      ingredientes.forEach((nombre, cantidad) {
        if (idInsumos.containsKey(nombre)) {
          resultado.add({
            'idInsumo': idInsumos[nombre],
            'nombreInsumo': nombre,
            'cantidad': cantidad
          });
        }
      });
      return resultado;
    }

    // ======================================================
    // 2. CREAR CATEGORÍAS Y PRODUCTOS
    // ======================================================
    
    // --- CHUZOS ENTEROS ---
    var catChuzos = db.collection('categorias').doc();
    batch.set(catChuzos, {'nombre': 'CHUZOS ENTEROS'});
    
    List<Map<String, dynamic>> chuzos = [
      {'nombre': 'Chuzo Legendario', 'precio': 24000, 'costo': 12000, 'receta': receta({'Carne Trozo (Chuzo)': 1, 'Pollo Trozo (Chuzo)': 1, 'Cerdo Trozo (Chuzo)': 1, 'Butifarra': 1, 'Chorizo': 1, 'Salchicha Suiza': 1, 'Salchicha Ranchera': 1, 'Bollo de Maíz': 1})},
      {'nombre': 'Chuzo de Pollo', 'precio': 18000, 'costo': 9000, 'receta': receta({'Pollo Trozo (Chuzo)': 1, 'Bollo de Maíz': 1})},
      {'nombre': 'Chuzo de Cerdo', 'precio': 18000, 'costo': 9000, 'receta': receta({'Cerdo Trozo (Chuzo)': 1, 'Bollo de Maíz': 1})},
      {'nombre': 'Chuzo de Carne', 'precio': 19000, 'costo': 9500, 'receta': receta({'Carne Trozo (Chuzo)': 1, 'Bollo de Maíz': 1})},
      {'nombre': 'Chuzo Mixto', 'precio': 20000, 'costo': 10000, 'receta': receta({'Carne Trozo (Chuzo)': 0.5, 'Pollo Trozo (Chuzo)': 0.5, 'Bollo de Maíz': 1})},
      {'nombre': 'Chuzo Cuatro Carnes', 'precio': 20000, 'costo': 10000, 'receta': receta({'Carne Trozo (Chuzo)': 1, 'Pollo Trozo (Chuzo)': 1, 'Butifarra': 1, 'Chorizo': 1, 'Bollo de Maíz': 1})},
    ];

    // --- DESGRANADOS ---
    var catDesgranados = db.collection('categorias').doc();
    batch.set(catDesgranados, {'nombre': 'DESGRANADOS'});
    
    List<Map<String, dynamic>> desgranados = [
      {'nombre': 'Desgranado Legendario', 'precio': 25000, 'costo': 12500, 'receta': receta({'Carne Desmechada': 1, 'Pollo Desmechado': 1, 'Butifarra': 1, 'Chorizo': 1, 'Cerdo Desmechado': 1, 'Salchicha Suiza': 1, 'Salchicha Ranchera': 1, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Bollo de Maíz': 1})},
      {'nombre': 'Desgranado de Pollo', 'precio': 20000, 'costo': 10000, 'receta': receta({'Pollo Desmechado': 1, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Bollo de Maíz': 1})},
      {'nombre': 'Desgranado de Cerdo', 'precio': 20000, 'costo': 10000, 'receta': receta({'Cerdo Desmechado': 1, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Bollo de Maíz': 1})},
      {'nombre': 'Desgranado de Carne', 'precio': 22000, 'costo': 11000, 'receta': receta({'Carne Desmechada': 1, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Bollo de Maíz': 1})},
      {'nombre': 'Desgranado Mixto', 'precio': 22000, 'costo': 11000, 'receta': receta({'Carne Desmechada': 0.5, 'Pollo Desmechado': 0.5, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa Tártara': 1, 'Bollo de Maíz': 1})},
      {'nombre': 'Desgranado Cuatro Carnes', 'precio': 20000, 'costo': 10000, 'receta': receta({'Carne Desmechada': 1, 'Pollo Desmechado': 1, 'Butifarra': 1, 'Chorizo': 1, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Bollo de Maíz': 1})},
    ];

    // --- PERROS AL CARBÓN ---
    var catPerros = db.collection('categorias').doc();
    batch.set(catPerros, {'nombre': 'PERROS AL CARBÓN'});
    
    List<Map<String, dynamic>> perros = [
      {'nombre': 'Perro Legendario', 'precio': 40000, 'costo': 20000, 'receta': receta({'Pan Brioche Perro': 1, 'Carne Desmechada': 1, 'Pollo Desmechado': 1, 'Cerdo Desmechado': 1, 'Chorizo': 1, 'Butifarra': 1, 'Salchicha Ranchera': 1, 'Salchicha Suiza': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Papa Ripio': 1, 'Queso Costeño': 1, 'Maíz Desgranado': 1, 'Tocineta': 1})},
      {'nombre': 'Perro Spartano', 'precio': 20000, 'costo': 10000, 'receta': receta({'Pan Brioche Perro': 1, 'Pollo Desmechado': 1, 'Carne Desmechada': 1, 'Cerdo Desmechado': 1, 'Butifarra': 1, 'Chorizo': 1, 'Salchicha Suiza': 1, 'Maíz Desgranado': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Queso Costeño': 1, 'Tocineta': 1, 'Salsa de la Casa': 1})},
      {'nombre': 'Perro Suizo Ranchero', 'precio': 25000, 'costo': 12500, 'receta': receta({'Pan Brioche Perro': 1, 'Salchicha Ranchera': 1, 'Salchicha Suiza': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Papa Ripio': 1, 'Queso Costeño': 1, 'Maíz Desgranado': 1, 'Tocineta': 1})},
      {'nombre': 'Perro Suizo', 'precio': 20000, 'costo': 10000, 'receta': receta({'Pan Brioche Perro': 1, 'Salchicha Suiza': 1, 'Lechuga': 1, 'Papa Ripio': 1, 'Queso Costeño': 1, 'Salsa de la Casa': 1})},
      {'nombre': 'Perro Ranchero', 'precio': 18000, 'costo': 9000, 'receta': receta({'Pan Brioche Perro': 1, 'Salchicha Ranchera': 1, 'Lechuga': 1, 'Papa Ripio': 1, 'Queso Costeño': 1, 'Salsa de la Casa': 1})},
      {'nombre': 'Perro Sencillo', 'precio': 7000, 'costo': 3500, 'receta': receta({'Pan Brioche Perro': 1, 'Salchicha Tradicional': 1, 'Lechuga': 1, 'Papa Ripio': 1, 'Queso Costeño': 1, 'Salsa de la Casa': 1})},
    ];

    // --- HAMBURGUESAS ---
    var catHamburguesas = db.collection('categorias').doc();
    batch.set(catHamburguesas, {'nombre': 'HAMBURGUESAS'});
    
    List<Map<String, dynamic>> hamburguesas = [
      {'nombre': 'Hamburguesa Legendaria', 'precio': 28000, 'costo': 14000, 'receta': receta({'Pan Brioche Hamburguesa': 1, 'Carne de Res 150g': 1, 'Queso Amarillo': 1, 'Salchicha Suiza': 1, 'Tocineta': 1, 'Papa Ripio': 1, 'Salsa de la Casa': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Hamburguesa Doble Carne', 'precio': 35000, 'costo': 17500, 'receta': receta({'Pan Brioche Hamburguesa': 1, 'Carne de Res 150g': 2, 'Queso Mozzarella': 1, 'Tocineta': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Hamburguesa Sencilla', 'precio': 22000, 'costo': 11000, 'receta': receta({'Pan Brioche Hamburguesa': 1, 'Carne de Res 150g': 1, 'Queso Mozzarella': 1, 'Tocineta': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Papas a la Francesa': 1})},
    ];

    // --- SALCHIPAPAS ---
    var catSalchipapas = db.collection('categorias').doc();
    batch.set(catSalchipapas, {'nombre': 'SALCHIPAPAS'});
    
    List<Map<String, dynamic>> salchipapas = [
      {'nombre': 'Salchipapa Legendaria', 'precio': 28000, 'costo': 14000, 'receta': receta({'Carne Desmechada': 1, 'Pollo Desmechado': 1, 'Cerdo Desmechado': 1, 'Butifarra': 1, 'Chorizo': 1, 'Salchicha Suiza': 1, 'Salchicha Ranchera': 1, 'Papas a la Francesa': 1, 'Papa Ripio': 1, 'Maíz Desgranado': 1, 'Salsa de la Casa': 1, 'Queso Costeño': 1})},
      {'nombre': 'Salchipapa Suiza', 'precio': 24000, 'costo': 12000, 'receta': receta({'Salchicha Suiza': 2, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Salchipapa Suiza Ranchera', 'precio': 26000, 'costo': 13000, 'receta': receta({'Salchicha Suiza': 1, 'Salchicha Ranchera': 1, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Salchipapa Ranchera', 'precio': 22000, 'costo': 11000, 'receta': receta({'Salchicha Ranchera': 2, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Salchipollo', 'precio': 25000, 'costo': 12500, 'receta': receta({'Salchicha Tradicional': 1, 'Pollo Desmechado': 1, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Salchipapa Clásica', 'precio': 16000, 'costo': 8000, 'receta': receta({'Salchicha Tradicional': 2, 'Queso Costeño': 1, 'Papa Ripio': 1, 'Lechuga': 1, 'Salsa de la Casa': 1, 'Papas a la Francesa': 1})},
    ];

    // --- ASADOS ---
    var catAsados = db.collection('categorias').doc();
    batch.set(catAsados, {'nombre': 'ASADOS'});
    
    List<Map<String, dynamic>> asados = [
      {'nombre': 'Carne Asada', 'precio': 30000, 'costo': 15000, 'receta': receta({'Carne de Res 300g': 1, 'Ensalada': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Pechuga', 'precio': 25000, 'costo': 12500, 'receta': receta({'Pechuga 300g': 1, 'Ensalada': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Lomo de Cerdo', 'precio': 25000, 'costo': 12500, 'receta': receta({'Lomo de Cerdo 300g': 1, 'Ensalada': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Punta Gorda', 'precio': 30000, 'costo': 15000, 'receta': receta({'Punta Gorda 300g': 1, 'Ensalada': 1, 'Papas a la Francesa': 1})},
      {'nombre': 'Churrasco', 'precio': 30000, 'costo': 15000, 'receta': receta({'Churrasco 300g': 1, 'Ensalada': 1, 'Papas a la Francesa': 1})},
    ];

    // --- MAZORCADAS ---
    var catMazorcadas = db.collection('categorias').doc();
    batch.set(catMazorcadas, {'nombre': 'MAZORCADAS'});
    
    List<Map<String, dynamic>> mazorcadas = [
      {'nombre': 'Mazorca Legendaria', 'precio': 26000, 'costo': 13000, 'receta': receta({'Maíz Desgranado': 1, 'Pollo Desmechado': 1, 'Cerdo Desmechado': 1, 'Carne Desmechada': 1, 'Salchicha Suiza': 1, 'Salchicha Ranchera': 1, 'Butifarra': 1, 'Chorizo': 1, 'Lechuga': 1, 'Papa Ripio': 1, 'Queso Gratinado': 1})},
      {'nombre': 'Mazorca con Pollo', 'precio': 22000, 'costo': 11000, 'receta': receta({'Maíz Desgranado': 1, 'Pollo Desmechado': 1, 'Lechuga': 1, 'Papa Ripio': 1, 'Queso Gratinado': 1})},
      {'nombre': 'Mazorca Mixta', 'precio': 24000, 'costo': 12000, 'receta': receta({'Maíz Desgranado': 1, 'Pollo Desmechado': 1, 'Carne Desmechada': 1, 'Lechuga': 1, 'Papa Ripio': 1, 'Queso Gratinado': 1})},
    ];

    // --- BEBIDAS ---
    var catBebidas = db.collection('categorias').doc();
    batch.set(catBebidas, {'nombre': 'BEBIDAS'});
    
    List<Map<String, dynamic>> bebidas = [
      {'nombre': 'Coca Cola Personal', 'precio': 4000, 'costo': 2500, 'receta': receta({'Coca Cola Personal': 1})},
      {'nombre': 'Coca Cola Litro y Cuarto', 'precio': 8000, 'costo': 5000, 'receta': receta({'Coca Cola 1.25L': 1})},
      {'nombre': 'Quatro Personal', 'precio': 4000, 'costo': 2500, 'receta': receta({'Quatro Personal': 1})},
      {'nombre': 'Quatro Litro y Medio', 'precio': 8000, 'costo': 5000, 'receta': receta({'Quatro 1.5L': 1})},
      {'nombre': 'Agua Manzana Personal', 'precio': 4000, 'costo': 2500, 'receta': receta({'Agua Manzana Personal': 1})},
      {'nombre': 'Agua Manzana Litro y Medio', 'precio': 8000, 'costo': 5000, 'receta': receta({'Agua Manzana 1.5L': 1})},
      {'nombre': 'Kola Román', 'precio': 4000, 'costo': 2500, 'receta': receta({'Kola Román': 1})},
      {'nombre': 'Ginger', 'precio': 4000, 'costo': 2500, 'receta': receta({'Ginger': 1})},
      {'nombre': 'Soda', 'precio': 4000, 'costo': 2500, 'receta': receta({'Soda': 1})},
      {'nombre': 'Botella de Agua', 'precio': 3000, 'costo': 1500, 'receta': receta({'Botella de Agua': 1})},
      {'nombre': 'Jugo Hit', 'precio': 4000, 'costo': 2500, 'receta': receta({'Jugo Hit': 1})},
      {'nombre': 'Limonada Natural', 'precio': 10000, 'costo': 3000, 'receta': receta({'Limonada Natural': 1})},
      {'nombre': 'Limonada Cerezada', 'precio': 12000, 'costo': 4000, 'receta': receta({'Limonada Cerezada': 1})},
      {'nombre': 'Aguila Light', 'precio': 4000, 'costo': 2500, 'receta': receta({'Aguila Light': 1})},
      {'nombre': 'Coronita', 'precio': 5000, 'costo': 3000, 'receta': receta({'Coronita': 1})},
    ];

    // --- ADICIONALES ---
    var catAdicionales = db.collection('categorias').doc();
    batch.set(catAdicionales, {'nombre': 'ADICIONALES'});
    
    List<Map<String, dynamic>> adicionales = [
      {'nombre': 'Papas a la Francesa', 'precio': 5000, 'costo': 2500, 'receta': receta({'Papas a la Francesa': 1})},
      {'nombre': 'Bollo de Maíz', 'precio': 4000, 'costo': 2000, 'receta': receta({'Bollo de Maíz': 1})},
      {'nombre': 'Salchicha Suiza', 'precio': 8000, 'costo': 4000, 'receta': receta({'Salchicha Suiza': 1})},
      {'nombre': 'Salchicha Ranchera', 'precio': 6000, 'costo': 3000, 'receta': receta({'Salchicha Ranchera': 1})},
      {'nombre': 'Maíz', 'precio': 3000, 'costo': 1500, 'receta': receta({'Maíz Desgranado': 1})},
      {'nombre': 'Mozzarella', 'precio': 4000, 'costo': 2000, 'receta': receta({'Queso Mozzarella': 1})},
      {'nombre': 'Chorichuzo', 'precio': 4000, 'costo': 2000, 'receta': receta({'Chorichuzo': 1})},
    ];

    void agregar(DocumentReference catRef, List<Map<String, dynamic>> lista) {
      for (var p in lista) {
        var ref = db.collection('productos').doc();
        batch.set(ref, {
          'nombre': p['nombre'],
          'precioVenta': p['precio'],
          'costoProduccion': p['costo'],
          'ganancia': (p['precio'] as int) - (p['costo'] as int),
          'categoriaId': catRef.id,
          'receta': p['receta']
        });
      }
    }

    agregar(catChuzos, chuzos);
    agregar(catDesgranados, desgranados);
    agregar(catPerros, perros);
    agregar(catHamburguesas, hamburguesas);
    agregar(catSalchipapas, salchipapas);
    agregar(catAsados, asados);
    agregar(catMazorcadas, mazorcadas);
    agregar(catBebidas, bebidas);
    agregar(catAdicionales, adicionales);

    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ¡MENÚ CARGADO EXITOSAMENTE!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuración")),
      body: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.all(20)),
          onPressed: () => cargarMenuElLegendario(context),
          icon: const Icon(Icons.cloud_upload, color: Colors.white, size: 30),
          label: const Text("CARGAR MENÚ COMPLETO", style: TextStyle(color: Colors.white, fontSize: 18)),
        ),
      ),
    );
  }
}