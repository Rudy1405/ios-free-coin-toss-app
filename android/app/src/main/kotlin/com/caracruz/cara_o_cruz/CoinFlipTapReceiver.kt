package com.caracruz.cara_o_cruz

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetBackgroundService
import io.flutter.FlutterInjector

/**
 * Destino real del toque sobre el widget "Cara o Cruz" -- reemplaza al
 * `HomeWidgetBackgroundReceiver` del plugin `home_widget` como target del
 * `PendingIntent` de clic (ver `CoinWidgetProvider.clickPendingIntent`).
 *
 * Pinta el estado de carga al instante, en este `onReceive` (sin Flutter
 * todavía), para que el widget nunca se sienta "trabado" mientras arranca
 * el `FlutterEngine` headless. Recién después reenvía el trabajo a
 * [HomeWidgetBackgroundService] -- el mismo mecanismo interno que usa el
 * receiver original del plugin -- para que la callback Dart ya registrada
 * (`coinWidgetFlipCallback`, en `coin_widget_service.dart`) calcule el
 * resultado y actualice el widget. Se le agrega `tappedAtMillis` a la URI
 * para que esa callback pueda pacer el reveal a ~1s reales desde el toque,
 * en vez de sumar una espera fija encima de la latencia del engine.
 */
class CoinFlipTapReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val appWidgetManager = AppWidgetManager.getInstance(context)
    val ids =
        appWidgetManager.getAppWidgetIds(ComponentName(context, CoinWidgetProvider::class.java))
    appWidgetManager.updateAppWidget(ids, CoinWidgetProvider.buildLoadingViews(context))

    val stampedUri =
        intent.data
            ?.buildUpon()
            ?.appendQueryParameter("tappedAtMillis", System.currentTimeMillis().toString())
            ?.build()
    val forwarded = Intent(intent).apply { data = stampedUri }

    val flutterLoader = FlutterInjector.instance().flutterLoader()
    flutterLoader.startInitialization(context)
    flutterLoader.ensureInitializationComplete(context, null)
    HomeWidgetBackgroundService.enqueueWork(context, forwarded)
  }
}
