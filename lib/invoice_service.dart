import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class InvoiceService {

  // 1. PARA WHATSAPP (PDF)
  static Future<void> generarYEnviarFactura({
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double costoEnvio,
    required String direccion,
    required String telefono,
    required String metodoPago,
    required String datosEnvio,
    required double efectivo,
    required double transferencia,
    String? numeroPedido,
  }) async {

    final pdf = await _construirTicket(
      items,
      subtotal,
      costoEnvio,
      direccion,
      telefono,
      metodoPago,
      datosEnvio,
      efectivo,
      transferencia,
      numeroPedido,
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Factura.pdf");

    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Factura El Legendario'
    );
  }

  // 2. PARA IMPRESORA (IMAGEN)
  static Future<void> generarYEnviarImagen({
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double costoEnvio,
    required String direccion,
    required String telefono,
    required String metodoPago,
    required String datosEnvio,
    required double efectivo,
    required double transferencia,
    String? numeroPedido,
  }) async {

    final pdf = await _construirTicket(
      items,
      subtotal,
      costoEnvio,
      direccion,
      telefono,
      metodoPago,
      datosEnvio,
      efectivo,
      transferencia,
      numeroPedido,
    );

    await for (var page in Printing.raster(
      await pdf.save(),
      pages: [0],
      dpi: 203
    )) {

      final image = await page.toPng();

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/ticket_print.png");

      await file.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Imprimir Ticket'
      );

      break;
    }
  }

  // DISEÑO DEL TICKET
  static Future<pw.Document> _construirTicket(
    List<Map<String, dynamic>> items,
    double subtotal,
    double costoEnvio,
    String direccion,
    String telefono,
    String metodoPago,
    String datosEnvio,
    double efectivo,
    double transferencia,
    String? numeroPedido,
  ) async {

    final pdf = pw.Document();
    final fecha = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());

    // IMAGEN DE FONDO
    final logoBytes = await rootBundle.load('assets/icon/imagen.png');
    final imageLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80.copyWith(
          width: 90 * PdfPageFormat.mm,
        ),
        margin: const pw.EdgeInsets.all(8),

        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.white,
            width: double.infinity,
            child: pw.Stack(
              children: [
                // MARCA DE AGUA
                pw.Center(
                  child: pw.Opacity(
                    opacity: 0.4,
                    child: pw.Image(
                      imageLogo,
                      width: 160,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
                // CONTENIDO
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // TITULO
                    pw.Text(
                      "EL LEGENDARIO",
                      style: pw.TextStyle(
                        fontSize: 26,  // ✅ 28 → 30
                        fontWeight: pw.FontWeight.bold
                      )
                    ),
                    pw.SizedBox(height: 8),
                    
                    // NÚMERO DE PEDIDO
                    if (numeroPedido != null && numeroPedido.isNotEmpty) ...[
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey, width: 1),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          "PEDIDO #$numeroPedido",
                          style: pw.TextStyle(
                            fontSize: 24,  // ✅ 22 → 24
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                    ],
                    
                    pw.Divider(borderStyle: pw.BorderStyle.dashed),
                    pw.Text(
                      "Fecha: $fecha",
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)  // ✅ 18 → 20
                    ),
                    pw.SizedBox(height: 8),
                    
                    // MESA O DOMICILIO
                    if (datosEnvio.isNotEmpty) ...[
                      pw.Text(
                        datosEnvio.contains("Mesa") ? datosEnvio : "DOMICILIO",
                        style: pw.TextStyle(
                          fontSize: 20,  // ✅ 18 → 20
                          fontWeight: pw.FontWeight.bold
                        )
                      ),
                      if (direccion.isNotEmpty) ...[
                        pw.SizedBox(height: 5),
                        pw.Text(
                          "Dir: $direccion",
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)  // ✅ 18 → 20
                        ),
                        pw.Text(
                          "Tel: $telefono",
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)  // ✅ 18 → 20
                        ),
                      ]
                    ],
                    pw.SizedBox(height: 8),
                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    // PRODUCTOS
                    ...items.map((item) => pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                "${item['cantidad']}x ${item['nombre']}",
                                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),  // ✅ 14 → 16
                              ),
                            ),
                            pw.Text(
                              "\$${(item['precio'] * (item['cantidad'] ?? 1)).toStringAsFixed(0)}",
                              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),  // ✅ 14 → 16
                            ),
                          ],
                        ),
                        // NOTA
                        if (item['nota'] != null && item['nota'].toString().isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 5, top: 2),
                            child: pw.Text(
                              "• Nota: ${item['nota']}",
                              style: pw.TextStyle(
                                fontSize: 13,  // ✅ 11 → 13
                                fontWeight: pw.FontWeight.bold,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          ),
                        pw.SizedBox(height: 4),
                      ],
                    )),
                    pw.Divider(borderStyle: pw.BorderStyle.dashed),

                    // DOMICILIO
                    if (costoEnvio > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "Domicilio:",
                            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)  // ✅ 18 → 20
                          ),
                          pw.Text(
                            "\$${costoEnvio.toStringAsFixed(0)}",
                            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)  // ✅ 18 → 20
                          ),
                        ],
                      ),
                    pw.SizedBox(height: 8),

                    // SUBTOTAL
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "Subtotal:",
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)  // ✅ 18 → 20
                        ),
                        pw.Text(
                          "\$${subtotal.toStringAsFixed(0)}",
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)  // ✅ 18 → 20
                        )
                      ]
                    ),
                    pw.SizedBox(height: 8),

                    // 🔥 TOTAL - SIN CAMBIO (se mantiene en 16)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "TOTAL PAGAR:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16  // ✅ SIN CAMBIO
                          )
                        ),
                        pw.Text(
                          "\$${(subtotal + costoEnvio).toStringAsFixed(0)}",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16  // ✅ SIN CAMBIO
                          )
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 15),

                    if (metodoPago == "Mixto") ...[
                      pw.Text(
                        "Pago: Mixto",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 20,  // ✅ 18 → 20
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        "Efectivo: \$${efectivo.toStringAsFixed(0)}",
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)  // ✅ 16 → 18
                      ),
                      pw.Text(
                        "Transferencia: \$${transferencia.toStringAsFixed(0)}",
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)  // ✅ 16 → 18
                      ),
                    ] else ...[
                      pw.Text(
                        "Pago: $metodoPago",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 20  // ✅ 18 → 20
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 15),

                    pw.Text(
                      "¡Gracias por tu compra!",
                      style: pw.TextStyle(
                        fontSize: 20,  // ✅ 18 → 20
                        fontWeight: pw.FontWeight.bold,
                        fontStyle: pw.FontStyle.italic
                      )
                    ),
                    pw.SizedBox(height: 8),

                    pw.Divider(borderStyle: pw.BorderStyle.dashed),
                    pw.SizedBox(height: 8),

                    pw.Text(
                      "📍 NOS UBICAMOS EN:",
                      style: pw.TextStyle(
                        fontSize: 18,  // ✅ 16 → 18
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      "Calle 19 Carrera 6a esquina",
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),  // ✅ 14 → 16
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "📞 TELÉFONO: 300 1687639",
                      style: pw.TextStyle(
                        fontSize: 16,  // ✅ 14 → 16
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 15),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }
}