import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'invoice_service.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}
class _InfoScreenState extends State<InfoScreen> {

  DateTime _fechaFiltro = DateTime.now();

  @override
  Widget build(BuildContext context) {

    DateTime inicioDia = DateTime(_fechaFiltro.year,_fechaFiltro.month,_fechaFiltro.day);
    DateTime finDia = inicioDia.add(const Duration(days: 1));


    

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cierre de Caja"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _fechaFiltro,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );

              if(picked != null){
                setState(() {
                  _fechaFiltro = picked;
                });
              }
            },
          )
        ],
      ),


////////borrar 
  floatingActionButton: FloatingActionButton(
      onPressed: () async {
        try {
          await FirebaseFirestore.instance
              .collection('contadores')
              .doc('numeroPedido')
              .delete();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Contador reiniciado correctamente")),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
      },
      child: const Icon(Icons.refresh),
    ),
//////////////////////7


      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ventas')
            .where('fecha', isGreaterThanOrEqualTo: inicioDia)
            .where('fecha', isLessThan: finDia)
            .orderBy('fecha', descending: true)
            .snapshots(),

        builder: (context, snapshotVentas){

          return StreamBuilder<QuerySnapshot>(

            stream: FirebaseFirestore.instance
                .collection('gastos')
                .where('fecha', isGreaterThanOrEqualTo: inicioDia)
                .where('fecha', isLessThan: finDia)
                .snapshots(),

            builder: (context, snapshotGastos){

              if(!snapshotVentas.hasData || !snapshotGastos.hasData){
                return const Center(child: CircularProgressIndicator());
              }

              var listaVentas = snapshotVentas.data!.docs;
              var listaGastos = snapshotGastos.data!.docs;

              double ingresosEfectivo = 0;
              double ingresosTransferencia = 0;
              double totalGastos = 0;
              int cantidadDomicilios = 0;
              double dineroDomicilios = 0;
///////////////////
              for(var doc in listaVentas){

  var data = doc.data() as Map<String,dynamic>;

  if(data['estado'] != 'cancelada'){

    double subtotal = (data['subtotal'] ?? 0 as num).toDouble();
    double envio = (data['costoDomicilio'] ?? 0 as num).toDouble();

    double efectivo = (data['efectivo'] ?? data['pagoEfectivo'] ?? 0 as num).toDouble();
    double transferencia = (data['transferencia'] ?? data['pagoTransferencia'] ?? 0 as num).toDouble();

    /// 🔥 SOPORTE PARA PAGOS MIXTOS
    if(efectivo > 0 && transferencia > 0){
      ingresosEfectivo += efectivo;
      ingresosTransferencia += transferencia;
    }
    else if(data['metodoPago'] == 'Transferencia'){
      ingresosTransferencia += subtotal;
    }
    else{
      ingresosEfectivo += subtotal;
    }

    /// DOMICILIOS
    if(data['esDomicilio'] == true){
      cantidadDomicilios++;
      dineroDomicilios += envio;
    }
  }
}
              for(var doc in listaGastos){
                totalGastos += (doc['monto'] as num).toDouble();
              }

              double saldoCajaEfectivo = ingresosEfectivo - totalGastos;

              return Column(
                children: [

                  /// TARJETA RESUMEN
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.grey[100],
                    child: Column(
                      children: [

                        Text(
                          "Fecha: ${DateFormat('dd/MM/yyyy').format(_fechaFiltro)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height:10),

                        Row(
                          children: [

                            Expanded(child: _infoCard("Efectivo", ingresosEfectivo, Colors.green)),

                            const SizedBox(width:5),

                            Expanded(child: _infoCard("Transferencia", ingresosTransferencia, Colors.blue))

                          ],
                        ),

                        const SizedBox(height:5),

                        Row(
                          children: [

                            Expanded(child: _infoCard("Gastos (-)", totalGastos, Colors.red)),

                            const SizedBox(width:5),

                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(10)
                                ),
                                child: Column(
                                  children: [

                                    const Text(
                                      "ENTREGAR EFECTIVO",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 10
                                      ),
                                    ),

                                    Text(
                                      "\$${saldoCajaEfectivo.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                          fontSize:20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white
                                      ),
                                    )

                                  ],
                                ),
                              ),
                            )

                          ],
                        ),

                        const SizedBox(height:5),

                        Text(
                          "Pago Domiciliarios: \$${dineroDomicilios.toStringAsFixed(0)} ($cantidadDomicilios envíos)",
                          style: const TextStyle(
                              fontSize:12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold
                          ),
                        )

                      ],
                    ),
                  ),

                  const Divider(thickness:2),

                  /// LISTA
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(10),
                      children: [

                        /// GASTOS
                        if(listaGastos.isNotEmpty)...[

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical:5),
                            child: Text(
                              "GASTOS REGISTRADOS:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red
                              ),
                            ),
                          ),

                          ...listaGastos.map((g)=>Card(

                            color: Colors.red[50],

                            child: ListTile(

                              leading: const Icon(Icons.money_off,color: Colors.red),

                              title: Text(
                                g['tipo'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),

                              subtitle: Text(g['descripcion'] ?? ''),

                              trailing: Text(
                                "-\$${(g['monto'] as num).toStringAsFixed(0)}",
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold
                                ),
                              ),

                            ),

                          )),

                          const Divider()

                        ],

                        /// VENTAS
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical:5),
                          child: Text(
                            "VENTAS REGISTRADAS:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green
                            ),
                          ),
                        ),

                        ...listaVentas.map((doc){

                          var data = doc.data() as Map<String,dynamic>;
                          bool cancelada = data['estado'] == 'cancelada';

                          String num = data['numeroPedido'] ?? doc.id.substring(0,4);
                          List items = data['items'] ?? [];

                          return Card(

                            color: cancelada ? Colors.red[50] : Colors.white,

                            child: ExpansionTile(

                              leading: CircleAvatar(

                                backgroundColor: cancelada
                                  ? Colors.grey
                                : (data['metodoPago'] == 'Mixto'
                                  ? Colors.purple
                                : data['metodoPago'] == 'Transferencia'
                                 ? Colors.blue
                                 : Colors.green),

                                child: Text(
                                  num,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize:10,
                                      fontWeight: FontWeight.bold
                                  ),
                                ),

                              ),

                              title: Text(
                                cancelada
                                    ? "ANULADA"
                                    : "\$${data['total'].toStringAsFixed(0)}",

                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: cancelada
                                        ? TextDecoration.lineThrough
                                        : null
                                ),
                              ),

                              subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Text(
      DateFormat('hh:mm a').format(data['fecha'].toDate()),
    ),

    /// 💳 MÉTODO DE PAGO BONITO
    if(data['metodoPago'] == 'Mixto')
      Text(
        "Mixto: Efe \$${(data['efectivo'] ?? data['pagoEfectivo'] ?? 0)} + Trans \$${(data['transferencia'] ?? data['pagoTransferencia'] ?? 0)}",
        style: const TextStyle(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
          fontSize: 12
        ),
      )
    else
      Text(
        data['metodoPago'] ?? "Efectivo",
        style: TextStyle(
          color: data['metodoPago'] == 'Transferencia'
              ? Colors.blue
              : Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 12
        ),
      ),

  ],
),

                              children: [

                                Padding(

                                  padding: const EdgeInsets.all(10),

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      const Text(
                                        "PRODUCTOS VENDIDOS:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize:12
                                        ),
                                      ),

                                      ...items.map((item)=>Padding(

                                        padding: const EdgeInsets.symmetric(vertical:2),

                                        child: Row(

                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                          children: [

                                            Text("${item['cantidad']}x ${item['nombre']}"),

                                            Text("\$${(item['precio'] * item['cantidad']).toStringAsFixed(0)}")

                                          ],

                                        ),

                                      )),

                                      const SizedBox(height:10),

                                      if(!cancelada)

  Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [

    // ✏️ EDITAR
    IconButton(
      icon: const Icon(Icons.edit, color: Colors.orange),
      tooltip: "Editar Venta",
      onPressed: () => _editarVenta(doc),
    ),

    // 🖨️ IMPRIMIR
    IconButton(
      icon: const Icon(Icons.print, color: Colors.blue),
      tooltip: "Reimprimir Ticket",
      onPressed: () => _reimprimirVenta(doc),
    ),

    // ❌ ELIMINAR
    IconButton(
      icon: const Icon(Icons.delete_forever, color: Colors.red),
      tooltip: "Anular Venta",
      onPressed: () => _procesoCancelacion(doc),
    ),
  ],
)

                                    ],

                                  ),

                                )

                              ],

                            ),

                          );

                        }),

                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: ElevatedButton.icon(
                      onPressed: ()=>_generarPDF(
                          listaVentas,
                          listaGastos,
                          ingresosEfectivo,
                          ingresosTransferencia,
                          totalGastos,
                          dineroDomicilios,
                          saldoCajaEfectivo
                      ),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Reporte de Cierre (PDF)"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity,50)
                      ),
                    ),
                  )

                ],
              );

            },

          );

        },

      ),

    );

  }
