import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pantalla encargada de visualizar el historial combinado
// de ventas y gastos registrados en Firestore.
class FlujosHistoricosScreen extends StatelessWidget {
  const FlujosHistoricosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // Barra superior de navegación
      appBar: AppBar(
        title: const Text("Flujos Históricos"),
        centerTitle: true,
      ),

      // Se usa StreamBuilder para escuchar cambios en tiempo real
      // dentro de la colección de ventas.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ventas')
            .snapshots(),

        builder: (context, ventasSnap) {

          // Segundo StreamBuilder para obtener gastos
          // y luego combinarlos visualmente.
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('gastos')
                .snapshots(),

            builder: (context, gastosSnap) {

              // Mostrar indicador mientras llegan datos
              if (!ventasSnap.hasData || !gastosSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              // Unificación de ventas y gastos en una sola lista
              List docs = [
                ...ventasSnap.data!.docs,
                ...gastosSnap.data!.docs,
              ];

              // Construcción dinámica del historial
              return ListView.builder(
                itemCount: docs.length,

                itemBuilder: (context, i) {
                  var d = docs[i];

                  // Conversión del documento a mapa
                  var data = d.data() as Map<String, dynamic>;

                  return ListTile(

                    // Se intenta mostrar total;
                    // si no existe se usa monto
                    title: Text(
                      data['total']?.toString() ??
                          data['monto'].toString(),
                    ),

                    // Identifica método de pago
                    // o clasifica como gasto
                    subtitle: Text(
                      data['metodoPago'] ?? "Gasto",
                    ),

                    // Acciones disponibles por registro
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // Botón reservado para edición futura
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            // Funcionalidad pendiente
                          },
                        ),

                        // Elimina únicamente el documento seleccionado
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
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

      // Botón flotante para limpieza masiva del historial
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.delete_forever),

        onPressed: () async {

          // Primera confirmación
          bool? c1 = await showDialog(
            context: context,

            builder: (c) => AlertDialog(
              title: const Text("¿Eliminar TODO?"),
              content: const Text(
                "Esto borrará ventas y gastos",
              ),

              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(c, false),
                  child: const Text("No"),
                ),

                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(c, true),
                  child: const Text("Sí"),
                ),
              ],
            ),
          );

          if (c1 != true) return;

          // Segunda confirmación para evitar eliminación accidental
          bool? c2 = await showDialog(
            context: context,

            builder: (c) => AlertDialog(
              title: const Text("CONFIRMACIÓN FINAL"),
              content: const Text(
                "No se puede deshacer",
              ),

              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(c, false),
                  child: const Text("Cancelar"),
                ),

                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(c, true),
                  child: const Text("ELIMINAR TODO"),
                ),
              ],
            ),
          );

          if (c2 != true) return;

          // Consulta completa de ventas
          var ventas = await FirebaseFirestore.instance
              .collection('ventas')
              .get();

          // Consulta completa de gastos
          var gastos = await FirebaseFirestore.instance
              .collection('gastos')
              .get();

          // Eliminación individual de ventas
          for (var v in ventas.docs) {
            await v.reference.delete();
          }

          // Eliminación individual de gastos
          for (var g in gastos.docs) {
            await g.reference.delete();
          }

          // Confirmación visual al usuario
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  "Historial eliminado correctamente",
                ),
              ),
            );
          }
        },
      ),
    );
  }
}