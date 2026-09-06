package com.caracruz.cara_o_cruz

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget "tiro rápido": onUpdate solo repinta idle/resultado a partir de lo
 * que ya guardó la callback Dart (ver coin_widget_service.dart) en
 * [widgetData] -- el estado de carga nunca pasa por acá, lo pinta
 * [CoinFlipTapReceiver] al instante, sin esperar al FlutterEngine headless
 * (ver CLAUDE.md, sección del widget de Android).
 */
class CoinWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences
  ) {
    val result = widgetData.getString(RESULT_KEY, null)
    val views =
        if (result == "cara" || result == "cruz") {
          buildResultViews(context, result)
        } else {
          buildIdleViews(context)
        }
    appWidgetManager.updateAppWidget(appWidgetIds, views)
  }

  companion object {
    const val RESULT_KEY = "widget_flip_result"

    private fun clickPendingIntent(context: Context): PendingIntent {
      val intent =
          Intent(context, CoinFlipTapReceiver::class.java).apply {
            data = Uri.parse("caraocruz://flip")
          }
      var flags = PendingIntent.FLAG_UPDATE_CURRENT
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        flags = flags or PendingIntent.FLAG_IMMUTABLE
      }
      return PendingIntent.getBroadcast(context, 0, intent, flags)
    }

    fun buildIdleViews(context: Context): RemoteViews {
      return RemoteViews(context.packageName, R.layout.coin_widget).apply {
        setInt(R.id.widget_root, "setBackgroundResource", R.drawable.coin_widget_bg_cara)
        setViewVisibility(R.id.widget_emoji, View.VISIBLE)
        setViewVisibility(R.id.widget_result_image, View.GONE)
        setViewVisibility(R.id.widget_result_text, View.GONE)
        setViewVisibility(R.id.widget_progress, View.GONE)
        setTextViewText(R.id.widget_subtitle, context.getString(R.string.coin_widget_tap_hint))
        setOnClickPendingIntent(R.id.widget_root, clickPendingIntent(context))
      }
    }

    /** Sin `setOnClickPendingIntent`: un toque nuevo mientras carga no debe re-disparar el flip. */
    fun buildLoadingViews(context: Context): RemoteViews {
      return RemoteViews(context.packageName, R.layout.coin_widget).apply {
        setViewVisibility(R.id.widget_emoji, View.GONE)
        setViewVisibility(R.id.widget_result_image, View.GONE)
        setViewVisibility(R.id.widget_result_text, View.GONE)
        setViewVisibility(R.id.widget_progress, View.VISIBLE)
        setTextViewText(R.id.widget_subtitle, context.getString(R.string.coin_widget_loading_hint))
      }
    }

    /** Imagen real (cara.png/cruz.png, duplicada en res/drawable-nodpi) junto al texto de resultado. */
    fun buildResultViews(context: Context, result: String): RemoteViews {
      val isCara = result == "cara"
      return RemoteViews(context.packageName, R.layout.coin_widget).apply {
        setInt(
            R.id.widget_root,
            "setBackgroundResource",
            if (isCara) R.drawable.coin_widget_bg_cara else R.drawable.coin_widget_bg_cruz)
        setViewVisibility(R.id.widget_emoji, View.GONE)
        setViewVisibility(R.id.widget_result_image, View.VISIBLE)
        setViewVisibility(R.id.widget_result_text, View.VISIBLE)
        setViewVisibility(R.id.widget_progress, View.GONE)
        setImageViewResource(
            R.id.widget_result_image,
            if (isCara) R.drawable.coin_widget_cara else R.drawable.coin_widget_cruz)
        setTextViewText(
            R.id.widget_result_text,
            context.getString(if (isCara) R.string.coin_widget_heads else R.string.coin_widget_tails))
        setTextColor(R.id.widget_result_text, if (isCara) 0xFFD6AD60.toInt() else 0xFF7B7BEA.toInt())
        setTextViewText(R.id.widget_subtitle, context.getString(R.string.coin_widget_tap_again_hint))
        setOnClickPendingIntent(R.id.widget_root, clickPendingIntent(context))
      }
    }
  }
}
