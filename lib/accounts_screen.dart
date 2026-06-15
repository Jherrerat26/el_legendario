import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _rol = 'vendedor';

  void _crearCuenta() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debe completar todos los campos"),
        ),
      );
      return;
    }

    try {
      // Crear usuario en Firebase Auth
      UserCredential res =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Guardar rol en Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(res.user!.uid)
          .set({
        'email': _emailController.text.trim(),
        'rol': _rol,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cuenta creada con éxito"),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Cuentas"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Correo",
              ),
            ),

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Contraseña",
              ),
            ),

            DropdownButton<String>(
              value: _rol,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'vendedor',
                  child: Text("Vendedor / Mesero"),
                ),
                DropdownMenuItem(
                  value: 'admin',
                  child: Text("Administrador"),
                ),
              ],
              onChanged: (v) => setState(() => _rol = v!),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _crearCuenta,
              child: const Text("REGISTRAR USUARIO"),
            ),
          ],
        ),
      ),
    );
  }
}