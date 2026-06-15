import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {

  /* ======================================================
      CARGAR INSUMOS POR DEFECTO
  ====================================================== */

  void _cargarInsumosPorDefecto() {
    final List<Map<String, dynamic>> defaults = [
      {'nombre': 'Pan Hamburguesa', 'unidad': 'Unidad'},
      {'nombre': 'Pan Perro', 'unidad': 'Unidad'},
      {'nombre': 'Carne Hamburguesa', 'unidad': 'Unidad'},
      {'nombre': 'Salchicha Suiza', 'unidad': 'Unidad'},
      {'nombre': 'Salchicha Ranchera', 'unidad': 'Unidad'},
      {'nombre': 'Queso Costeño', 'unidad': 'Kg'},
      {'nombre': 'Queso Mozzarella', 'unidad': 'Loncha'},
      {'nombre': 'Papa Ripio', 'unidad': 'Paq'},
      {'nombre': 'Papa Francesa', 'unidad': 'Kg'},
      {'nombre': 'Lechuga', 'unidad': 'Kg'},
      {'nombre': 'Salsas (Casa)', 'unidad': 'Lts'},
      {'nombre': 'Coca Cola 1.5L', 'unidad': 'Unidad'},
      {'nombre': 'Vaso Desechable', 'unidad': 'Paq'},
    ];

    for (var item in defaults) {
      FirebaseFirestore.instance.collection('inventario').add({
        'nombre': item['nombre'],
        'stock': 0.0,
        'minimo': 10.0,
        'unidad': item['unidad']
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Insumos básicos cargados."))
    );
  }

  /* ======================================================
      CREAR / EDITAR INSUMO
  ====================================================== */

  void _gestionInsumo({DocumentSnapshot? doc}) {
    final nombreCtrl = TextEditingController(text: doc?['nombre'] ?? '');
    final stockCtrl = TextEditingController(text: doc?['stock']?.toString() ?? '0');
    final minimoCtrl = TextEditingController(text: doc?['minimo']?.toString() ?? '10');
    String unidad = doc?['unidad'] ?? 'Unidad';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(doc == null ? "Nuevo Insumo" : "Editar Insumo"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: "Nombre"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Stock Actual"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: minimoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Tope Mínimo (Alerta)"),
                ),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: unidad,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Unidad', child: Text("Unidad")),
                    DropdownMenuItem(value: 'Kg', child: Text("Kg")),
                    DropdownMenuItem(value: 'Lts', child: Text("Lts")),
                    DropdownMenuItem(value: 'Paq', child: Text("Paq")),
                    DropdownMenuItem(value: 'Loncha', child: Text("Loncha")),
                    DropdownMenuItem(value: 'Vaso', child: Text("Vaso")),
                  ],
                  onChanged: (v) => setStateDialog(() => unidad = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                final data = {
                  'nombre': nombreCtrl.text,
                  'stock': double.tryParse(stockCtrl.text) ?? 0,
                  'minimo': double.tryParse(minimoCtrl.text) ?? 0,
                  'unidad': unidad,
                };

                if (doc == null) {
                  FirebaseFirestore.instance.collection('inventario').add(data);
                } else {
                  doc.reference.update(data);
                }

                Navigator.pop(context);
              },
              child: const Text("Guardar"),
            )
          ],
        ),
      ),
    );
  }

  /* ======================================================
      🔥 ELIMINAR INSUMO EN CASCADA (ACTUALIZA RECETAS)
  ====================================================== */

  void _eliminarInsumo(DocumentSnapshot doc) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("¿Eliminar ${doc['nombre']}?"),
        content: const Text(
          "⚠️ Se eliminará este insumo de TODAS las recetas automáticamente."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar Todo"),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmar) return;

    try {
      var productos =
          await FirebaseFirestore.instance.collection('productos').get();

      var batch = FirebaseFirestore.instance.batch();

      for (var prod in productos.docs) {
        Map<String, dynamic> data = prod.data();

        if (data.containsKey('receta')) {
          List receta = List.from(data['receta']);
          bool modificado = false;

          receta.removeWhere((ingrediente) {
            if (ingrediente['idInsumo'] == doc.id) {
              modificado = true;
              return true;
            }
            return false;
          });

          if (modificado) {
            batch.update(prod.reference, {'receta': receta});
          }
        }
      }

      // Borramos el insumo
      batch.delete(doc.reference);

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Insumo eliminado y recetas actualizadas."),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  /* ======================================================
      UI PRINCIPAL
  ====================================================== */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Inventario", style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: "Cargar Insumos Base",
            onPressed: _cargarInsumosPorDefecto,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventario')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No hay insumos. Carga los básicos arriba ☁️"),
            );
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {

              double stock = (doc['stock'] as num).toDouble();
              double minimo = (doc['minimo'] as num).toDouble();

              Color colorEstado;
              String estadoTexto;

              if (stock <= minimo) {
                colorEstado = Colors.red;
                estadoTexto = "CRÍTICO";
              } else if (stock <= minimo * 2) {
                colorEstado = Colors.orange;
                estadoTexto = "ALERTA";
              } else {
                colorEstado = Colors.green;
                estadoTexto = "BIEN";
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorEstado, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorEstado,
                    child: const Icon(Icons.inventory_2, color: Colors.white),
                  ),
                  title: Text(
                    doc['nombre'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Stock: ${stock.toStringAsFixed(1)} ${doc['unidad']}  |  Estado: $estadoTexto",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _gestionInsumo(doc: doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _eliminarInsumo(doc),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () => _gestionInsumo(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
