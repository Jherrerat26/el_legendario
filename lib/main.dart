import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Importa tus pantallas
import 'login_screen.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    
    // Configuración para que funcione sin internet (Offline)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true, 
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED
    );
    
  } catch (e) {
    print("Error conectando Firebase: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Legendario',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      // En lugar de ir directo al Login, pasamos por el "Portero" (AuthGate)
      home: const AuthGate(),
    );
  }
}

/// Esta clase es el "Portero". Decide a dónde va el usuario.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha cambios en la autenticación (si entra o sale)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        // 1. Si está esperando respuesta de Firebase...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. Si hay un usuario logueado (snapshot tiene datos)
        if (snapshot.hasData) {
          // Necesitamos saber si es Admin o Vendedor para cargar el Home correcto
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('usuarios').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
              }

              if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                // Obtener el rol y enviar al Home
                String rol = userSnapshot.data!['rol'];
                return HomeScreen(rol: rol);
              } else {
                // Si el usuario está autenticado pero no tiene datos en la BD (Raro, pero posible)
                return const LoginPage();
              }
            },
          );
        }

        // 3. Si NO hay usuario logueado
        return const LoginPage();
      },
    );
  }
}