/////////////////////////////////////////////////////////////////////////////////////////////////////


Future<void> _reimprimirVenta(DocumentSnapshot doc) async {
  var data = doc.data() as Map<String, dynamic>;
  List<Map<String, dynamic>> items =
      List<Map<String, dynamic>>.from(data['items']);
  double subtotal = (data['subtotal'] as num).toDouble();
  double costoEnvio = (data['costoDomicilio'] ?? 0 as num).toDouble();
  String direccion = data['direccion'] ?? "";
  String telefono = data['telefono'] ?? "";
  String metodoPago = data['metodoPago'] ?? "Efectivo";
  String datosEnvio = data['datosDomicilio'] ?? "";
  try {
    await InvoiceService.generarYEnviarImagen(
  items: items,
  subtotal: subtotal,
  costoEnvio: costoEnvio,
  direccion: direccion,
  telefono: telefono,
  metodoPago: metodoPago,
  datosEnvio: datosEnvio,
  efectivo: (data['efectivo'] ?? data['pagoEfectivo'] ?? 0).toDouble(),
  transferencia: (data['transferencia'] ?? data['pagoTransferencia'] ?? 0).toDouble(),
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al reimprimir: $e")),
      );
    }
  }
}
/////////////////////////////////////////////////////


Future<void> _editarVenta(DocumentSnapshot doc) async {

  var data = doc.data() as Map<String, dynamic>;

  List<Map<String, dynamic>> items =
      List<Map<String, dynamic>>.from(data['items']);

  double total = (data['total'] as num).toDouble();

  double efectivo = (data['efectivo'] ?? data['pagoEfectivo'] ?? total).toDouble();
  double transferencia = (data['transferencia'] ?? data['pagoTransferencia'] ?? 0).toDouble();

  String metodo = data['metodoPago'] ?? "Efectivo";

  await showDialog(
    context: context,
    builder: (ctx) {

      return StatefulBuilder(
        builder: (context, setStateSB) {

          double totalCalculado = 0;
          for (var i in items) {
            totalCalculado += (i['precio'] * i['cantidad']);
          }

          return AlertDialog(
            title: const Text("Editar Venta"),
            content: SingleChildScrollView(
              child: Column(
                children: [

                  /// 🧾 PRODUCTOS
                  ...items.asMap().entries.map((entry) {

                    int index = entry.key;
                    var item = entry.value;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        Expanded(
                          child: Text("${item['nombre']} x${item['cantidad']}"),
                        ),

                        Row(
                          children: [

                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.red),
                              onPressed: () {
                                setStateSB(() {
                                  if (item['cantidad'] > 1) {
                                    item['cantidad']--;
                                  } else {
                                    items.removeAt(index);
                                  }
                                });
                              },
                            ),

                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.green),
                              onPressed: () {
                                setStateSB(() {
                                  item['cantidad']++;
                                });
                              },
                            ),

                          ],
                        )
                      ],
                    );
                  }),

                  const Divider(),

                  /// 💰 PAGO
                  Text("Total: \$${totalCalculado.toStringAsFixed(0)}"),

                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Efectivo"),
                    controller: TextEditingController(text: efectivo.toString()),
                    onChanged: (v) {
                      efectivo = double.tryParse(v) ?? 0;
                    },
                  ),

                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Transferencia"),
                    controller: TextEditingController(text: transferencia.toString()),
                    onChanged: (v) {
                      transferencia = double.tryParse(v) ?? 0;
                    },
                  ),

                ],
              ),
            ),

            actions: [

              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),

              ElevatedButton(
                onPressed: () async {

                  if ((efectivo + transferencia) != totalCalculado) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Los valores no coinciden")),
                    );
                    return;
                  }

                  metodo = (transferencia > 0 && efectivo > 0)
                      ? "Mixto"
                      : (transferencia > 0 ? "Transferencia" : "Efectivo");

                  await doc.reference.update({
                    'items': items,
                    'total': totalCalculado,
                    'subtotal': totalCalculado,
                    'metodoPago': metodo,
                    'efectivo': efectivo,
                    'transferencia': transferencia,
                  });

                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Venta actualizada")),
                  );
                },
                child: const Text("Guardar"),
              )
            ],
          );
        },
      );
    },
  );
}


