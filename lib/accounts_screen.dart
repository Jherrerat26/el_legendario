import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pantalla encargada del registro de usuarios
// y asignación de roles dentro del sistema.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {

  // Controladores para capturar datos ingresados
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Rol por defecto asignado al nuevo usuario
  String _rol = 'vendedor';

  // Función responsable de crear la cuenta
  // en Firebase Authentication y registrar
  // información adicional en Firestore.
  void _crearCuenta() async {

    // Validación básica de campos obligatorios
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Debe completar todos los campos",
          ),
        ),
      );

      return;
    }

    try {

      // Crear usuario en Firebase Authentication
      UserCredential res =
          await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Guardar información complementaria
      // del usuario dentro de Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(res.user!.uid)
          .set({
        'email': _emailController.text.trim(),
        'rol': _rol,
      });

      // Confirmación visual para el administrador
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Cuenta creada con éxito",
          ),
        ),
      );

      // Regresar automáticamente
      // a la pantalla anterior
      Navigator.pop(context);

    } catch (e) {

      // Manejo de errores durante el registro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error: $e",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // Barra superior
      appBar: AppBar(
        title: const Text(
          "Crear Cuentas",
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(25),

        child: Column(
          children: [

            // Campo para correo electrónico
            TextField(
              controller: _emailController,

              decoration: const InputDecoration(
                labelText: "Correo",
              ),
            ),

            // Campo para contraseña
            TextField(
              controller: _passwordController,

              decoration: const InputDecoration(
                labelText: "Contraseña",
              ),
            ),

            // Selector de rol
            DropdownButton<String>(
              value: _rol,
              isExpanded: true,

              items: const [

                DropdownMenuItem(
                  value: 'vendedor',
                  child: Text(
                    "Vendedor / Mesero",
                  ),
                ),

                DropdownMenuItem(
                  value: 'admin',
                  child: Text(
                    "Administrador",
                  ),
                ),
              ],

              // Actualiza el rol seleccionado
              onChanged: (v) =>
                  setState(() => _rol = v!),
            ),

            const SizedBox(
              height: 30,
            ),

            // Botón principal para registrar usuario
            ElevatedButton(
              onPressed: _crearCuenta,

              child: const Text(
                "REGISTRAR USUARIO",
              ),
            ),
          ],
        ),
      ),
    );
  }
}