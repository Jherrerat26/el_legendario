import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true; // Variable para mostrar/ocultar contraseña

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // 1. Intentar Autenticar en Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(), // trim quita espacios accidentales
        password: _passwordController.text.trim(),
      );

      // 2. Si entra, buscar el ROL en Firestore usando el UID
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String rol = userDoc['rol'];
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(rol: rol)),
          );
        }
      } else {
        // El usuario existe en Auth pero no creaste su documento en Firestore
        throw "No se encontró el permiso (rol) para este usuario en la base de datos.";
      }
    } on FirebaseAuthException catch (e) {
      String mensaje = "Error de correo o contraseña.";
      if (e.code == 'user-not-found') mensaje = "El correo no está registrado.";
      if (e.code == 'wrong-password') mensaje = "Contraseña incorrecta.";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.restaurant_menu, size: 80, color: Colors.orange),
              const SizedBox(height: 10),
              Text("El Legendario", 
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              
              // CAMPO CORREO
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Correo electrónico", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 20),
              
              // CAMPO CONTRASEÑA CON OJO
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: "Contraseña", 
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              _isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55), 
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: _login,
                    child: const Text("ENTRAR", 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}