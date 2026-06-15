import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'invoice_service.dart'; // Asegúrate de tener este archivo creado

class SalesScreen extends StatefulWidget {
  final String? mesaId;
  final String? mesaNombre;
  final List<Map<String, dynamic>>? pedidosActuales;

  const SalesScreen({
    super.key,
    this.mesaId,
    this.mesaNombre,
    this.pedidosActuales
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // Lista de productos en el carrito
  List<Map<String, dynamic>> carrito = [];

  double totalVenta = 0;
  double totalGanancia = 0;
  bool mostrandoHistorial = false;
  bool procesando = false;
  bool get esMesa => widget.mesaId != null;

  @override
  void initState() {
    super.initState();

    if (widget.pedidosActuales != null) {
      carrito = widget.pedidosActuales!.map((e) {
        e['nuevo'] = false;
        return e;
      }).toList();
      calcularTotales();
    }
  }

  /* ======================================================
      LÓGICA DEL CARRITO
  ====================================================== */
  void agregarAlCarrito(QueryDocumentSnapshot p) {
    setState(() {
      // 1. Buscamos si el producto ya existe en el carrito usando su ID
      int index = carrito.indexWhere((item) => item['id_producto'] == p.id);

      if (index != -1) {
        // SI YA EXISTE: Le sumamos 1 a la cantidad
        carrito[index]['cantidad'] = (carrito[index]['cantidad'] ?? 1) + 1;
      } else {
        // SI ES NUEVO: Lo agregamos con cantidad inicial 1
        carrito.add({
          'id_temp': DateTime.now().millisecondsSinceEpoch.toString(),
          'id_producto': p.id,
          'nombre': p['nombre'],
          'precio': (p['precioVenta'] as num).toDouble(),
          'ganancia': (p['ganancia'] as num).toDouble(),
          'nota': '',
          'cantidad': 1, // <--- ESTO ES LO NUEVO
          'nuevo': true,          
        });
      }
      calcularTotales();
    });
  }

  ////////////////////////////////////////////////
  Future<void> guardarPedidosMesa() async {
    if (widget.mesaId == null) return;

    await FirebaseFirestore.instance
        .collection('mesas')
        .doc(widget.mesaId)
        .update({
      'estado': carrito.isEmpty ? 'libre' : 'ocupada',
      'pedidos': carrito
    });
  }

  ////////////////////////////////////////////////
  /////BOTÓN 1: ACTUALIZAR / COCINA
  ///////////////////////////////////////////////////

  Future<void> actualizarPedidoMesa() async {
    setState(() => procesando = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var item in carrito) {
        if (item['nuevo'] == true) {
          var prodDoc = await FirebaseFirestore.instance
              .collection('productos')
              .doc(item['id_producto'])
              .get();

          if (prodDoc.exists) {
            Map<String, dynamic> data = prodDoc.data() as Map<String, dynamic>;

            if (data.containsKey('receta')) {
              for (var ing in data['receta']) {
                var insumoRef = FirebaseFirestore.instance
                    .collection('inventario')
                    .doc(ing['idInsumo']);

                double desc =
                    (ing['cantidad'] as num).toDouble() *
                    (item['cantidad'] as int);

                batch.update(insumoRef, {
                  'stock': FieldValue.increment(-desc)
                });
              }
            }
          }

          item['nuevo'] = false;
        }
      }

      await FirebaseFirestore.instance
          .collection('mesas')
          .doc(widget.mesaId)
          .update({
        'estado': 'ocupada',
        'pedidos': carrito
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pedido enviado a cocina 👨‍🍳"))
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print(e);
    } finally {
      if(mounted) setState(() => procesando = false);
    }
  }

  //////////////////////////////////////////////////////////////////////////////////
  ///pre imprimir 

  // FUNCIÓN PARA SOLO IMPRIMIR (SIN COBRAR NI CERRAR MESA)
  Future<void> imprimirPreCuentaMesa() async {
    setState(() => procesando = true);
    try {
      // 🔥 NUEVO: Pedir número de pedido antes de imprimir
      String? numeroPedido = await _solicitarNumeroPedido();
      if (numeroPedido == null) {
        if (mounted) setState(() => procesando = false);
        return;
      }

      await InvoiceService.generarYEnviarFactura(
        items: carrito,
        subtotal: totalVenta,
        costoEnvio: 0,
        direccion: "",
        telefono: "",
        metodoPago: "Por Pagar",
        datosEnvio: "PRE-CUENTA: ${widget.mesaNombre}",
        efectivo: 0,
        transferencia: 0,
        numeroPedido: numeroPedido, // 🔥 NUEVO: Enviar número de pedido
      );
    } catch (e) {
      print(e);
    } finally {
      if(mounted) setState(() => procesando = false);
    }
  }

  //////////////////////////////////////////////////////////////////////////////////
  //BOTÓN 2: CERRAR CUENTA
  //////////////////////////////////////////////////////////////////////////////////

  Future<void> cerrarCuentaMesa() async {
    double granTotal = totalVenta;
    double efectivoValor = 0;
    double transferenciaValor = 0;
    String metodoPago = "Efectivo";
    bool usarEfectivo = true;
    bool usarTransferencia = false;

    // 🔥 NUEVO: Pedir número de pedido antes de cobrar
    String? numeroPedido = await _solicitarNumeroPedido();
    if (numeroPedido == null) return;

    bool? confirmar = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final efectivoCtrl = TextEditingController();
        final transferenciaCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text("Cobrar Mesa"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Total: \$${granTotal.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  /// 💵 EFECTIVO
                  Row(
                    children: [
                      Checkbox(
                        value: usarEfectivo,
                        onChanged: (v) {
                          setStateSB(() {
                            usarEfectivo = v!;
                            if (usarEfectivo && !usarTransferencia) {
                              efectivoCtrl.text = granTotal.toStringAsFixed(0);
                            } else if (usarEfectivo && usarTransferencia) {
                              double mitad = granTotal / 2;
                              efectivoCtrl.text = mitad.toStringAsFixed(0);
                              transferenciaCtrl.text = mitad.toStringAsFixed(0);
                            } else {
                              efectivoCtrl.clear();
                            }
                          });
                        },
                      ),
                      const Text("Efectivo"),
                    ],
                  ),
                  TextField(
                    controller: efectivoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 10),
                  /// 💳 TRANSFERENCIA
                  Row(
                    children: [
                      Checkbox(
                        value: usarTransferencia,
                        onChanged: (v) {
                          setStateSB(() {
                            usarTransferencia = v!;
                            if (usarTransferencia && !usarEfectivo) {
                              transferenciaCtrl.text = granTotal.toStringAsFixed(0);
                            } else if (usarTransferencia && usarEfectivo) {
                              double mitad = granTotal / 2;
                              efectivoCtrl.text = mitad.toStringAsFixed(0);
                              transferenciaCtrl.text = mitad.toStringAsFixed(0);
                            } else {
                              transferenciaCtrl.clear();
                            }
                          });
                        },
                      ),
                      const Text("Transferencia"),
                    ],
                  ),
                  TextField(
                    controller: transferenciaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    efectivoValor = double.tryParse(efectivoCtrl.text) ?? 0;
                    transferenciaValor = double.tryParse(transferenciaCtrl.text) ?? 0;

                    if ((efectivoValor + transferenciaValor) != granTotal) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Los valores no coinciden con el total")),
                      );
                      return;
                    }

                    metodoPago = (transferenciaValor > 0 && efectivoValor > 0)
                        ? "Mixto"
                        : (transferenciaValor > 0 ? "Transferencia" : "Efectivo");

                    Navigator.pop(ctx, true);
                  },
                  child: const Text("Cobrar"),
                )
              ],
            );
          },
        );
      },
    );

    if (confirmar != true) return;

    setState(() => procesando = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      var ventaRef = FirebaseFirestore.instance.collection('ventas').doc();

      batch.set(ventaRef, {
        'fecha': DateTime.now(),
        'subtotal': totalVenta,
        'total': totalVenta,
        'items': carrito,
        'mesa': widget.mesaNombre,
        'estado': 'completada',
        'metodoPago': metodoPago,
        'efectivo': efectivoValor,
        'transferencia': transferenciaValor,
        'numeroPedido': numeroPedido, // 🔥 NUEVO: Guardar número de pedido
      });

      batch.update(
        FirebaseFirestore.instance.collection('mesas').doc(widget.mesaId),
        {
          'estado': 'libre',
          'pedidos': []
        }
      );

      await batch.commit();

      await InvoiceService.generarYEnviarFactura(
        items: carrito,
        subtotal: totalVenta,
        costoEnvio: 0,
        direccion: "",
        telefono: "",
        metodoPago: metodoPago,
        datosEnvio: "Mesa: ${widget.mesaNombre}",
        efectivo: efectivoValor,
        transferencia: transferenciaValor,
        numeroPedido: numeroPedido, // 🔥 NUEVO: Enviar número de pedido
      );

      Navigator.pop(context);

    } catch(e) {
      print(e);
    } finally {
      if(mounted) setState(() => procesando = false);
    }
  }

  //////////////////////////////////////////////////
  void eliminarDelCarrito(int index) {
    setState(() {
      // Si tiene más de 1, le restamos. Si solo queda 1, lo borramos.
      if (carrito[index]['cantidad'] > 1) {
        carrito[index]['cantidad']--;
      } else {
        carrito.removeAt(index);
      }
      calcularTotales();
    });
  }

  void calcularTotales() {
    totalVenta = 0;
    totalGanancia = 0;
    for (var item in carrito) {
      // Multiplicamos Precio x Cantidad
      totalVenta += (item['precio'] * item['cantidad']);
      totalGanancia += (item['ganancia'] * item['cantidad']);
    }
  }

  void editarNota(int index) {
    final notaCtrl = TextEditingController(text: carrito[index]['nota']);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Nota para ${carrito[index]['nombre']}"),
        content: TextField(
          controller: notaCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Ej: Sin cebolla, término medio...",
            border: OutlineInputBorder()
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                carrito[index]['nota'] = notaCtrl.text;
              });
              Navigator.pop(c);
            },
            child: const Text("Guardar Nota"),
          )
        ],
      ),
    );
  }



