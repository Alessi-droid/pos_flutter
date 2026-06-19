package com.example.pos_tablet_v7

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // 1. Dejamos que tu app en Flutter reciba la tecla primero (así funciona tu "Cobrar con F12")
        val flutterSeEncargo = super.dispatchKeyEvent(event)

        // 2. Si la tecla presionada es de la F1 a la F12...
        if (event.keyCode in KeyEvent.KEYCODE_F1..KeyEvent.KEYCODE_F12) {
            // Le "mentimos" a Android diciendo que ya procesamos la tecla.
            // Esto bloquea que Android intente abrir Chrome, Contactos o el Correo.
            return true 
        }

        // 3. Para cualquier otra tecla (Volumen, brillo, botones normales), dejamos que Android haga lo suyo
        return flutterSeEncargo
    }
}