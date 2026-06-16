import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Commit Jonathan 15-06
// IMPORTACIONES DE TUS PANTALLAS
import 'login_screen.dart';
import 'sales_screen.dart';      // 
import 'products_screen.dart';   // Productos (Menú)
import 'inventory_screen.dart';  // Inventario (Insumos/Ingredientes)
import 'expenses_screen.dart';   // Gastos
import 'info_screen.dart';       // Información/Resumen Vendedor
import 'admin_screen.dart';      // Configuración Admin
import 'accounts_screen.dart';   // Cuentas
import 'summary_screen.dart';    // Resumen Admin
import 'tables_screen.dart';     // Mesas (si decides implementarlo)

class HomeScreen extends StatelessWidget {
  final String rol;
  const HomeScreen({super.key, required this.rol});

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = rol == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("Menú Principal", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar Sesión",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bienvenido,", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            Text(isAdmin ? "Administrador" : "Vendedor", 
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: _buildMenuItems(context, isAdmin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context, bool isAdmin) {
    if (isAdmin) {
      // --- MENÚ ADMINISTRADOR ---
      return [
        _MenuCard(
          title: "Cuentas", icon: Icons.people, color: Colors.blue, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountsScreen()))
        ),
        _MenuCard(
          title: "Resumen Total", icon: Icons.bar_chart, color: Colors.indigo, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SummaryScreen(isAdmin: isAdmin)))
        ),
        _MenuCard(
          title: "Productos (Menú)", icon: Icons.fastfood, color: Colors.purple, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsScreen()))
        ),
        _MenuCard(
          title: "Inventario (Insumos)", icon: Icons.inventory_2, color: Colors.orange, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()))
        ),
        _MenuCard(
          title: "Configuración", icon: Icons.settings, color: Colors.grey, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()))
        ),
        _MenuCard(
          title: "Mesas", 
          icon: Icons.table_bar, 
          color: Colors.brown, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TablesScreen()))
       ),
      ];
    } else {
      // --- MENÚ VENDEDOR ---
      return [
        _MenuCard(
          title: "Ventas", icon: Icons.point_of_sale, color: Colors.green, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesScreen()))
        ),
        _MenuCard(
          title: "Gastos", icon: Icons.money_off, color: Colors.red, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExpensesScreen()))
        ),
        _MenuCard(
          title: "Inventario (Stock)", icon: Icons.inventory_2, color: Colors.orange, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()))
        ),
        _MenuCard(
          title: "Ver Productos", icon: Icons.fastfood, color: Colors.purple, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsScreen()))
        ),
        _MenuCard(
          title: "Resumen Día", icon: Icons.picture_as_pdf, color: Colors.teal, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InfoScreen()))
        ),
        _MenuCard(
          title: "Mesas", 
          icon: Icons.table_bar, 
          color: Colors.brown, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TablesScreen()))
       ),
      ];
    }
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MenuCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}