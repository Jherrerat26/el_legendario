import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FlujosHistoricosScreen extends StatelessWidget {
  const FlujosHistoricosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flujos Históricos")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ventas').snapshots(),
        builder: (context, ventasSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('gastos').snapshots(),
            builder: (context, gastosSnap) {

              if (!ventasSnap.hasData || !gastosSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              List docs = [
                ...ventasSnap.data!.docs,
                ...gastosSnap.data!.docs
              ];

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  var d = docs[i];
                  var data = d.data() as Map<String, dynamic>;

                  return ListTile(
                    title: Text(data['total']?.toString() ?? data['monto'].toString()),
                    subtitle: Text(data['metodoPago'] ?? "Gasto"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        /// EDITAR
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            // luego te hago esto
                          },
                        ),

                        /// ELIMINAR
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await d.reference.delete();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.delete_forever),
        onPressed: () async {

          bool? c1 = await showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text("¿Eliminar TODO?"),
              content: const Text("Esto borrará ventas y gastos"),
              actions: [
                TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("No")),
                ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Sí"))
              ],
            ),
          );

          if (c1 != true) return;

          bool? c2 = await showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text("CONFIRMACIÓN FINAL"),
              content: const Text("No se puede deshacer"),
              actions: [
                TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("Cancelar")),
                ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("ELIMINAR TODO"))
              ],
            ),
          );

          if (c2 != true) return;

          var ventas = await FirebaseFirestore.instance.collection('ventas').get();
          var gastos = await FirebaseFirestore.instance.collection('gastos').get();

          for (var v in ventas.docs) {
            await v.reference.delete();
          }

          for (var g in gastos.docs) {
            await g.reference.delete();
          }
        },
      ),
    );
  }
}