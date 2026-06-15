import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _mensajes = [
    {'rol': 'bot', 'texto': '👋 Hola Admin. Soy tu analista financiero.\nToca una pregunta para ver estadísticas reales.'}
  ];

  final List<String> _preguntas = const [
    "¿Cuánto se ha vendido hoy?",
    "¿Cuál es el balance neto de hoy?",
    "¿Cuál es el margen de ganancia total hoy?",
    "¿Cuál es el producto más vendido?",
    "¿Cuál es el producto que menos se vende?",
    "¿Cuál es la categoría favorita?",
    "¿Qué producto deja más ganancia?",
    "¿Qué día de la semana es el más fuerte?",
    "¿Cuánto se gastó en insumos este mes?",
    "¿Cuántas hamburguesas se vendieron esta semana?",
    "¿Cuál es la bebida más pedida?",
    "¿Cuál es el crecimiento respecto al mes anterior?",
    "¿Recomendación para mejorar ventas?"
  ];

  void _responder(String pregunta) {
    setState(() {
      _mensajes.add({'rol': 'user', 'texto': pregunta});
      _mensajes.add({'rol': 'bot', 'texto': 'Analizando base de datos... ⏳'});
    });
    _scrollAbajo();

    _procesarPregunta(pregunta).then((respuesta) {
      setState(() {
        _mensajes.removeLast(); 
        _mensajes.add({'rol': 'bot', 'texto': respuesta});
      });
      _scrollAbajo();
    });
  }

  void _scrollAbajo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ===============================================================
  // 🧠 CEREBRO DEL ASISTENTE (BLINDADO CONTRA ERRORES)
  // ===============================================================
  Future<String> _procesarPregunta(String pregunta) async {
    try {
      final now = DateTime.now();
      final inicioDia = DateTime(now.year, now.month, now.day);
      final inicioMes = DateTime(now.year, now.month, 1);
      
      // 1. VENTAS DE HOY
      if (pregunta.contains("vendido hoy")) {
        var docs = await _getVentas(inicioDia);
        double total = 0;
        for (var d in docs) {
          var data = d.data() as Map<String, dynamic>;
          total += (data['total'] ?? 0).toDouble();
        }
        return "💰 Hoy se ha vendido un total de: \$${_fmt(total)}";
      }

      // 2. BALANCE NETO HOY
      if (pregunta.contains("balance neto")) {
        var ventas = await _getVentas(inicioDia);
        var gastos = await _getGastos(inicioDia);
        
        double totalV = 0;
        for (var v in ventas) {
          var data = v.data() as Map<String, dynamic>;
          totalV += (data['total'] ?? 0).toDouble();
        }
        
        double totalG = 0;
        for (var g in gastos) {
          var data = g.data() as Map<String, dynamic>;
          totalG += (data['monto'] ?? 0).toDouble();
        }
        
        return "📊 Balance de Hoy:\n\n(+) Ventas: \$${_fmt(totalV)}\n(-) Gastos: \$${_fmt(totalG)}\n\n= NETO: \$${_fmt(totalV - totalG)}";
      }

      // 3. MARGEN DE GANANCIA HOY
      if (pregunta.contains("margen de ganancia")) {
        var ventas = await _getVentas(inicioDia);
        double ganancia = 0;
        for (var v in ventas) {
          var data = v.data() as Map<String, dynamic>;
          // Usamos ?? 0 para evitar el error "field does not exist"
          ganancia += (data['gananciaTotal'] ?? 0).toDouble();
        }
        return "💎 Tu ganancia limpia hoy (Venta - Costo Producción) es: \$${_fmt(ganancia)}";
      }

      // 4. GASTOS DEL MES
      if (pregunta.contains("gastó en insumos") || pregunta.contains("este mes")) {
        var gastos = await _getGastos(inicioMes);
        double total = 0;
        for (var g in gastos) {
           var data = g.data() as Map<String, dynamic>;
           total += (data['monto'] ?? 0).toDouble();
        }
        return "📉 En lo que va del mes, los gastos suman: \$${_fmt(total)}";
      }

      // 5. PRODUCTO MÁS VENDIDO
      if (pregunta.contains("más vendido")) {
        return await _analizarProductos(top: true);
      }

      // 6. PRODUCTO MENOS VENDIDO
      if (pregunta.contains("menos se vende")) {
        return await _analizarProductos(top: false);
      }

      // 7. CATEGORÍA FAVORITA
      if (pregunta.contains("categoría favorita")) {
        return await _analizarCategorias();
      }

      // 8. PRODUCTO CON MÁS GANANCIA UNITARIA
      if (pregunta.contains("deja más ganancia")) {
        var prods = await FirebaseFirestore.instance.collection('productos')
            .orderBy('ganancia', descending: true).limit(1).get();
        if(prods.docs.isEmpty) return "No hay productos registrados.";
        var p = prods.docs.first.data();
        return "🏆 El producto estrella en margen es '${p['nombre']}'.\nLe ganas \$${_fmt((p['ganancia'] ?? 0).toDouble())} por unidad.";
      }

      // 9. HAMBURGUESAS ESTA SEMANA
      if (pregunta.contains("hamburguesas")) {
        DateTime lunes = now.subtract(Duration(days: now.weekday - 1));
        var ventas = await _getVentas(DateTime(lunes.year, lunes.month, lunes.day));
        int count = 0;
        for(var v in ventas) {
          var data = v.data() as Map<String, dynamic>;
          List items = data['items'] ?? [];
          for(var item in items) {
            if(item['nombre'].toString().toLowerCase().contains('hamburguesa')) {
              count += (item['cantidad'] ?? 1) as int;
            }
          }
        }
        return "🍔 Esta semana se han vendido $count hamburguesas.";
      }
      
      // 10. BEBIDA MÁS PEDIDA
      if (pregunta.contains("bebida")) {
         return await _buscarItemMasVendidoPorPalabraClave(['coca', 'gaseosa', 'jugo', 'cerveza', 'agua', 'limonada']);
      }

      // 11. DÍA MÁS FUERTE
      if (pregunta.contains("día de la semana")) {
        return await _analizarMejorDia();
      }

      // 12. CRECIMIENTO VS MES ANTERIOR
      if (pregunta.contains("crecimiento")) {
        return await _analizarCrecimiento();
      }

      // 13. RECOMENDACIÓN
      if (pregunta.contains("recomendación")) {
        return await _generarRecomendacion();
      }

      return "No tengo datos suficientes para responder eso aún.";

    } catch (e) {
      return "Ocurrió un error leyendo los datos antiguos: $e";
    }
  }

  // --- FUNCIONES AUXILIARES BLINDADAS ---

  Future<List<QueryDocumentSnapshot>> _getVentas(DateTime desde) async {
    var snap = await FirebaseFirestore.instance.collection('ventas')
        .where('fecha', isGreaterThanOrEqualTo: desde)
        .get();
    
    // FILTRO MANUAL SEGURO:
    // En lugar de confiar en que todos tienen el campo 'estado', lo verificamos.
    return snap.docs.where((d) {
      var data = d.data() as Map<String, dynamic>;
      // Si no tiene campo estado, asumimos que es válida (no cancelada)
      return (data['estado'] ?? '') != 'cancelada';
    }).toList();
  }

  Future<List<QueryDocumentSnapshot>> _getGastos(DateTime desde) async {
    var snap = await FirebaseFirestore.instance.collection('gastos')
        .where('fecha', isGreaterThanOrEqualTo: desde).get();
    return snap.docs;
  }

  Future<String> _analizarProductos({required bool top}) async {
    var fechaInicio = DateTime.now().subtract(const Duration(days: 30));
    var ventas = await _getVentas(fechaInicio);
    Map<String, int> contador = {};

    for (var v in ventas) {
      var data = v.data() as Map<String, dynamic>;
      List items = data['items'] ?? [];
      for (var item in items) {
        String nombre = item['nombre'] ?? 'Producto desc.';
        int cant = (item['cantidad'] ?? 1) as int;
        contador[nombre] = (contador[nombre] ?? 0) + cant;
      }
    }

    if (contador.isEmpty) return "No hay ventas suficientes para analizar.";

    var listaOrdenada = contador.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); 

    if (top) {
      var mejor = listaOrdenada.first;
      return "🥇 El más vendido es: ${mejor.key} (${mejor.value} unds).";
    } else {
      var peores = listaOrdenada.reversed.take(3).toList();
      String texto = "⚠️ Los menos vendidos son:\n";
      for (var p in peores) {
        texto += "- ${p.key} (${p.value} unds)\n";
      }
      return texto;
    }
  }

  Future<String> _analizarCategorias() async {
    var fechaInicio = DateTime.now().subtract(const Duration(days: 30));
    var ventas = await _getVentas(fechaInicio);
    
    var prodSnap = await FirebaseFirestore.instance.collection('productos').get();
    Map<String, String> prodCatMap = {}; 
    for (var p in prodSnap.docs) prodCatMap[p['nombre']] = p['categoriaId'];

    var catSnap = await FirebaseFirestore.instance.collection('categorias').get();
    Map<String, String> catNameMap = {}; 
    for (var c in catSnap.docs) catNameMap[c.id] = c['nombre'];

    Map<String, int> catCount = {};

    for (var v in ventas) {
      var data = v.data() as Map<String, dynamic>;
      List items = data['items'] ?? [];
      for (var item in items) {
        String? catId = prodCatMap[item['nombre']];
        if (catId != null) {
          String catNombre = catNameMap[catId] ?? "Otros";
          catCount[catNombre] = (catCount[catNombre] ?? 0) + ((item['cantidad'] ?? 1) as num).toInt();
        }
      }
    }

    if(catCount.isEmpty) return "Faltan datos de categorías.";
    
    var topCat = catCount.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return "🔥 La categoría favorita es '${topCat.first.key}' con ${topCat.first.value} productos vendidos.";
  }

  Future<String> _buscarItemMasVendidoPorPalabraClave(List<String> keywords) async {
    var ventas = await _getVentas(DateTime.now().subtract(const Duration(days: 30)));
    Map<String, int> counts = {};

    for(var v in ventas) {
      var data = v.data() as Map<String, dynamic>;
      List items = data['items'] ?? [];
      for(var item in items) {
        String nombre = item['nombre'].toString().toLowerCase();
        for(var k in keywords) {
          if(nombre.contains(k)) {
            counts[item['nombre']] = (counts[item['nombre']] ?? 0) + ((item['cantidad'] ?? 1) as num).toInt();
            break; 
          }
        }
      }
    }
    
    if(counts.isEmpty) return "No se han vendido bebidas recientemente.";
    var top = counts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return "🥤 La bebida más pedida es: ${top.first.key}";
  }

  Future<String> _analizarMejorDia() async {
    var ventas = await _getVentas(DateTime.now().subtract(const Duration(days: 60)));
    Map<int, double> dias = {1:0,2:0,3:0,4:0,5:0,6:0,7:0};
    
    for(var v in ventas) {
      var data = v.data() as Map<String, dynamic>;
      DateTime fecha = data['fecha'].toDate();
      dias[fecha.weekday] = (dias[fecha.weekday] ?? 0) + (data['total'] as num).toDouble();
    }
    
    int mejorDia = dias.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    const nombres = ["","Lunes","Martes","Miércoles","Jueves","Viernes","Sábado","Domingo"];
    
    return "📅 Tu día más fuerte históricamente es el ${nombres[mejorDia]}.";
  }

  Future<String> _analizarCrecimiento() async {
    DateTime now = DateTime.now();
    DateTime inicioMesActual = DateTime(now.year, now.month, 1);
    DateTime inicioMesPasado = DateTime(now.year, now.month - 1, 1);
    DateTime finMesPasado = DateTime(now.year, now.month, 0); 

    var ventasActual = await _getVentas(inicioMesActual);
    var ventasPasadoQuery = await FirebaseFirestore.instance.collection('ventas')
        .where('fecha', isGreaterThanOrEqualTo: inicioMesPasado)
        .where('fecha', isLessThanOrEqualTo: finMesPasado).get();

    double totalActual = 0;
    for(var v in ventasActual) {
       var data = v.data() as Map<String, dynamic>;
       totalActual += (data['total'] ?? 0).toDouble();
    }

    double totalPasado = 0;
    for(var v in ventasPasadoQuery.docs) {
       var data = v.data() as Map<String, dynamic>;
       if((data['estado'] ?? '') != 'cancelada') {
         totalPasado += (data['total'] ?? 0).toDouble();
       }
    }

    if (totalPasado == 0) return "No hay datos del mes pasado para comparar.";

    double crecimiento = ((totalActual - totalPasado) / totalPasado) * 100;
    String emoji = crecimiento >= 0 ? "🚀" : "📉";
    
    return "$emoji Comparado con el mes anterior:\n\nMes Pasado: \$${_fmt(totalPasado)}\nEste Mes: \$${_fmt(totalActual)}\n\nVariación: ${crecimiento.toStringAsFixed(1)}%";
  }

  Future<String> _generarRecomendacion() async {
    String menosVendido = await _analizarProductos(top: false); 
    String mensaje = "💡 CONSEJOS:\n\n";

    if (menosVendido.contains("-")) {
       try {
         String nombreMalo = menosVendido.split("\n")[1].split("(")[0].replaceAll("- ", "").trim();
         mensaje += "1. Promociona '$nombreMalo'. Podrías armar un combo con bebida para rotarlo.\n\n";
       } catch (e) {}
    }

    var ventasHoy = await _getVentas(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    if (ventasHoy.length < 5) {
      mensaje += "2. Hoy el movimiento está lento. ¿Qué tal una 'Flash Sale' en redes sociales?\n\n";
    }

    mensaje += "3. Revisa el inventario de 'Queso Costeño' y 'Salsas', suelen agotarse rápido.";
    return mensaje;
  }

  String _fmt(double valor) {
    return valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Asistente IA")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(10),
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                bool esBot = _mensajes[index]['rol'] == 'bot';
                return Align(
                  alignment: esBot ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: esBot ? Colors.white : Colors.indigo[100],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: esBot ? Radius.zero : const Radius.circular(15),
                        bottomRight: esBot ? const Radius.circular(15) : Radius.zero,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
                    ),
                    child: Text(_mensajes[index]['texto']!, style: TextStyle(fontSize: 15, color: esBot ? Colors.black87 : Colors.black)),
                  ),
                );
              },
            ),
          ),
          Container(
            height: 240, 
            color: Colors.grey[200],
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8
              ),
              itemCount: _preguntas.length,
              itemBuilder: (context, index) {
                return ElevatedButton(
                  onPressed: () => _responder(_preguntas[index]),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, 
                    foregroundColor: Colors.indigo[800],
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  child: Text(_preguntas[index], style: const TextStyle(fontSize: 11), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}