///////////////////////////////////////////////////////////////////////////////////////////////////////
  /// PDF
  Future<void> _generarPDF(
      List<QueryDocumentSnapshot> ventas,
      List<QueryDocumentSnapshot> gastos,
      double efectivo,
      double transf,
      double totalGastos,
      double dineroDomis,
      double saldoFinal
      ) async {

    final pdf = pw.Document();

    final fecha = DateFormat('dd-MM-yyyy').format(_fechaFiltro);

    pdf.addPage(

      pw.Page(

        pageFormat: PdfPageFormat.roll80,

        margin: const pw.EdgeInsets.all(10),

        build:(pw.Context context){

          return pw.Column(

            crossAxisAlignment: pw.CrossAxisAlignment.start,

            children: [

              pw.Center(child: pw.Text("CIERRE DE CAJA",style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize:16))),

              pw.Center(child: pw.Text("EL LEGENDARIO")),

              pw.Divider(),

              pw.Text("Fecha: $fecha"),

              pw.SizedBox(height:10),

              pw.Text("Efectivo: \$${efectivo.toStringAsFixed(0)}"),

              pw.Text("Transferencia: \$${transf.toStringAsFixed(0)}"),

              pw.Text("Gastos: -\$${totalGastos.toStringAsFixed(0)}"),

              pw.Divider(),

              pw.Text(
                "EFECTIVO A ENTREGAR: \$${saldoFinal.toStringAsFixed(0)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize:14),
              ),

              pw.SizedBox(height:10),

              pw.Text("Pago a Domiciliarios: \$${dineroDomis.toStringAsFixed(0)}"),

              pw.SizedBox(height:20),

              pw.Text("Firma Cajero: _________________")

            ],

          );

        },

      ),

    );

    final output = await getTemporaryDirectory();

    final file = File("${output.path}/Cierre_$fecha.pdf");

    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)],text:'Cierre de Caja $fecha');

  }

  Widget _infoCard(String titulo,double valor,Color color){

    return Container(

      padding: const EdgeInsets.symmetric(vertical:10,horizontal:5),

      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),

      child: Column(

        children: [

          Text(
            titulo,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize:12
            ),
          ),

          Text(
            "\$${valor.toStringAsFixed(0)}",
            style: TextStyle(
                color: color,
                fontSize:16,
                fontWeight: FontWeight.bold
            ),
          )

        ],

      ),

    );

  }

  

  void _procesoCancelacion(DocumentSnapshot doc){

    showDialog(

        context: context,

        builder:(ctx)=>AlertDialog(

          title: const Text("Anular Venta"),

          content: const Text("¿Devolver inventario?"),

          actions: [

            TextButton(
                onPressed:()=>Navigator.pop(ctx),
                child: const Text("Atrás")
            ),

            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed:()=>_ejecutarCancelacion(doc,false),
                child: const Text("No (Pérdida)")
            ),

            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed:()=>_ejecutarCancelacion(doc,true),
                child: const Text("Sí, Devolver")
            )

          ],

        )

    );

  }

  Future<void> _ejecutarCancelacion(DocumentSnapshot doc,bool devolver) async{

    Navigator.pop(context);

    final batch = FirebaseFirestore.instance.batch();

    batch.update(doc.reference,{'estado':'cancelada'});

    if(devolver){

      Map<String,dynamic> venta = doc.data() as Map<String,dynamic>;

      for(var item in venta['items']){

        if(item['id_producto'] != null){

          var prodDoc = await FirebaseFirestore.instance
              .collection('productos')
              .doc(item['id_producto'])
              .get();

          if(prodDoc.exists && prodDoc.data()!.containsKey('receta')){

            int cant = item['cantidad'] ?? 1;

            for(var ing in prodDoc['receta']){

              batch.update(
                  FirebaseFirestore.instance
                      .collection('inventario')
                      .doc(ing['idInsumo']),

                  {
                    'stock': FieldValue.increment(
                        (ing['cantidad'] as num).toDouble() * cant
                    )
                  }

              );

            }

          }

        }

      }

    }

    await batch.commit();

    if(mounted){
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Venta Anulada")));
    }


    

  }

  

}