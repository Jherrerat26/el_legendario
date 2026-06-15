import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'assistant_screen.dart';
import 'flujos_historicos_screen.dart'; // 🔥 IMPORT NUEVO

class SummaryScreen extends StatefulWidget {
  final bool isAdmin; // 🔥 NUEVO

  const SummaryScreen({super.key, required this.isAdmin}); // 🔥 NUEVO

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {

  DateTimeRange _rangoCaja = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now()
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Finanzas y Reportes", style: GoogleFonts.poppins())
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 BOTÓN ASISTENTE
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white
                ),
                icon: const Icon(Icons.chat),
                label: const Text("ASISTENTE DE NEGOCIO"),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AssistantScreen())
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 🔥 NUEVO BOTÓN SOLO ADMIN
            if (widget.isAdmin)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white
                  ),
                  icon: const Icon(Icons.auto_graph),
                  label: const Text("FLUJOS HISTÓRICOS"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FlujosHistoricosScreen(),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // 🔥 FILTRO FECHA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Resumen Financiero",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: const Text("Filtrar"),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      initialDateRange: _rangoCaja
                    );
                    if (picked != null) {
                      setState(() => _rangoCaja = picked);
                    }
                  },
                )
              ],
            ),

            Text(
              "${DateFormat('dd/MM').format(_rangoCaja.start)} - ${DateFormat('dd/MM').format(_rangoCaja.end)}",
              style: const TextStyle(color: Colors.grey)
            ),

            const SizedBox(height: 15),

            // 🔥 DATOS
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ventas')
                  .where('fecha', isGreaterThanOrEqualTo: _rangoCaja.start)
                  .where('fecha', isLessThanOrEqualTo: _rangoCaja.end.add(const Duration(days: 1)))
                  .snapshots(),
              builder: (context, snapshotVentas) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('gastos')
                      .where('fecha', isGreaterThanOrEqualTo: _rangoCaja.start)
                      .where('fecha', isLessThanOrEqualTo: _rangoCaja.end.add(const Duration(days: 1)))
                      .snapshots(),
                  builder: (context, snapshotGastos) {

                    if (!snapshotVentas.hasData || !snapshotGastos.hasData) {
                      return const LinearProgressIndicator();
                    }

                    double ingresosComida = 0;
                    double ingresosDomicilio = 0;
                    double totalGastos = 0;

                    for (var doc in snapshotVentas.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      if (data['estado'] != 'cancelada') {
                        ingresosComida += (data['subtotal'] ?? 0 as num).toDouble();
                        ingresosDomicilio += (data['costoDomicilio'] ?? 0 as num).toDouble();
                      }
                    }

                    for (var doc in snapshotGastos.data!.docs) {
                      totalGastos += (doc['monto'] as num).toDouble();
                    }

                    double balanceNeto = ingresosComida - totalGastos;

                    return Column(
                      children: [

                        // 🔵 TARJETA PRINCIPAL
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.blue, Colors.blueAccent]
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 5)
                              )
                            ]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "DINERO EN CAJA (Sin Domicilios)",
                                style: TextStyle(color: Colors.white70)
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "\$${balanceNeto.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold
                                )
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        Row(children: [
                          Expanded(child: _miniCard("Venta Comida", ingresosComida, Colors.green)),
                          const SizedBox(width: 10),
                          Expanded(child: _miniCard("Gastos Local", totalGastos, Colors.red))
                        ]),

                        const SizedBox(height: 10),

                        _miniCard("Pago para Domiciliarios", ingresosDomicilio, Colors.orange),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 30),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Tendencia Semanal",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              )
            ),

            const SizedBox(height: 10),

            Container(
              height: 250,
              padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]
              ),
              child: _GraficaSemanal(),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(String titulo, double valor, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Column(
        children: [
          Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          Text("\$${valor.toStringAsFixed(0)}",
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
class _GraficaSemanal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    DateTime hoy = DateTime.now();
    // Inicio de hace 7 días
    DateTime hace7dias = DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 6));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ventas')
          .where('fecha', isGreaterThanOrEqualTo: hace7dias)
          .orderBy('fecha')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        Map<int, double> ventasPorDia = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0};
        double maxVenta = 100;
        
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['estado'] != 'cancelada') {
            DateTime fecha = data['fecha'].toDate();
            // Convertimos a Miles para que quepa en la gráfica (ej: 20000 -> 20)
            double valor = (data['subtotal'] ?? 0 as num).toDouble() / 1000; 
            ventasPorDia[fecha.weekday] = (ventasPorDia[fecha.weekday] ?? 0) + valor;
          }
        }

        // Buscar máximo para escalar
        ventasPorDia.forEach((k,v) { if(v > maxVenta) maxVenta = v; });

        return BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const dias = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
                    if (value < 1 || value > 7) return const Text('');
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(dias[value.toInt() - 1], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(7, (i) {
              int dia = i + 1;
              return BarChartGroupData(
                x: dia,
                barRods: [
                  BarChartRodData(
                    toY: ventasPorDia[dia] ?? 0,
                    color: (ventasPorDia[dia] ?? 0) > 0 ? Colors.blueAccent : Colors.grey[300],
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxVenta * 1.1, color: Colors.grey[100])
                  )
                ]
              );
            }),
          ),
        );
      },
    );
  }
}