//antes esta 
  /* ======================================================
      🔥 NUEVO: FUNCIÓN PARA SOLICITAR NÚMERO DE PEDIDO
  ====================================================== */
  //ahora esta
    /* ======================================================
      🔥 GENERAR NÚMERO DE PEDIDO AUTOMÁTICO
      (Contador independiente que se reinicia cada día)
  ====================================================== */
  Future<String?> _solicitarNumeroPedido() async {
    // 1. Obtener la fecha actual en formato YYYY-MM-DD para usar como clave
    final hoy = DateTime.now();
    final fechaKey = DateFormat('yyyy-MM-dd').format(hoy);
    
    try {
      // 2. Referencia al documento de control de numeración
      final controlRef = FirebaseFirestore.instance
          .collection('contadores')
          .doc('numeroPedido');
      
      // 3. Obtener el contador del día actual
      final docSnapshot = await controlRef.get();
      
      int siguienteNumero = 1;
      
      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        // Buscar el contador para la fecha actual
        if (data.containsKey(fechaKey)) {
          int ultimoNumero = data[fechaKey] as int;
          siguienteNumero = ultimoNumero + 1;
        }
      }
      
      String numeroPedido = siguienteNumero.toString();
      
      // 4. Mostrar diálogo con el número generado
      bool continuar = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Número de Pedido"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Se ha generado automáticamente el siguiente número:"),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Text(
                  "#$numeroPedido",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 15),
              const Text("¿Deseas continuar con este número?", textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Continuar"),
            ),
          ],
        ),
      );
      
      if (continuar != true) return null;
      
      // 5. ACTUALIZAR EL CONTADOR PARA ESTE DÍA
      await controlRef.set({
        fechaKey: siguienteNumero,
      }, SetOptions(merge: true));
      
      // 6. También guardar en la mesa si es necesario
      if (esMesa && widget.mesaId != null) {
        await FirebaseFirestore.instance
            .collection('mesas')
            .doc(widget.mesaId)
            .update({
              'ultimoNumeroPedido': numeroPedido,
            }).catchError((e) {
          print("Error actualizando mesa: $e");
        });
      }
      
      return numeroPedido;
      
    } catch (e) {
      print("Error al generar número de pedido: $e");
      // Fallback: número basado en timestamp
      String fallbackNumero = DateTime.now().millisecondsSinceEpoch.toString().substring(10, 13);
      return fallbackNumero;
    }
  }



  /* ======================================================
      PROCESAR VENTA (FLUJO COMPLETO)
  ====================================================== */
  Future<void> procesarVenta() async {
    if (carrito.isEmpty) return;

    // 🔥 NUEVO: Pedir número de pedido al inicio
    String? numeroPedido = await _solicitarNumeroPedido();
    if (numeroPedido == null) return;

    // 🔥 NUEVO: SI ESTA VENTA VIENE DESDE UNA MESA ABIERTA
    if (esMesa) {
      await actualizarPedidoMesa();
      return;
    }

    // --- VARIABLES INICIALES ---
    bool esDomicilio = false;
    String direccion = "";
    String telefono = "";
    double costoDomicilio = 0;
    String mesaSeleccionada = "Barra / Llevar"; // Valor por defecto
    String metodoPago = "Efectivo";

    // 1. PREGUNTA INICIAL: ¿DOMICILIO O MESA?
    bool? respDomicilio = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Tipo de Pedido"),
        content: const Text("¿Dónde es el pedido?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null), 
            child: const Text("CANCELAR", style: TextStyle(color: Colors.red))
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // False = MESA
            child: const Text("Mesa / Llevar")
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), // True = DOMICILIO
            child: const Text("DOMICILIO")
          ),
        ],
      ),
    );
    if (respDomicilio == null) return; // Cancelado

    // 2. LÓGICA SEGÚN TIPO
    if (respDomicilio == true) {
      // ---------------- ES DOMICILIO ----------------
      esDomicilio = true;
      final dirCtrl = TextEditingController();
      final telCtrl = TextEditingController();
      final costoCtrl = TextEditingController();

      bool? continuar = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Datos de Domicilio"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: dirCtrl, decoration: const InputDecoration(labelText: "Dirección", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on))),
                const SizedBox(height: 10),
                TextField(controller: telCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Teléfono / Nombre", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
                const SizedBox(height: 10),
                TextField(controller: costoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Costo Envío \$", border: OutlineInputBorder(), prefixIcon: Icon(Icons.motorcycle))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Atrás")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Continuar"))
          ],
        ),
      );
      
      if (continuar == null) return;
      direccion = dirCtrl.text.trim();
      telefono = telCtrl.text.trim();
      costoDomicilio = double.tryParse(costoCtrl.text) ?? 0;

    } else {
      // ---------------- ES MESA (NUEVA LÓGICA) ----------------
      String? mesaElegida = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Selecciona la Mesa"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('mesas').orderBy('creada').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var mesas = snapshot.data!.docs;
                if (mesas.isEmpty) return const Center(child: Text("No hay mesas creadas.\n(Crea mesas en el menú principal)"));

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, 
                    childAspectRatio: 2.5, 
                    crossAxisSpacing: 10, 
                    mainAxisSpacing: 10
                  ),
                  itemCount: mesas.length,
                  itemBuilder: (context, index) {
                    var m = mesas[index];
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[100], 
                        foregroundColor: Colors.black
                      ),
                      // Al tocar, devolvemos el nombre de la mesa
                      onPressed: () => Navigator.pop(ctx, m['nombre']),
                      child: Text(m['nombre'], textAlign: TextAlign.center),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("CANCELAR", style: TextStyle(color: Colors.red)))
          ],
        ),
      );

      if (mesaElegida == null) return; // Si no eligió mesa, cancela
      mesaSeleccionada = mesaElegida;
    }

    double granTotal = totalVenta + costoDomicilio;
    double efectivoValor = 0;
    double transferenciaValor = 0;

    // 3. CONFIRMACIÓN Y PAGO
    bool? generarFactura = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final efectivoCtrl = TextEditingController();
        final transferenciaCtrl = TextEditingController();
        bool usarEfectivo = false;
        bool usarTransferencia = false;

        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text("Finalizar Venta"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Total: \$${granTotal.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18
                    ),
                  ),
                  const SizedBox(height: 10),
                  /// 💵 EFECTIVO
                  Row(
                    children: [
                      Checkbox(
                        value: usarEfectivo,
                        onChanged: (v) {
                          setStateSB(() {
                            usarEfectivo = v!;
                            if (usarEfectivo && !usarTransferencia) {
                              efectivoCtrl.text = granTotal.toStringAsFixed(0);
                            } else if (usarEfectivo && usarTransferencia) {
                              double mitad = granTotal / 2;
                              efectivoCtrl.text = mitad.toStringAsFixed(0);
                              transferenciaCtrl.text = mitad.toStringAsFixed(0);
                            } else {
                              efectivoCtrl.clear();
                            }
                          });
                        },
                      ),
                      const Text("Efectivo"),
                    ],
                  ),
                  TextField(
                    controller: efectivoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 10),
                  /// 💳 TRANSFERENCIA
                  Row(
                    children: [
                      Checkbox(
                        value: usarTransferencia,
                        onChanged: (v) {
                          setStateSB(() {
                            usarTransferencia = v!;
                            if (usarTransferencia && !usarEfectivo) {
                              transferenciaCtrl.text = granTotal.toStringAsFixed(0);
                            } else if (usarTransferencia && usarEfectivo) {
                              double mitad = granTotal / 2;
                              efectivoCtrl.text = mitad.toStringAsFixed(0);
                              transferenciaCtrl.text = mitad.toStringAsFixed(0);
                            } else {
                              transferenciaCtrl.clear();
                            }
                          });
                        },
                      ),
                      const Text("Transferencia"),
                    ],
                  ),
                  TextField(
                    controller: transferenciaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () {
                    efectivoValor = double.tryParse(efectivoCtrl.text) ?? 0;
                    transferenciaValor = double.tryParse(transferenciaCtrl.text) ?? 0;

                    if ((efectivoValor + transferenciaValor) != granTotal) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Los valores no coinciden con el total")),
                      );
                      return;
                    }

                    metodoPago = (transferenciaValor > 0 && efectivoValor > 0)
                        ? "Mixto"
                        : (transferenciaValor > 0 ? "Transferencia" : "Efectivo");

                    Navigator.pop(ctx, false);
                  },
                  child: const Text("Guardar"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    efectivoValor = double.tryParse(efectivoCtrl.text) ?? 0;
                    transferenciaValor = double.tryParse(transferenciaCtrl.text) ?? 0;

                    if ((efectivoValor + transferenciaValor) != granTotal) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Los valores no coinciden con el total")),
                      );
                      return;
                    }

                    metodoPago = (transferenciaValor > 0 && efectivoValor > 0)
                        ? "Mixto"
                        : (transferenciaValor > 0 ? "Transferencia" : "Efectivo");

                    Navigator.pop(ctx, true);
                  },
                  child: const Text("Factura"),
                )
              ],
            );
          },
        );
      },
    );

    if (generarFactura == null) return;

    // 4. GUARDAR
    setState(() => procesando = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      var ventaRef = FirebaseFirestore.instance.collection('ventas').doc();

      // Preparamos info completa para PDF
      String infoDomicilioDB = esDomicilio ? "Dir: $direccion - Tel: $telefono" : "";

      batch.set(ventaRef, {
        'fecha': DateTime.now(),
        'subtotal': totalVenta,
        'costoDomicilio': costoDomicilio,
        'total': granTotal,
        'gananciaTotal': totalGanancia,
        'items': carrito,
        'esDomicilio': esDomicilio,
        'direccion': direccion,
        'telefono': telefono,
        'mesa': mesaSeleccionada,
        'datosDomicilio': infoDomicilioDB,
        'metodoPago': metodoPago,
        'efectivo': efectivoValor,
        'transferencia': transferenciaValor,
        'estado': 'completada',
        'vendedor': "Usuario App",
        'numeroPedido': numeroPedido, // 🔥 NUEVO: Usar el número ingresado
      });

      // Inventario
      for (var itemVenta in carrito) {
        if (itemVenta['id_producto'] != null) {
          var prodDoc = await FirebaseFirestore.instance.collection('productos').doc(itemVenta['id_producto']).get();
          if (prodDoc.exists) {
            Map<String, dynamic> data = prodDoc.data() as Map<String, dynamic>;
            if (data.containsKey('receta')) {
              for (var ing in data['receta']) {
                var insumoRef = FirebaseFirestore.instance.collection('inventario').doc(ing['idInsumo']);
                var snap = await insumoRef.get();
                if(snap.exists) {
                  // Descuento = Receta * Cantidad Vendida
                  double descuento = (ing['cantidad'] as num).toDouble() * (itemVenta['cantidad'] as int);
                  batch.update(insumoRef, {'stock': FieldValue.increment(-descuento)});
                }
              }
            }
          }
        }
      }

      await batch.commit();

      if (generarFactura) {
        // Enviar datos al PDF
        String infoMesa = esDomicilio ? "" : "Mesa: $mesaSeleccionada";

        await InvoiceService.generarYEnviarFactura(
          items: carrito, 
          subtotal: totalVenta,
          costoEnvio: costoDomicilio,
          direccion: direccion,
          telefono: telefono,
          metodoPago: metodoPago,
          datosEnvio: esDomicilio ? "DOMICILIO" : "Mesa: $mesaSeleccionada",
          efectivo: efectivoValor,
          transferencia: transferenciaValor,
          numeroPedido: numeroPedido, // 🔥 NUEVO: Enviar número de pedido
        );
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Venta Guardada")));
      }

      setState(() { carrito.clear(); calcularTotales(); });

    } catch (e) {
      showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Error"), content: Text("$e")));
    } finally {
      if(mounted) setState(() => procesando = false);
    }
  }

  ////////////////////////////////////////////////////////////////////////
  /* ======================================================
      INTERFAZ GRÁFICA (UI)
  ====================================================== */

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await guardarPedidosMesa();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            mostrandoHistorial ? "Historial del Día" : "Nueva Venta",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: mostrandoHistorial ? "Volver a Vender" : "Ver Historial",
              icon: Icon(mostrandoHistorial ? Icons.point_of_sale : Icons.history),
              onPressed: () => setState(() => mostrandoHistorial = !mostrandoHistorial),
            )
          ],
        ),
        body: procesando
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Procesando venta e inventario..."),
                  ],
                ),
              )
            : (mostrandoHistorial ? _buildHistoryView() : _buildSalesView()),
      ),
    );
  }

  /* ======================================================
      VISTA DE VENTAS (PRODUCTOS + CARRITO)
  ====================================================== */
  Widget _buildSalesView() {
    return Column(
      children: [
        // --- PARTE SUPERIOR: LISTA DE PRODUCTOS ---
        Expanded(
          flex: 6,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('categorias').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                children: snapshot.data!.docs.map((cat) {
                  return ExpansionTile(
                    title: Text(
                      cat['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                                dense: true,
                                title: Text(p['nombre']),
                                subtitle: Text(
                                  "\$${p['precioVenta']}",
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.orange,
                                    size: 30,
                                  ),
                                  onPressed: () => agregarAlCarrito(p),
                                ),
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
        ),
        const Divider(thickness: 2, height: 2),
        // --- PARTE INFERIOR: CARRITO ---
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart, size: 16, color: Colors.grey),
                    SizedBox(width: 5),
                    Text(
                      "CARRITO (Toca un producto para agregar nota)",
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                // LISTA DEL CARRITO
                Expanded(
                  child: carrito.isEmpty
                      ? const Center(
                          child: Text(
                            "Carrito vacío",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 18,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: carrito.length,
                          itemBuilder: (context, index) {
                            var item = carrito[index];
                            double subtotal = item['precio'] * item['cantidad'];
                            String nota = item['nota'];

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                onTap: () => editarNota(index),
                                title: Text(
                                  "${item['nombre']}  x${item['cantidad']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Subtotal: \$${subtotal.toStringAsFixed(0)}",
                                      style: const TextStyle(color: Colors.green),
                                    ),
                                    if (nota.isNotEmpty)
                                      Text(
                                        "Nota: $nota",
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      onPressed: () => eliminarDelCarrito(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle,
                                          color: Colors.green),
                                      onPressed: () {
                                        setState(() {
                                          carrito[index]['cantidad']++;
                                          calcularTotales();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // --- ZONA DE BOTONES ---
                if (esMesa)
                  // SI ES MESA: 3 BOTONES (Cocina, Imprimir, Cobrar)
                  Row(
                    children: [
                      // 1. COCINA
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: carrito.isEmpty ? null : actualizarPedidoMesa,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant, color: Colors.white, size: 20),
                              Text("COCINA", style: TextStyle(color: Colors.white, fontSize: 10))
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      // 2. IMPRIMIR
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan[600],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: carrito.isEmpty ? null : imprimirPreCuentaMesa,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.print, color: Colors.white, size: 20),
                              Text("IMPRIMIR", style: TextStyle(color: Colors.white, fontSize: 10))
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      // 3. CERRAR CUENTA
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: carrito.isEmpty ? null : cerrarCuentaMesa,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_money, color: Colors.white, size: 20),
                              Text("COBRAR", style: TextStyle(color: Colors.white, fontSize: 10))
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // SI ES VENTA RÁPIDA / DOMICILIO: 1 BOTÓN GRANDE
                  Container(
                    width: double.infinity,
                    height: 60,
                    margin: const EdgeInsets.only(top: 5),
                    child: ElevatedButton(
                      onPressed: carrito.isEmpty ? null : procesarVenta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "CONFIRMAR VENTA",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            "TOTAL: \$${totalVenta.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        )
      ],
    );
  }

  /* ======================================================
      VISTA HISTORIAL (VENTAS DE HOY)
  ====================================================== */
  Widget _buildHistoryView() {
    DateTime inicioDia = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ventas')
          .where('fecha', isGreaterThanOrEqualTo: inicioDia)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No hay ventas registradas hoy"));

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            bool cancelada = data['estado'] == 'cancelada';
            
            // Texto descriptivo de la venta
            String resumen = "";
            List items = data['items'];
            if(items.isNotEmpty) {
              resumen = "${items[0]['nombre']}";
              if(items.length > 1) resumen += " + ${items.length - 1} más";
            }

            return Card(
              color: cancelada ? Colors.red[50] : Colors.white,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: Icon(
                  cancelada ? Icons.cancel : Icons.check_circle, 
                  color: cancelada ? Colors.red : Colors.green
                ),
                title: Text(
                  cancelada ? "CANCELADA" : "\$${data['total']}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    decoration: cancelada ? TextDecoration.lineThrough : null,
                    color: cancelada ? Colors.red : Colors.black
                  )
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resumen, style: const TextStyle(fontSize: 12)),
                    Text(DateFormat('hh:mm a').format(data['fecha'].toDate()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                trailing: !cancelada 
                  ? IconButton(
                      tooltip: "Anular Venta",
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _anularVenta(doc),
                    ) 
                  : const Text("Anulada", style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Función para anular venta desde el historial
  void _anularVenta(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Anular Venta?"),
        content: const Text("Esta acción marcará la venta como cancelada y el dinero se restará del balance. NO SE PUEDE DESHACER."),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Solo actualizamos el estado, no borramos el documento para mantener auditoría
              doc.reference.update({'estado': 'cancelada'});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Venta Anulada")));
            },
            child: const Text("ANULAR", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}