// This file is used to register Flutter web plugins.
// It is required by the Flutter framework.

import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? registrar]) {
  if (registrar != null) {
    FirebaseCoreWeb.registerWith(registrar);
    FirebaseAuthWeb.registerWith(registrar);
    FirebaseFirestoreWeb.registerWith(registrar);
  }
} 