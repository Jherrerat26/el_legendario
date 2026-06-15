import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sales_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {

  @override
  void initState() {
    super.initState();
    normalizarMesas();
  }

  // 🔥 ARREGLA MESAS VIEJAS AUTOMÁTICAMENTE
  Future<void> normalizarMesas() async {
    var snapshot = await FirebaseFirestore.instance.collection('mesas').get();

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data();
      Map<String, dynamic> updateData = {};

      if (!data.containsKey('estado')) {
        updateData['estado'] = 'libre';
      }

      if (!data.containsKey('pedidos')) {
        updateData['pedidos'] = [];
      }

      if (!data.containsKey('creada')) {
        updateData['creada'] = DateTime.now();
      }

      if (updateData.isNotEmpty) {
        await doc.reference.update(updateData);
      }
    }
  }

  void _crearMesa() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Nueva Mesa"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: "Ej: Mesa 1"),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                FirebaseFirestore.instance.collection('mesas').add({
                  'nombre': ctrl.text,
                  'estado': 'libre',
                  'pedidos': [],
                  'creada': DateTime.now()
                });
                Navigator.pop(c);
              }
            },
            child: const Text("Crear"),
          )
        ],
      ),
    );
  }

  void _borrarMesa(String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("¿Borrar Mesa?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              FirebaseFirestore.instance.collection('mesas').doc(id).delete();
              Navigator.pop(c);
            },
            child: const Text("Borrar"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text("Mesas y Pedidos", style: GoogleFonts.poppins())),

      body: Column(
        children: [

          /// 🔥 MENSAJE SUPERIOR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.black87,
            child: const Text(
              "⚠️ Mantén presionada una mesa para borrarla",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold
              ),
            ),
          ),

          /// 🔽 LISTA DE MESAS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('mesas')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                if (snapshot.data!.docs.isEmpty)
                  return const Center(child: Text("Crea mesas con el botón +"));

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var mesa = snapshot.data!.docs[index];
                    Map<String, dynamic> data =
                        mesa.data() as Map<String, dynamic>;

                    String estado = data.containsKey('estado')
                        ? data['estado']
                        : 'libre';

                    List pedidos = data.containsKey('pedidos')
                        ? data['pedidos']
                        : [];

                    bool ocupada = estado == 'ocupada';

                    double totalMesa = 0;
                    if (ocupada) {
                      for (var p in pedidos) {
                        totalMesa += (p['precio'] * p['cantidad']);
                      }
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesScreen(
                              mesaId: mesa.id,
                              mesaNombre: data['nombre'],
                              pedidosActuales: ocupada
                                  ? List<Map<String, dynamic>>.from(pedidos)
                                  : [],
                            ),
                          ),
                        );
                      },
                      onLongPress: () => _borrarMesa(mesa.id),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              ocupada ? Colors.red[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color:
                                  ocupada ? Colors.red : Colors.green,
                              width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_restaurant,
                                size: 40,
                                color: ocupada
                                    ? Colors.red
                                    : Colors.green),
                            const SizedBox(height: 5),
                            Text(
                              data['nombre'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              ocupada
                                  ? "\$${totalMesa.toStringAsFixed(0)}"
                                  : "Libre",
                              style: TextStyle(
                                  color: ocupada
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: _crearMesa,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}