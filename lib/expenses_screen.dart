import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  // Lista predefinida
  final List<String> _categoriasFijas = [
    'Compra de insumos',
    'Pago a trabajadores',
    'Arriendo',
    'Servicios (Luz/Agua)',
    'Publicidad',
    'Transporte',
    'Pérdidas',
    'Otro (Escribir...)'
  ];

  void _mostrarDialogoGasto() {
    final montoCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final otroTipoCtrl = TextEditingController();
    String seleccion = _categoriasFijas.first;
    bool mostrarCampoOtro = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Registrar Salida de Dinero"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Selección de Categoría
                    DropdownButtonFormField<String>(
                      value: seleccion,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: "Motivo del Gasto"),
                      items: _categoriasFijas.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          seleccion = val!;
                          mostrarCampoOtro = (val == 'Otro (Escribir...)');
                        });
                      },
                    ),
                    
                    // 2. Campo extra si selecciona "Otro"
                    if (mostrarCampoOtro)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                          controller: otroTipoCtrl,
                          decoration: const InputDecoration(
                            labelText: "¿Cuál es el motivo?",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.edit)
                          ),
                        ),
                      ),

                    const SizedBox(height: 15),
                    
                    // 3. Monto
                    TextField(
                      controller: montoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Monto (\$)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money)
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // 4. Detalle opcional
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: "Nota adicional (Opcional)"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    if (montoCtrl.text.isEmpty) return;

                    // Definir el tipo final
                    String tipoFinal = mostrarCampoOtro ? otroTipoCtrl.text : seleccion;
                    if (tipoFinal.isEmpty) tipoFinal = "Gasto Varios";

                    FirebaseFirestore.instance.collection('gastos').add({
                      'fecha': DateTime.now(),
                      'tipo': tipoFinal,
                      'descripcion': descCtrl.text,
                      'monto': double.tryParse(montoCtrl.text) ?? 0,
                      'usuario': 'Vendedor' 
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gasto guardado")));
                  },
                  child: const Text("REGISTRAR", style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Control de Gastos", style: GoogleFonts.poppins())),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('gastos').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay gastos registrados."));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
  leading: const CircleAvatar(
    backgroundColor: Colors.redAccent,
    child: Icon(Icons.money_off, color: Colors.white)
  ),

  title: Text(
    doc['tipo'],
    style: const TextStyle(fontWeight: FontWeight.bold)
  ),

  subtitle: Text(
    "${DateFormat('dd/MM - HH:mm').format(doc['fecha'].toDate())}\n${doc['descripcion']}"
  ),

  isThreeLine: true,

  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [

      /// 💰 VALOR
      Text(
        "-\$${doc['monto']}",
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 16
        ),
      ),

      const SizedBox(width: 10),

      /// ❌ BOTÓN BORRAR
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text("Eliminar gasto"),
              content: const Text("¿Seguro que deseas eliminar este gasto?"),
              actions: [
                TextButton(
                  onPressed: ()=>Navigator.pop(c),
                  child: const Text("Cancelar")
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    await doc.reference.delete();
                    Navigator.pop(c);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Gasto eliminado"))
                    );
                  },
                  child: const Text("Eliminar")
                )
              ],
            )
          );
        },
      )

    ],
  ),
),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nuevo Gasto", style: TextStyle(color: Colors.white)),
        onPressed: _mostrarDialogoGasto,
      ),
    );
  }
}