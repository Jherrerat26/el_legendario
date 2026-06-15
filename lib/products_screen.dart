import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {

  /* ======================================================
      CREAR NUEVO PRODUCTO EN CATEGORÍA
  ====================================================== */
  void _crearNuevoProducto(String categoriaId) {
    final nombreCtrl = TextEditingController();
    final ventaCtrl = TextEditingController();
    final costoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nuevo Producto"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl, 
              decoration: const InputDecoration(labelText: "Nombre del Plato")
            ),
            TextField(
              controller: ventaCtrl, 
              decoration: const InputDecoration(labelText: "Precio Venta"), 
              keyboardType: TextInputType.number
            ),
            TextField(
              controller: costoCtrl, 
              decoration: const InputDecoration(labelText: "Costo Producción"), 
              keyboardType: TextInputType.number
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.isNotEmpty) {
                double venta = double.tryParse(ventaCtrl.text) ?? 0;
                double costo = double.tryParse(costoCtrl.text) ?? 0;
                
                FirebaseFirestore.instance.collection('productos').add({
                  'nombre': nombreCtrl.text,
                  'precioVenta': venta,
                  'costoProduccion': costo,
                  'ganancia': venta - costo,
                  'categoriaId': categoriaId,
                  'receta': [] // Receta vacía al inicio
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Crear"),
          )
        ],
      ),
    );
  }

  /* ======================================================
      ELIMINAR CATEGORÍA + TODOS LOS PRODUCTOS
  ====================================================== */
  void _eliminarCategoria(String catId, String catNombre) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("¿Eliminar '$catNombre'?"),
        content: const Text(
          "⚠️ CUIDADO:\n\nSe eliminará la categoría y TODOS los productos que contiene.\nEsta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // 1. Borrar productos de la categoría
              var prodSnapshot = await FirebaseFirestore.instance
                  .collection('productos')
                  .where('categoriaId', isEqualTo: catId)
                  .get();

              for (var doc in prodSnapshot.docs) {
                await doc.reference.delete();
              }

              // 2. Borrar categoría
              await FirebaseFirestore.instance
                  .collection('categorias')
                  .doc(catId)
                  .delete();

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Categoría y productos eliminados")),
              );
            },
            child: const Text("ELIMINAR TODO", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  /* ======================================================
      EDITAR PRODUCTO + RECETA
  ====================================================== */
  void _editarProducto(DocumentSnapshot producto) {
    final nombreCtrl = TextEditingController(text: producto['nombre']);
    final ventaCtrl = TextEditingController(text: producto['precioVenta'].toString());
    final costoCtrl = TextEditingController(text: producto['costoProduccion'].toString());

    // Recuperar receta existente
    List receta = [];
    try {
      receta = List.from(producto['receta']);
    } catch (e) {
      receta = [];
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text("Editar: ${producto['nombre']}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre")),
                
                Row(
                  children: [
                    Expanded(child: TextField(controller: ventaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Precio Venta"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: costoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Costo Prod."))),
                  ],
                ),

                const Divider(),
                const Text("RECETA (Descuento de Inventario)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),

                // Lista de ingredientes actuales
                ...receta.asMap().entries.map((e) => ListTile(
                  dense: true,
                  title: Text(e.value['nombreInsumo']),
                  subtitle: Text("Descarga: ${e.value['cantidad']}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => setStateDialog(() => receta.removeAt(e.key)),
                  ),
                )),

                ElevatedButton.icon(
                  icon: const Icon(Icons.add_link),
                  label: const Text("Agregar Ingrediente"),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('inventario').snapshots(),
                        builder: (ctx, snap) {
                          if (!snap.hasData) return const SizedBox();
                          return ListView(
                            children: snap.data!.docs.map((insumo) {
                              return ListTile(
                                title: Text(insumo['nombre']),
                                trailing: const Icon(Icons.add),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pedirCantidad(context, (cant) {
                                    setStateDialog(() {
                                      receta.add({
                                        'idInsumo': insumo.id,
                                        'nombreInsumo': insumo['nombre'],
                                        'cantidad': cant
                                      });
                                    });
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    );
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                producto.reference.delete();
                Navigator.pop(context);
              },
              child: const Text("Eliminar Producto", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                double venta = double.tryParse(ventaCtrl.text) ?? 0;
                double costo = double.tryParse(costoCtrl.text) ?? 0;

                producto.reference.update({
                  'nombre': nombreCtrl.text,
                  'precioVenta': venta,
                  'costoProduccion': costo,
                  'ganancia': venta - costo,
                  'receta': receta
                });
                Navigator.pop(context);
              },
              child: const Text("Guardar Cambios"),
            )
          ],
        ),
      ),
    );
  }

  void _pedirCantidad(BuildContext context, Function(double) onConfirm) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Cantidad a descontar"),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                onConfirm(double.parse(ctrl.text));
                Navigator.pop(c);
              }
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  /* ======================================================
      UI PRINCIPAL
  ====================================================== */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Gestión de Menú", style: GoogleFonts.poppins())),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categorias').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView(
            children: snapshot.data!.docs.map((cat) {
              return ExpansionTile(
                title: Text(cat['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                
                // BOTONES EN LA CARPETA (Agregar Producto y Eliminar Carpeta)
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      tooltip: "Nuevo Producto Aquí",
                      onPressed: () => _crearNuevoProducto(cat.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      tooltip: "Borrar Carpeta",
                      onPressed: () => _eliminarCategoria(cat.id, cat['nombre']),
                    ),
                  ],
                ),

                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('productos')
                        .where('categoriaId', isEqualTo: cat.id)
                        .snapshots(),
                    builder: (context, pSnap) {
                      if (!pSnap.hasData) return const SizedBox();
                      return Column(
                        children: pSnap.data!.docs.map((p) {
                          return ListTile(
                            leading: const Icon(Icons.fastfood, size: 20),
                            title: Text(p['nombre']),
                            subtitle: Text("\$${p['precioVenta']}"),
                            onTap: () => _editarProducto(p),
                          );
                        }).toList(),
                      );
                    },
                  )
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}