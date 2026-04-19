package com.opc.stella

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NowPlayingWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.now_playing_widget_layout)

            val title = widgetData.getString("now_playing_title", "") ?: ""
            val podcast = widgetData.getString("now_playing_podcast", "") ?: ""
            val isPlaying = widgetData.getBoolean("now_playing_is_playing", false)

            views.setTextViewText(R.id.widget_title, if (title.isNotEmpty()) title else "Not Playing")
            views.setTextViewText(R.id.widget_podcast, if (podcast.isNotEmpty()) podcast else "Stella")

            if (isPlaying) {
                views.setImageViewResource(R.id.widget_play_icon, android.R.drawable.ic_media_pause)
                views.setViewVisibility(R.id.widget_play_icon, View.VISIBLE)
            } else {
                views.setImageViewResource(R.id.widget_play_icon, android.R.drawable.ic_media_play)
                views.setViewVisibility(R.id.widget_play_icon, View.VISIBLE)
            }

            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
